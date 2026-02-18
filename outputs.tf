# Load Generator Public IP
output "load_generator_public_ip" {
  description = "Public IP of the Load Generator EC2 instance"
  value       = aws_instance.load_generator.public_ip
}
# API Gateway Public IP
output "apigw_service_public_ip" {
  description = "Public IP of the API Gateway EC2 instance"
  value       = aws_instance.apigw_service.public_ip
}

# Response Service Public IP (assuming first instance)
output "response_service_public_ip" {
  description = "Public IP of the Response Service EC2 instance"
  value       = aws_instance.response_service[0].public_ip
}
#Add Consul UI URL
output "output" {
    value = <<CONFIGURATION
==================================================
CONSUL UI & ACL TOKEN
==================================================
Consul UI: http://${aws_instance.consul.public_ip}:8500
ACL Token: e95b599e-166e-7d80-08ad-aee76e7ddf19

==================================================
CONSUL ADMIN PARTITIONS
==================================================
Admin Partitions Created:
  - default (API Gateway)
  - ap1 (Hello Service) - ID: ${consul_admin_partition.ap1.id}
  - ap2 (Response Service) - ID: ${consul_admin_partition.ap2.id}

Service Distribution:
  - service-hello: AP1 → exported to default
  - service-response: AP2 → exported to AP1
  - mesh-gateway: AP1 → exported to default (required for cross-partition routing)
  - mesh-gateway: AP2 → exported to AP1 (required for cross-partition routing)
  - minion-gateway (API GW): default → accesses AP1

CRITICAL: Both mesh-gateway AND application services must be exported
  Reference: https://support.hashicorp.com/hc/en-us/articles/19290357144211

Mesh Gateways (for cross-partition communication):
  - mesh-gateway-ap1: ${aws_instance.mesh_gateway_ap1.private_ip} (port 8443)
    Admin UI: http://${aws_instance.mesh_gateway_ap1.public_ip}:19001
    SSH: ssh -i "minion-key.pem" ubuntu@${aws_instance.mesh_gateway_ap1.public_ip}
  - mesh-gateway-ap2: ${aws_instance.mesh_gateway_ap2.private_ip} (port 8443)
    Admin UI: http://${aws_instance.mesh_gateway_ap2.public_ip}:19002
    SSH: ssh -i "minion-key.pem" ubuntu@${aws_instance.mesh_gateway_ap2.public_ip}

Mesh Gateway Mode: local (services route through local mesh gateway)

Required Ports for Mesh Gateways:
  - 8443: Mesh gateway traffic (WAN federation)
  - 8502: gRPC (service mesh communication)
  - 8300: Consul server RPC
  - 8301: Consul serf LAN (TCP/UDP)
  - 8302: Consul serf WAN (TCP/UDP)
  - 19001/19002: Envoy admin interfaces

Service Intentions (Authorization):
  ✓ service-hello (AP1) → service-response (AP2): ALLOW
  ✓ minion-gateway (default) → service-hello (AP1): ALLOW

==================================================
API GATEWAY (Main Entry Point)
==================================================
    http://${aws_instance.apigw_service.public_ip}:8443/hello
    http://${aws_instance.apigw_service.public_ip}:8443/hellobello
    Envoy Admin: http://${aws_instance.apigw_service.public_ip}:19000/ready

==================================================
MONITORING DASHBOARDS
==================================================
Grafana: http://${aws_instance.grafana.public_ip}:3000 (admin/admin)
Prometheus: http://${aws_instance.prometheus.public_ip}:9090

==================================================
DIRECT SERVICE ACCESS (for testing)
==================================================
response_service_url
    curl http://${aws_instance.response_service[0].public_ip}:6060/response | jq
    curl http://${aws_instance.response_service[1].public_ip}:6060/response | jq

==================================================
SSH ACCESS
==================================================
ssh_to_consul_service
    ssh -i "minion-key.pem" ubuntu@${aws_instance.consul.public_ip}

ssh_to_hello_service
    ssh -i "minion-key.pem" ubuntu@${aws_instance.hello_service[0].public_ip}
    ssh -i "minion-key.pem" ubuntu@${aws_instance.hello_service[1].public_ip}

ssh_to_response_service
    ssh -i "minion-key.pem" ubuntu@${aws_instance.response_service[0].public_ip}
    ssh -i "minion-key.pem" ubuntu@${aws_instance.response_service[1].public_ip}

ssh_to_apigw_service
    ssh -i "minion-key.pem" ubuntu@${aws_instance.apigw_service.public_ip}

ssh_to_grafana
    ssh -i "minion-key.pem" ubuntu@${aws_instance.grafana.public_ip}

ssh_to_prometheus
    ssh -i "minion-key.pem" ubuntu@${aws_instance.prometheus.public_ip}

==================================================

    CONFIGURATION
}
