Kind = "api-gateway"
Name = "minion-gateway"

// Each listener configures a port which can be used to access the Consul cluster
Listeners = [
  {
    Port = 8443
    Name = "service-hello-http-listener"
    Protocol = "http"
    # TLS = {
    #   Certificates = [
    #     {
    #       Kind = "inline-certificate"
    #       Name = "my-certificate"
    #     }
    #   ]
    # }
  }
]
