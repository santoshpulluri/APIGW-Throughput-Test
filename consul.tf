# ===================================================================
# Consul Admin Partitions and Configuration
# ===================================================================

# Proxy defaults to enable mesh gateway mode for cross-partition communication
resource "consul_config_entry" "proxy_defaults_default" {
  name = "global"
  kind = "proxy-defaults"
  
  config_json = jsonencode({
    Protocol = "http"
    MeshGateway = {
      Mode = "local"
    }
  })
  
  depends_on = [null_resource.wait_for_consul]
}

resource "consul_config_entry" "proxy_defaults_ap1" {
  name      = "global"
  kind      = "proxy-defaults"
  partition = "ap1"
  
  config_json = jsonencode({
    Protocol = "http"
    MeshGateway = {
      Mode = "local"
    }
  })
  
  depends_on = [consul_admin_partition.ap1]
}

resource "consul_config_entry" "proxy_defaults_ap2" {
  name      = "global"
  kind      = "proxy-defaults"
  partition = "ap2"
  
  config_json = jsonencode({
    Protocol = "http"
    MeshGateway = {
      Mode = "local"
    }
  })
  
  depends_on = [consul_admin_partition.ap2]
}

# Service defaults for service-hello (AP1) - explicitly set protocol
resource "consul_config_entry" "service_defaults_hello" {
  name      = "service-hello"
  kind      = "service-defaults"
  partition = "ap1"
  
  config_json = jsonencode({
    Protocol = "http"
  })
  
  depends_on = [consul_admin_partition.ap1]
}

# Service defaults for service-response (AP2) - explicitly set protocol
resource "consul_config_entry" "service_defaults_response" {
  name      = "service-response"
  kind      = "service-defaults"
  partition = "ap2"
  
  config_json = jsonencode({
    Protocol = "http"
  })
  
  depends_on = [consul_admin_partition.ap2]
}

# Create Admin Partition AP1 for Hello Service
resource "consul_admin_partition" "ap1" {
  name        = "ap1"
  description = "Admin Partition for Hello Service"
  
  depends_on = [null_resource.wait_for_consul]
}

# Create Admin Partition AP2 for Response Service
resource "consul_admin_partition" "ap2" {
  name        = "ap2"
  description = "Admin Partition for Response Service"
  
  depends_on = [null_resource.wait_for_consul]
}

# Export service-hello AND mesh-gateway from AP1 to default partition (for API Gateway access)
resource "consul_config_entry" "exported_services_ap1" {
  name      = "ap1"
  kind      = "exported-services"
  partition = "ap1"
  
  config_json = jsonencode({
    Services = [
      {
        Name = "mesh-gateway"
        Consumers = [{
          Partition = "default"
        }]
      },
      {
        Name = "service-hello"
        Consumers = [{
          Partition = "default"
        }]
      }
    ]
  })
  
  depends_on = [consul_admin_partition.ap1]
}

# Export service-response AND mesh-gateway from AP2 to AP1 (for hello service access)
resource "consul_config_entry" "exported_services_ap2" {
  name      = "ap2"
  kind      = "exported-services"
  partition = "ap2"
  
  config_json = jsonencode({
    Services = [
      {
        Name = "mesh-gateway"
        Consumers = [{
          Partition = "ap1"
        }]
      },
      {
        Name = "service-response"
        Consumers = [{
          Partition = "ap1"
        }]
      }
    ]
  })
  
  depends_on = [consul_admin_partition.ap2]
}

# ===================================================================
# Service Intentions for Cross-Partition Communication
# ===================================================================

# Allow service-hello (AP1) to call service-response (AP2)
resource "consul_config_entry" "intention_hello_to_response" {
  name      = "service-response"
  kind      = "service-intentions"
  partition = "ap2"
  
  config_json = jsonencode({
    Sources = [
      {
        Name      = "service-hello"
        Partition = "ap1"
        Action    = "allow"
      }
    ]
  })
  
  depends_on = [
    consul_admin_partition.ap1,
    consul_admin_partition.ap2,
    consul_config_entry.exported_services_ap1,
    consul_config_entry.exported_services_ap2
  ]
}

# Allow API Gateway (default partition) to call service-hello (AP1)
resource "consul_config_entry" "intention_apigw_to_hello" {
  name      = "service-hello"
  kind      = "service-intentions"
  partition = "ap1"
  
  config_json = jsonencode({
    Sources = [
      {
        Name      = "minion-gateway"
        Partition = "default"
        Action    = "allow"
      }
    ]
  })
  
  depends_on = [
    consul_admin_partition.ap1,
    consul_config_entry.exported_services_ap1
  ]
}
