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

# starting the application
if [ "${application_name}" = "hello-service" ]; then
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

elif [ "${application_name}" = "response-service" ]; then
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

  # Register the service with Consul
  consul services register /ops/shared/config/response-service.json
  consul services register /ops/shared/config/response-service-proxy.hcl
  # sudo docker run -d --name service-a-sidecar --network host consul:1.18 connect proxy -sidecar-for service-response -admin-bind="127.0.0.1:19000"

  touch /var/log/envoy.log
  chmod a+rw /var/log/envoy.log
  consul connect envoy -sidecar-for service-response-${index} -ignore-envoy-compatibility -- -l debug > /var/log/envoy.log 2>&1 &

elif [ "${application_name}" = "apigw-service" ]; then
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

elif [ "${application_name}" = "grafana-service" ]; then
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

elif [ "${application_name}" = "prometheus-service" ]; then
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

else
  echo "Unknown application name: ${application_name}"
fi

# once bootstrapped, remove the ACL token
rm -f $CONSULCONFIGDIR/acl.hcl

# API_PAYLOAD='{
#   "Name": "'${application_name}'",
#   "ID": "'${application_name}'-'$INSTANCE_ID'",
#   "Address": "'$PUBLIC_IP'",
#   "Port": '${application_port}',
#   "Meta": {
#     "version": "1.0.0"
#   },
#   "EnableTagOverride": false,
#   "Checks": [
#     {
#       "Name": "HTTP Health Check",
#       "HTTP": "http://'$PUBLIC_IP':'${application_port}'/'${application_health_ep}'",
#       "Interval": "10s",
#       "Timeout": "1s"
#     }
#   ]
# }'

# echo $API_PAYLOAD > /tmp/api_payload.json

# # Register the service with Consul
# curl -X PUT http://${consul_ip}:8500/v1/agent/service/register \
# -H "Content-Type: application/json" \
# -d "$API_PAYLOAD"

sleep 10

# curl --request PUT --data '["Bello!", "Poopaye!", "Tulaliloo ti amo!"]' http://consul.service.consul:8500/v1/kv/minion_phrases

# additional permissions for remote debugging
sudo chmod -R a+rwx /etc/consul.d
sudo chmod -R a+rwx /opt/