Kind = "exported-services"
Name = "ap1"
Partition = "ap1"
Services = [
  {
    Name = "mesh-gateway"
    Consumers = [
      {
        Partition = "default"
      }
    ]
  },
  {
    Name = "service-hello"
    Consumers = [
      {
        Partition = "default"
      }
    ]
  }
]
