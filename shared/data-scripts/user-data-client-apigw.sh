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

# creating proxy default
sudo tee ./proxy-default.hcl<<EOF
Kind      = "proxy-defaults"
Name      = "global"
Config {
  protocol = "http"
}
EOF

consul config write proxy-default.hcl

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
