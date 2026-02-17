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

# Use AP1 partition config for hello service
sudo bash /ops/shared/scripts/client.sh "${cloud_env}" "${retry_join}" "ap1"

NOMAD_HCL_PATH="/etc/nomad.d/nomad.hcl"
CLOUD_ENV="${cloud_env}"
CONSULCONFIGDIR=/etc/consul.d

# wait for consul to start
sleep 10

PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/public-ipv4)
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/instance-id)

# Wait for AP1 partition to be created on the server
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

# Wait for mesh gateways to be ready (required for cross-partition communication)
echo "Waiting for mesh gateways to be registered and healthy..."
RETRY_COUNT=0
MAX_RETRIES=30

# Wait for mesh-gateway in ap1 partition
until consul catalog services -partition=ap1 | grep -q "mesh-gateway" || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
  echo "Mesh gateway AP1 not yet registered, waiting... (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "ERROR: Mesh gateway AP1 not ready after $MAX_RETRIES attempts"
  exit 1
fi

# Wait for mesh-gateway in ap2 partition (needed for calling response service)
RETRY_COUNT=0
until consul catalog services -partition=ap2 | grep -q "mesh-gateway" || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
  echo "Mesh gateway AP2 not yet registered, waiting... (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "ERROR: Mesh gateway AP2 not ready after $MAX_RETRIES attempts"
  exit 1
fi

echo "Both mesh gateways are now available"

# Wait for response service to be healthy in AP2 (since hello calls response)
echo "Waiting for response service to be healthy in partition AP2..."
RETRY_COUNT=0
until consul catalog services -partition=ap2 | grep -q "service-response" || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
  echo "Response service not yet available, waiting... (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "ERROR: Response service not available after $MAX_RETRIES attempts"
  exit 1
fi

echo "Response service is now available"

# Additional wait for exported services to propagate
echo "Waiting for exported services configuration to propagate..."
sleep 15

# Verify service intention exists (allows hello -> response communication)
echo "Verifying service intentions for cross-partition communication..."
RETRY_COUNT=0
until consul config read -kind service-intentions -name service-response -partition ap2 2>/dev/null | grep -q "service-hello" || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
  echo "Service intention not yet configured, waiting... (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "WARNING: Service intention not fully configured, proceeding anyway..."
else
  echo "Service intention verified: service-hello can call service-response"
fi

# starting the hello-service application
sudo touch /var/log/fake_service.log
sudo chmod a+rw /var/log/fake_service.log

# starting the fake service
LISTEN_ADDR=0.0.0.0:5050 UPSTREAM_URIS=http://localhost:9999/response fake_service > /var/log/fake_service.log 2>&1 &

# wait until the file is copied
if [ ! -f /tmp/shared/config/hello-service.json ]; then
  echo "Waiting for hello-service.json to be copied..."
  while [ ! -f /tmp/shared/config/hello-service.json ]; do
    sleep 5
  done
fi
cp /tmp/shared/config/hello-service.json /ops/shared/config/hello-service.json

sed -i "s/IP_ADDRESS/$PRIVATE_IP/g" /ops/shared/config/hello-service.json
sed -i "s/INSTANCE_INDEX/${index}/g" /ops/shared/config/hello-service.json

# wait until the file is copied
if [ ! -f /tmp/shared/config/hello-service-proxy.hcl ]; then
  echo "Waiting for hello-service-proxy.hcl to be copied..."
  while [ ! -f /tmp/shared/config/hello-service-proxy.hcl ]; do
    sleep 5
  done
fi
cp /tmp/shared/config/hello-service-proxy.hcl /ops/shared/config/hello-service-proxy.hcl
sed -i "s/IP_ADDRESS/$PRIVATE_IP/g" /ops/shared/config/hello-service-proxy.hcl
sed -i "s/INSTANCE_INDEX/${index}/g" /ops/shared/config/hello-service-proxy.hcl
sed -i "s/PROXY_PORT/21000/g" /ops/shared/config/hello-service-proxy.hcl

sleep 10

# Register the service with Consul (will be in AP1 partition due to agent config)
export CONSUL_HTTP_TOKEN="e95b599e-166e-7d80-08ad-aee76e7ddf19"
consul services register /ops/shared/config/hello-service.json
# Note: The sidecar proxy is automatically created via the connect.sidecar_service in the JSON

touch /var/log/envoy.log
chmod a+rw /var/log/envoy.log
consul connect envoy -sidecar-for service-hello-${index} -ignore-envoy-compatibility -- -l debug > /var/log/envoy.log 2>&1 &

# once bootstrapped, remove the ACL token
rm -f $CONSULCONFIGDIR/acl.hcl

sleep 10

# additional permissions for remote debugging
sudo chmod -R a+rwx /etc/consul.d
sudo chmod -R a+rwx /opt/
