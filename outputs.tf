#Add Consul UI URL
output "output" {
    value = <<CONFIGURATION
==================================================
CONSUL UI & ACL TOKEN
==================================================
Consul UI: http://${aws_instance.consul.public_ip}:8500
ACL Token: e95b599e-166e-7d80-08ad-aee76e7ddf19

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
