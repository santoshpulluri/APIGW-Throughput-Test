data_dir = "/opt/consul/data"
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
advertise_addr = "IP_ADDRESS"

bootstrap_expect = 1

log_level = "TRACE"

server = true
ui = true

retry_join = ["RETRY_JOIN"]

service {
    name = "minion-consul"
}

ports {
  grpc = 8502
}

license_path = "/etc/consul.d/license.hclic"

audit {
  enabled = true
  sink "My sink" {
    type   = "file"
    format = "json"
    path   = "/tmp/audit.json"
    delivery_guarantee = "best-effort"
    rotate_duration = "24h"
    rotate_max_files = 15
    rotate_bytes = 25165824
  }
}

telemetry {
  prometheus_retention_time = "24h"
  disable_hostname = true
}