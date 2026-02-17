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

# Use AP2 partition config for response service
sudo bash /ops/shared/scripts/client.sh "${cloud_env}" "${retry_join}" "ap2"

NOMAD_HCL_PATH="/etc/nomad.d/nomad.hcl"
CLOUD_ENV="${cloud_env}"
CONSULCONFIGDIR=/etc/consul.d

# wait for consul to start
sleep 10

PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/public-ipv4)
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/instance-id)

# Wait for AP2 partition to be created on the server
echo "Waiting for AP2 partition to be available..."
export CONSUL_HTTP_TOKEN="e95b599e-166e-7d80-08ad-aee76e7ddf19"
MAX_RETRIES=30
RETRY_COUNT=0
until consul partition list | grep -q "ap2" || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
  echo "AP2 partition not yet available, waiting... (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "ERROR: AP2 partition failed to become available after $MAX_RETRIES attempts"
  exit 1
fi

echo "AP2 partition is now available"

# Wait for mesh gateway AP2 to be ready (required for receiving cross-partition traffic)
echo "Waiting for mesh gateway AP2 to be registered and healthy..."
RETRY_COUNT=0
MAX_RETRIES=30

until consul catalog services -partition=ap2 | grep -q "mesh-gateway" || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
  echo "Mesh gateway AP2 not yet registered, waiting... (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "ERROR: Mesh gateway AP2 not ready after $MAX_RETRIES attempts"
  exit 1
fi

echo "Mesh gateway AP2 is now available"

# Additional wait for exported services to propagate
echo "Waiting for exported services configuration to propagate..."
sleep 15

# starting the response-service application
sudo touch /var/log/fake_service.log
sudo chmod a+rw /var/log/fake_service.log

# starting the fake service
LISTEN_ADDR=0.0.0.0:6060 fake_service > /var/log/fake_service.log 2>&1 &

sleep 10

# wait until the file is copied
if [ ! -f /tmp/shared/config/response-service.json ]; then
  echo "Waiting for response-service.json to be copied..."
  while [ ! -f /tmp/shared/config/response-service.json ]; do
    sleep 5
  done
  cp /tmp/shared/config/response-service.json /ops/shared/config/response-service.json
fi

sed -i "s/IP_ADDRESS/$PRIVATE_IP/g" /ops/shared/config/response-service.json
sed -i "s/INSTANCE_INDEX/${index}/g" /ops/shared/config/response-service.json

# wait until the file is copied
if [ ! -f /tmp/shared/config/response-service-proxy.hcl ]; then
  echo "Waiting for response-service-proxy.hcl to be copied..."
  while [ ! -f /tmp/shared/config/response-service-proxy.hcl ]; do
    sleep 5
  done
fi
cp /tmp/shared/config/response-service-proxy.hcl /ops/shared/config/response-service-proxy.hcl
sed -i "s/IP_ADDRESS/$PRIVATE_IP/g" /ops/shared/config/response-service-proxy.hcl
sed -i "s/INSTANCE_INDEX/${index}/g" /ops/shared/config/response-service-proxy.hcl
sed -i "s/PROXY_PORT/21000/g" /ops/shared/config/response-service-proxy.hcl

# Register the service with Consul (will be in AP2 partition due to agent config)
export CONSUL_HTTP_TOKEN="e95b599e-166e-7d80-08ad-aee76e7ddf19"
consul services register /ops/shared/config/response-service.json
# Note: The sidecar proxy is automatically created via the connect.sidecar_service in the JSON

touch /var/log/envoy.log
chmod a+rw /var/log/envoy.log
consul connect envoy -sidecar-for service-response-${index} -ignore-envoy-compatibility -- -l debug > /var/log/envoy.log 2>&1 &

# once bootstrapped, remove the ACL token
rm -f $CONSULCONFIGDIR/acl.hcl

sleep 10

# additional permissions for remote debugging
sudo chmod -R a+rwx /etc/consul.d
sudo chmod -R a+rwx /opt/
