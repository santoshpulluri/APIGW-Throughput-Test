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

# Register the service with Consul
consul services register /ops/shared/config/hello-service.json
consul services register /ops/shared/config/hello-service-proxy.hcl
# sudo docker run -d --name service-a-sidecar --network host consul:1.18 connect proxy -sidecar-for service-hello -admin-bind="127.0.0.1:19000"

touch /var/log/envoy.log
chmod a+rw /var/log/envoy.log
consul connect envoy -sidecar-for service-hello-${index} -ignore-envoy-compatibility -- -l debug > /var/log/envoy.log 2>&1 &

# once bootstrapped, remove the ACL token
rm -f $CONSULCONFIGDIR/acl.hcl

sleep 10

# additional permissions for remote debugging
sudo chmod -R a+rwx /etc/consul.d
sudo chmod -R a+rwx /opt/
