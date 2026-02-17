variable "region" {
  description = "AWS region"
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type for main services (Consul, API Gateway, Hello, Response, Mesh Gateways)"
  default     = "m5.2xlarge"
}

variable "monitoring_instance_type" {
  description = "EC2 instance type for monitoring services (Grafana, Prometheus)"
  default     = "t2.medium"
}

variable "retry_join" {
  description = "Used by Consul to automatically form a cluster."
  type        = string
  default     = "provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"
}

variable "name_prefix" {
  description = "Prefix used to name various infrastructure components. Alphanumeric characters only."
  default     = "minion"
}

variable "response_service_count" {
  description = "Number of response service instances to create"
  default     = 2
}

variable "hello_service_count" {
  description = "Number of hello service instances to create"
  default     = 2
}

variable "consul_token" {
  description = "Consul ACL token for Terraform provider"
  type        = string
  default     = "e95b599e-166e-7d80-08ad-aee76e7ddf19"
  sensitive   = true
}
