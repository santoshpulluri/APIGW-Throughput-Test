service {
  name = "service-hello-sidecar-proxy"
  id   = "service-hello-proxy-INSTANCE_INDEX"
  kind = "connect-proxy"
  # The proxy's own listening port for incoming traffic
  port = PROXY_PORT

  proxy {
    destination_service_id   = "service-hello"
    destination_service_name = "service-hello"
    local_service_address    = "127.0.0.1"
    local_service_port       = 5050

    upstreams = [
      {
        destination_name = "service-response"
        local_bind_port  = 9090
      }
    ]
  }
}
