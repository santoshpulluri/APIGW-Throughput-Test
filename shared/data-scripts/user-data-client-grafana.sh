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

# starting the grafana-service application
echo "Starting grafana service"

# install grafana
# Add the GPG key for Grafana repos
wget -q -O - https://apt.grafana.com/gpg.key | sudo apt-key add -

# Add the repository for Grafana Enterprise
sudo add-apt-repository -y "deb https://apt.grafana.com stable main"

# Update package lists
sudo apt-get -y update

# Install Grafana Enterprise
sudo apt-get install -y grafana-enterprise

sudo mkdir -p /etc/grafana/provisioning/datasources/
sudo chmod -R a+rw /etc/grafana
sudo tee /etc/grafana/provisioning/datasources/prometheus.yml<<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://${prometheus_ip}:9090
    isDefault: true
EOF

# starting grafana
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

sleep 10

# Add the datasource using grafana-cli
grafana-cli --homepath "/usr/share/grafana" admin create-api-key "AdminKey" --role "Admin" | \
  grep -oP '(?<="key":")[^"]*' | \
  xargs -I {} curl -X POST http://localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {}" \
  -d @/etc/grafana/provisioning/datasources/prometheus.yml

# Add the dashboard using grafana-cli
grafana-cli --homepath "/usr/share/grafana" admin reset-admin-password "admin" | \
  grep -oP '(?<="key":")[^"]*' | \
  xargs -I {} curl -X POST http://localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {}" \
  -d @/tmp/shared/config/grafana-dashboard.json

# once bootstrapped, remove the ACL token
rm -f $CONSULCONFIGDIR/acl.hcl

sleep 10

# additional permissions for remote debugging
sudo chmod -R a+rwx /etc/consul.d
sudo chmod -R a+rwx /opt/
