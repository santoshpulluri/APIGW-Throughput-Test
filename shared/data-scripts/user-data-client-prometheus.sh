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

# starting the prometheus-service application
echo "Starting prometheus service"

# install prometheus
sudo apt-get install -y prometheus
sudo mkdir -p /etc/prometheus
sudo chmod -R a+rw /etc/prometheus

echo "${prometheus_targets}" > /tmp/prometheus_targets.txt
cat /tmp/prometheus_targets.txt
CONSUL_AGENTS=$(consul members | awk 'NR>1 {print $2}' | cut -d ':' -f 1 | sort -u | awk '{print $1":8500"}' | paste -sd, -)
echo "Consul agents: $CONSUL_AGENTS"

sudo tee /etc/prometheus/prometheus.yml<<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'consul'
    metrics_path: '/v1/agent/metrics'
    bearer_token: 'e95b599e-166e-7d80-08ad-aee76e7ddf19'
    static_configs:
      - targets: ["${prometheus_targets}"]
EOF

sleep 10

# starting prometheus
sudo systemctl enable prometheus
sudo systemctl start prometheus

sleep 10
sudo systemctl restart prometheus

# once bootstrapped, remove the ACL token
rm -f $CONSULCONFIGDIR/acl.hcl

sleep 10

# additional permissions for remote debugging
sudo chmod -R a+rwx /etc/consul.d
sudo chmod -R a+rwx /opt/
