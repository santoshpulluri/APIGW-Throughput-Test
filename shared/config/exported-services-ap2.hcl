Kind = "exported-services"
Name = "ap2"
Partition = "ap2"
Services = [
  {
    Name = "mesh-gateway"
    Consumers = [
      {
        Partition = "ap1"
      }
    ]
  },
  {
    Name = "service-response"
    Consumers = [
      {
        Partition = "ap1"
      }
    ]
  }
]
