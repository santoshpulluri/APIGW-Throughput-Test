
kind = "http-route"
name = "minion-api-gateway-route"
parents = [
  {
    sectionName = "service-hello-http-listener"
    name = "minion-gateway"
    kind = "api-gateway"
  }
]
rules = [
  {
    Matches = [
      {
        Path = {
          Match = "prefix"
          Value = "/hello"
        }
      }
    ]
    services = [
      {
        name = "service-hello"
        partition = "ap1"
      }
    ]
  },
  {
    Matches = [
      {
        Path = {
          Match = "prefix"
          Value = "/response"
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