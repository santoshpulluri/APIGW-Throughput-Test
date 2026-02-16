variable "region" {
  description = "AWS region"
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type"
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
