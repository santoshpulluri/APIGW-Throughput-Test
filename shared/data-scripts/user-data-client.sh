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

# Determine partition based on application type and update Consul config
if [ "${application_name}" = "hello-service" ] || [ "${application_name}" = "apigw-service" ] || [ "${application_name}" = "mesh-gateway-ap1" ]; then
  echo "Configuring Consul client for partition AP1"
  # Get AWS metadata token
  TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)
  
  sed -i "s/IP_ADDRESS/$PRIVATE_IP/g" /ops/shared/config/consul_client_ap1.hcl
  sed -i "s/RETRY_JOIN/${retry_join}/g" /ops/shared/config/consul_client_ap1.hcl
  sudo cp /ops/shared/config/consul_client_ap1.hcl $CONSULCONFIGDIR/consul.hcl
  
  # Restart consul to apply partition configuration
  sudo systemctl restart consul.service
elif [ "${application_name}" = "response-service" ] || [ "${application_name}" = "mesh-gateway-ap2" ]; then
  echo "Configuring Consul client for partition AP2"
  # Get AWS metadata token
  TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)
  
  sed -i "s/IP_ADDRESS/$PRIVATE_IP/g" /ops/shared/config/consul_client_ap2.hcl
  sed -i "s/RETRY_JOIN/${retry_join}/g" /ops/shared/config/consul_client_ap2.hcl
  sudo cp /ops/shared/config/consul_client_ap2.hcl $CONSULCONFIGDIR/consul.hcl
  
  # Restart consul to apply partition configuration
  sudo systemctl restart consul.service
fi

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

  # Register the service with Consul in partition AP1
  consul services register -partition=AP1 /ops/shared/config/hello-service.json
  consul services register -partition=AP1 /ops/shared/config/hello-service-proxy.hcl
  # sudo docker run -d --name service-a-sidecar --network host consul:1.18 connect proxy -sidecar-for service-hello -admin-bind="127.0.0.1:19000"
  
  touch /var/log/envoy.log
  chmod a+rw /var/log/envoy.log
  consul connect envoy -partition=AP1 -sidecar-for service-hello-${index} -ignore-envoy-compatibility -- -l info > /var/log/envoy.log 2>&1 &
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

  # Register the service with Consul in partition AP2
  consul services register -partition=AP2 /ops/shared/config/response-service.json
  consul services register -partition=AP2 /ops/shared/config/response-service-proxy.hcl
  # sudo docker run -d --name service-a-sidecar --network host consul:1.18 connect proxy -sidecar-for service-response -admin-bind="127.0.0.1:19000"

  touch /var/log/envoy.log
  chmod a+rw /var/log/envoy.log
  consul connect envoy -partition=AP2 -sidecar-for service-response-${index} -ignore-envoy-compatibility -- -l info > /var/log/envoy.log 2>&1 &
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

  # creating proxy default for AP1 partition  
  sudo tee ./proxy-default-ap1.hcl<<EOF
  Kind      = "proxy-defaults"
  Name      = "global"
  Partition = "AP1"
  Namespace = "default"
  MeshGateway {
    Mode = "local"
  }
  Config {
    protocol = "http"
  }
EOF

  # creating proxy default for AP2 partition
  sudo tee ./proxy-default-ap2.hcl<<EOF
  Kind      = "proxy-defaults"
  Name      = "global"
  Partition = "AP2"
  Namespace = "default"
  MeshGateway {
    Mode = "local"
  }
  Config {
    protocol = "http"
  }
EOF

  consul config write -partition=AP1 proxy-default-ap1.hcl
  consul config write -partition=AP2 proxy-default-ap2.hcl

  # Register the API gateway with Consul in partition AP1
  consul config write -partition=AP1 /ops/shared/config/api-gw.hcl
  consul config write -partition=AP1 /ops/shared/config/api-gw-routes.hcl

  # starting envoy for API gateway in AP1 partition
  touch /var/log/envoy.log
  chmod a+rw /var/log/envoy.log
  consul connect envoy -partition=AP1 -gateway api -register -service minion-gateway -admin-bind 0.0.0.0:19000 -- --log-level info > /var/log/envoy.log 2>&1 &
elif [ "${application_name}" = "mesh-gateway-ap1" ]; then
  echo "Starting Mesh Gateway for partition AP1"
  sleep 10

  # Copy and configure mesh gateway service definition
  cp /tmp/shared/config/mesh-gateway-ap1.hcl /ops/shared/config/mesh-gateway-ap1.hcl
  sed -i "s/IP_ADDRESS/$PRIVATE_IP/g" /ops/shared/config/mesh-gateway-ap1.hcl

  # Register mesh gateway service in AP1 partition
  consul services register -partition=AP1 /ops/shared/config/mesh-gateway-ap1.hcl

  # Start Envoy as mesh gateway
  touch /var/log/envoy.log
  chmod a+rw /var/log/envoy.log
  consul connect envoy -partition=AP1 -gateway mesh -register -service mesh-gateway -address "$PRIVATE_IP:8444" -wan-address "$PUBLIC_IP:8444" -admin-bind 0.0.0.0:19000 -- --log-level info > /var/log/envoy.log 2>&1 &
elif [ "${application_name}" = "mesh-gateway-ap2" ]; then
  echo "Starting Mesh Gateway for partition AP2"
  sleep 10

  # Copy and configure mesh gateway service definition
  cp /tmp/shared/config/mesh-gateway-ap2.hcl /ops/shared/config/mesh-gateway-ap2.hcl
  sed -i "s/IP_ADDRESS/$PRIVATE_IP/g" /ops/shared/config/mesh-gateway-ap2.hcl

  # Register mesh gateway service in AP2 partition
  consul services register -partition=AP2 /ops/shared/config/mesh-gateway-ap2.hcl

  # Start Envoy as mesh gateway
  touch /var/log/envoy.log
  chmod a+rw /var/log/envoy.log
  consul connect envoy -partition=AP2 -gateway mesh -register -service mesh-gateway -address "$PRIVATE_IP:8444" -wan-address "$PUBLIC_IP:8444" -admin-bind 0.0.0.0:19000 -- --log-level info > /var/log/envoy.log 2>&1 &
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