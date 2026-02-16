#!/bin/bash

set -e

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

export CONSUL_HTTP_TOKEN="e95b599e-166e-7d80-08ad-aee76e7ddf19"

# wait until the file is copied
if [ ! -f /tmp/shared/scripts/server.sh ]; then
  echo "Waiting for server.sh to be copied..."
  while [ ! -f /tmp/shared/scripts/server.sh ]; do
    sleep 5
  done
fi

sudo mkdir -p /ops/shared
# sleep for 10s to ensure the file is copied
sleep 10
sudo cp -R /tmp/shared /ops/

sudo bash /ops/shared/scripts/server.sh "${cloud_env}" "${server_count}" "${retry_join}"


CLOUD_ENV="${cloud_env}"

sed -i "s/RETRY_JOIN/${retry_join}/g" /etc/consul.d/consul.hcl

# for aws only
TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)
sed -i "s/IP_ADDRESS/$PRIVATE_IP/g" /etc/consul.d/consul.hcl
sed -i "s/SERVER_COUNT/${server_count}/g" /etc/consul.d/consul.hcl

sudo systemctl restart consul.service

sleep 10

# once bootstrapped, remove the ACL token
rm -f $CONSULCONFIGDIR/acl.hcl

sleep 10

echo "Consul started"

# additional permissions for remote debugging
sudo chmod -R a+rwx /etc/consul.d
sudo chmod -R a+rwx /opt/consul/data

sudo apt-get install -y golang


