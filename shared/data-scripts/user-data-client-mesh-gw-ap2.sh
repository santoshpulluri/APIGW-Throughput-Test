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

# Use AP2 partition config for mesh gateway
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

# Starting the mesh gateway for AP2
echo "Starting mesh gateway for AP2..."
sleep 10

# Start Envoy as mesh gateway
touch /var/log/mesh-gateway.log
chmod a+rw /var/log/mesh-gateway.log

# Run mesh gateway in local mode
# The -register flag will automatically register the service with Consul
consul connect envoy -gateway=mesh \
  -register \
  -service mesh-gateway \
  -partition ap2 \
  -address "$PRIVATE_IP:8443" \
  -wan-address "$PUBLIC_IP:8443" \
  -bind-address "mesh=$PRIVATE_IP:8443" \
  -admin-bind 0.0.0.0:19002 \
  -- -l debug > /var/log/mesh-gateway.log 2>&1 &

# once bootstrapped, remove the ACL token
rm -f $CONSULCONFIGDIR/acl.hcl

sleep 10

# additional permissions for remote debugging
sudo chmod -R a+rwx /etc/consul.d
sudo chmod -R a+rwx /opt/
