service {
  name = "service-response-sidecar-proxy"
  id   = "service-response-sidecar-proxy-INSTANCE_INDEX"
  kind = "connect-proxy"
  # The proxy's own listening port for incoming traffic
  port = PROXY_PORT
  
  proxy {
    destination_service_id   = "service-response"
    destination_service_name = "service-response"
    local_service_address    = "127.0.0.1"
    local_service_port       = 6060
  }
}