#!/bin/bash

set -e

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

export CONSUL_HTTP_TOKEN="e95b599e-166e-7d80-08ad-aee76e7ddf19"

# wait until the file is copied
if [ ! -f /tmp/shared/scripts/client.sh ]; then
  echo "Waiting for client.sh to be copied..."
  while [ ! -f /tmp/shared/scripts/client.sh ]; do
    sleep 5
  done
fi

sudo mkdir -p /ops/shared
# sleep for 10s to ensure the file is copied
sleep 10
sudo cp -R /tmp/shared /ops/

sudo bash /ops/shared/scripts/client.sh "${cloud_env}" "${retry_join}"

NOMAD_HCL_PATH="/etc/nomad.d/nomad.hcl"
CLOUD_ENV="${cloud_env}"
CONSULCONFIGDIR=/etc/consul.d

# wait for consul to start
sleep 10

PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/public-ipv4)
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/instance-id)

# Wait for AP1 partition (API Gateway routes to services in AP1)
echo "Waiting for AP1 partition to be available..."
export CONSUL_HTTP_TOKEN="e95b599e-166e-7d80-08ad-aee76e7ddf19"
MAX_RETRIES=30
RETRY_COUNT=0
until consul partition list | grep -q "ap1" || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
  echo "AP1 partition not yet available, waiting... (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "ERROR: AP1 partition failed to become available after $MAX_RETRIES attempts"
  exit 1
fi

echo "AP1 partition is now available"

# Wait for mesh gateway AP1 (required for cross-partition routing)
echo "Waiting for mesh gateway AP1 to be registered..."
RETRY_COUNT=0
until consul catalog services -partition=ap1 | grep -q "mesh-gateway" || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
  echo "Mesh gateway AP1 not yet registered, waiting... (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "ERROR: Mesh gateway AP1 not ready after $MAX_RETRIES attempts"
  exit 1
fi

echo "Mesh gateway AP1 is now available"

# Wait for hello service to be available in AP1
echo "Waiting for hello service to be available in partition AP1..."
RETRY_COUNT=0
until consul catalog services -partition=ap1 | grep -q "service-hello" || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
  echo "Hello service not yet available, waiting... (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "ERROR: Hello service not available after $MAX_RETRIES attempts"
  exit 1
fi

echo "Hello service is now available"

# Additional wait for exported services to propagate
echo "Waiting for exported services configuration to propagate..."
sleep 15

# Verify service intention exists (allows API Gateway -> hello communication)
echo "Verifying service intentions for API Gateway to Hello Service..."
export CONSUL_HTTP_TOKEN="e95b599e-166e-7d80-08ad-aee76e7ddf19"
RETRY_COUNT=0
until consul config read -kind service-intentions -name service-hello -partition ap1 2>/dev/null | grep -q "minion-gateway" || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
  echo "Service intention not yet configured, waiting... (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "WARNING: Service intention not fully configured, proceeding anyway..."
else
  echo "Service intention verified: minion-gateway can call service-hello"
fi

# starting the apigw-service application
sleep 10

# wait until the file is copied
if [ ! -f /tmp/shared/config/api-gw.hcl ]; then
  echo "Waiting for api-gw.hcl to be copied..."
  while [ ! -f /tmp/shared/config/api-gw.hcl ]; do
    sleep 5
  done
  cp /tmp/shared/config/api-gw.hcl /ops/shared/config/api-gw.hcl
fi

# wait until the file is copied
if [ ! -f /tmp/shared/config/api-gw-routes.hcl ]; then
  echo "Waiting for api-gw-routes.hcl to be copied..."
  while [ ! -f /tmp/shared/config/api-gw-routes.hcl ]; do
    sleep 5
  done
  cp /tmp/shared/config/api-gw-routes.hcl /ops/shared/config/api-gw-routes.hcl
fi

# Note: proxy-defaults is now managed by Terraform (see consul.tf)
# This enables mesh gateway mode for cross-partition communication

# Register the service with Consul
consul config write /ops/shared/config/api-gw.hcl
consul config write /ops/shared/config/api-gw-routes.hcl

# starting envoy
touch /var/log/envoy.log
chmod a+rw /var/log/envoy.log
consul connect envoy -gateway api -register -service minion-gateway -admin-bind 0.0.0.0:19000 -- --log-level debug > /var/log/envoy.log 2>&1 &

# once bootstrapped, remove the ACL token
rm -f $CONSULCONFIGDIR/acl.hcl

sleep 10

# additional permissions for remote debugging
sudo chmod -R a+rwx /etc/consul.d
sudo chmod -R a+rwx /opt/
