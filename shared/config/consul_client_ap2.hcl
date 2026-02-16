ui = true
log_level = "TRACE"
data_dir = "/opt/consul/data"
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
advertise_addr = "IP_ADDRESS"
retry_join = ["RETRY_JOIN"]

partition = "AP2"

license_path = "/etc/consul.d/license.hclic"

ports {
  grpc = 8502
}

telemetry {
  prometheus_retention_time = "24h"
  disable_hostname = true
}
