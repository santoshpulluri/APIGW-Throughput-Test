kind = "http-route"
name = "minion-api-gateway-route"
parents = [
  {
    sectionName = "service-hello-http-listener"
    name = "minion-gateway"
    kind = "api-gateway"
  },
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
    # filters = {
    #   JWT = {
    #     Providers = [
    #       {
    #         Name = "okta", # this is referencing an existing JWT provider config entry
    #         VerifyClaims = {
    #           Path = ["perms", "role"],
    #           Value = "admin",
    #         }
    #       }
    #     ]
    #   }
    # }
    services = [
      {
        name = "service-hello"
      }
    ]
  }
]