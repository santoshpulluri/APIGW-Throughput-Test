kind = "http-route"
name = "minion-api-gateway-route"

# Defines which gateway and listener this route attaches to
parents = [
  {
    kind        = "api-gateway"
    name        = "minion-gateway"
    sectionName = "service-hello-http-listener"
  }
]

rules = [
  # Rule 1: Routes prefix /hello to service-hello
  {
    matches = [
      {
        path = {
          match = "prefix"
          value = "/hello"
        }
      }
    ]
    services = [
      {
        name      = "service-hello"
        partition = "ap1"
      }
    ]
  },

  # Rule 2: Routes prefix /response to service-response
  {
    matches = [
      {
        path = {
          match = "prefix"
          value = "/response"
        }
      }
    ]
    services = [
      {
        name = "service-response"
        partition = "ap2"
      }
    ]
  }
]