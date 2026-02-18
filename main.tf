# Load Generator EC2 instance
resource "aws_instance" "load_generator" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.minion-key.key_name
  tags = {
    Name = "${var.name_prefix}-load-generator"
  }
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
  vpc_security_group_ids = [aws_security_group.consul_ui_ingress.id]
  provisioner "file" {
    source      = "${path.module}/benchmark_apigw.sh"
    destination = "/tmp/benchmark_apigw.sh"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.pk.private_key_pem
      host        = self.public_ip
    }
  }
  user_data = templatefile(
    "${path.module}/shared/data-scripts/user-data-client-load-generator.sh",
    {
      hello_url      = "http://${aws_instance.apigw_service.public_ip}:8443/hello"
      hellobello_url = "http://${aws_instance.apigw_service.public_ip}:8443/hellobello"
      response_url   = "http://${aws_instance.apigw_service.public_ip}:8443/response"
    }
  )
}
provider "aws" {
  region = var.region
}

# Consul provider for managing partitions and config entries
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.20"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "consul" {
  address = "${aws_instance.consul.public_ip}:8500"
  token   = var.consul_token
}

#1.  Add a new EC2 instance for Consul.
#2.  Modify HelloService and ResponseService to include Consul configuration.

resource "aws_security_group" "consul_ui_ingress" {
  name   = "${var.name_prefix}-ui-ingress"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Consul
  ingress {
    from_port       = 8500
    to_port         = 8500
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # hello-service
  ingress {
    from_port       = 5050
    to_port         = 5050
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # response-service
  ingress {
    from_port       = 6060
    to_port         = 6060
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # api-gw
  ingress {
    from_port       = 8443
    to_port         = 8443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # envoy admin (api-gw)
  ingress {
    from_port       = 19000
    to_port         = 19000
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # envoy admin (mesh-gateway-ap1)
  ingress {
    from_port       = 19001
    to_port         = 19001
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # envoy admin (mesh-gateway-ap2)
  ingress {
    from_port       = 19002
    to_port         = 19002
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # gRPC (required for service mesh)
  ingress {
    from_port       = 8502
    to_port         = 8502
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # Consul server RPC
  ingress {
    from_port       = 8300
    to_port         = 8300
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # Consul serf LAN
  ingress {
    from_port       = 8301
    to_port         = 8301
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 8301
    to_port         = 8301
    protocol        = "udp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # Consul serf WAN
  ingress {
    from_port       = 8302
    to_port         = 8302
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 8302
    to_port         = 8302
    protocol        = "udp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # prometheus admin
  ingress {
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # grafana admin
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  # allow_all_internal_traffic
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# use ubuntu 22.04 ami
data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Add EC2 instance for Consul
resource "aws_instance" "consul" {
  instance_type = var.instance_type
  ami = data.aws_ami.ubuntu.id
  key_name      = aws_key_pair.minion-key.key_name

  # instance tags
  # ConsulAutoJoin is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.name_prefix}-consul-service-0"
    },
    {
      "ConsulAutoJoin" = "auto-join"
    },
    {
      "NomadType" = "client"
    }
  )

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  # Enables access to the metadata endpoint (http://169.254.169.254).
  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }

  # copy files from ./shared to /ops with private key permissions
  provisioner "file" {
    source      = "${path.module}/shared"
    destination = "/tmp"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.pk.private_key_pem
      host        = self.public_ip
    }
  }

  user_data = templatefile("${path.module}/shared/data-scripts/user-data-server.sh", {
    server_count = 1
    region                    = var.region
    cloud_env                 = "aws"
    retry_join                = var.retry_join
  })

  vpc_security_group_ids = [aws_security_group.consul_ui_ingress.id]
}

# Wait for Consul server to be fully ready before Consul provider tries to connect
resource "null_resource" "wait_for_consul" {
  depends_on = [aws_instance.consul]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Consul server to be ready at ${aws_instance.consul.public_ip}:8500..."
      for i in {1..90}; do
        # Check if API is reachable
        if ! curl -s -f -o /dev/null "http://${aws_instance.consul.public_ip}:8500/v1/status/leader" 2>/dev/null; then
          echo "Attempt $i/90: Consul API not reachable yet, waiting..."
          sleep 10
          continue
        fi
        
        # Check if cluster has a leader
        LEADER=$(curl -s "http://${aws_instance.consul.public_ip}:8500/v1/status/leader" 2>/dev/null | tr -d '"')
        if [ -n "$LEADER" ] && [ "$LEADER" != "" ]; then
          echo "Consul server is ready! Leader elected: $LEADER"
          # Wait an additional 15 seconds for cluster to stabilize
          echo "Waiting 15 more seconds for cluster to stabilize..."
          sleep 15
          exit 0
        fi
        
        echo "Attempt $i/90: Consul API reachable but no leader elected yet, waiting..."
        sleep 10
      done
      echo "ERROR: Consul server did not become ready after 900 seconds"
      exit 1
    EOT
  }
}

# HelloService EC2 instance
resource "aws_instance" "hello_service" {
  count = var.hello_service_count
  depends_on = [
    aws_instance.response_service,
    aws_instance.mesh_gateway_ap1,
    aws_instance.mesh_gateway_ap2,
    consul_config_entry.exported_services_ap1,
    consul_config_entry.exported_services_ap2,
    consul_config_entry.intention_hello_to_response
  ]
  ami = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.minion-key.key_name

  # instance tags
  # ConsulAutoJoin is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.name_prefix}-hello-service-${count.index}"
    },
    {
      "ConsulAutoJoin" = "auto-join"
    },
    {
      "NomadType" = "client"
    }
  )

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }

  # copy files from ./shared to /ops with private key permissions
  provisioner "file" {
    source      = "${path.module}/shared"
    destination = "/tmp"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.pk.private_key_pem
      host        = self.public_ip
    }
  }

  # initialises the instance with the runtime configuration
  user_data = templatefile("${path.module}/shared/data-scripts/user-data-client-hello.sh", {
    region                    = var.region
    cloud_env                 = "aws"
    retry_join                = var.retry_join
    index                     = count.index
  })

  vpc_security_group_ids = [aws_security_group.consul_ui_ingress.id]
}

# Update ResponseService to register with Consul
resource "aws_instance" "response_service" {
  count = var.response_service_count
  depends_on = [
    aws_instance.mesh_gateway_ap2,
    consul_config_entry.exported_services_ap2
  ]
  ami = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.minion-key.key_name

  # instance tags
  # ConsulAutoJoin is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.name_prefix}-response-service-${count.index}"
    },
    {
      "ConsulAutoJoin" = "auto-join"
    },
    {
      "NomadType" = "client"
    }
  )

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }

  # copy files from ./shared to /ops with private key permissions
  provisioner "file" {
    source      = "${path.module}/shared"
    destination = "/tmp"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.pk.private_key_pem
      host        = self.public_ip
    }
  }

  # initialises the instance with the runtime configuration
  user_data = templatefile("${path.module}/shared/data-scripts/user-data-client-response.sh", {
    region                    = var.region
    cloud_env                 = "aws"
    retry_join                = var.retry_join
    index                     = count.index
  })

  vpc_security_group_ids = [aws_security_group.consul_ui_ingress.id]
}

# Update api-gw
resource "aws_instance" "apigw_service" {
  depends_on = [
    aws_instance.hello_service,
    aws_instance.mesh_gateway_ap1,
    consul_config_entry.exported_services_ap1,
    consul_config_entry.intention_apigw_to_hello
  ]
  ami = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.minion-key.key_name

  # instance tags
  # ConsulAutoJoin is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.name_prefix}-apigw-service-1"
    },
    {
      "ConsulAutoJoin" = "auto-join"
    },
    {
      "NomadType" = "client"
    }
  )

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }

  # copy files from ./shared to /ops with private key permissions
  provisioner "file" {
    source      = "${path.module}/shared"
    destination = "/tmp"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.pk.private_key_pem
      host        = self.public_ip
    }
  }

  # initialises the instance with the runtime configuration
  user_data = templatefile("${path.module}/shared/data-scripts/user-data-client-apigw.sh", {
    region                    = var.region
    cloud_env                 = "aws"
    retry_join                = var.retry_join
  })

  vpc_security_group_ids = [aws_security_group.consul_ui_ingress.id]
}

# Mesh Gateway for AP1 Partition
resource "aws_instance" "mesh_gateway_ap1" {
  depends_on = [
    consul_admin_partition.ap1,
    consul_config_entry.proxy_defaults_ap1
  ]
  ami = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.minion-key.key_name

  # instance tags
  # ConsulAutoJoin is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.name_prefix}-mesh-gateway-ap1"
    },
    {
      "ConsulAutoJoin" = "auto-join"
    },
    {
      "NomadType" = "client"
    }
  )

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }

  # copy files from ./shared to /ops with private key permissions
  provisioner "file" {
    source      = "${path.module}/shared"
    destination = "/tmp"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.pk.private_key_pem
      host        = self.public_ip
    }
  }

  # initialises the instance with the runtime configuration
  user_data = templatefile("${path.module}/shared/data-scripts/user-data-client-mesh-gw-ap1.sh", {
    region                    = var.region
    cloud_env                 = "aws"
    retry_join                = var.retry_join
  })

  vpc_security_group_ids = [aws_security_group.consul_ui_ingress.id]
}

# Mesh Gateway for AP2 Partition
resource "aws_instance" "mesh_gateway_ap2" {
  depends_on = [
    consul_admin_partition.ap2,
    consul_config_entry.proxy_defaults_ap2
  ]
  ami = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.minion-key.key_name

  # instance tags
  # ConsulAutoJoin is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.name_prefix}-mesh-gateway-ap2"
    },
    {
      "ConsulAutoJoin" = "auto-join"
    },
    {
      "NomadType" = "client"
    }
  )

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }

  # copy files from ./shared to /ops with private key permissions
  provisioner "file" {
    source      = "${path.module}/shared"
    destination = "/tmp"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.pk.private_key_pem
      host        = self.public_ip
    }
  }

  # initialises the instance with the runtime configuration
  user_data = templatefile("${path.module}/shared/data-scripts/user-data-client-mesh-gw-ap2.sh", {
    region                    = var.region
    cloud_env                 = "aws"
    retry_join                = var.retry_join
  })

  vpc_security_group_ids = [aws_security_group.consul_ui_ingress.id]
}

# Update prometheus
resource "aws_instance" "prometheus" {
  depends_on = [aws_instance.consul, aws_instance.hello_service, aws_instance.response_service, aws_instance.apigw_service]
  ami = data.aws_ami.ubuntu.id
  instance_type = var.monitoring_instance_type
  key_name      = aws_key_pair.minion-key.key_name

  # instance tags
  # ConsulAutoJoin is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.name_prefix}-prometheus-service-1"
    },
    {
      "ConsulAutoJoin" = "auto-join"
    },
    {
      "NomadType" = "client"
    }
  )

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }

  # copy files from ./shared to /ops with private key permissions
  provisioner "file" {
    source      = "${path.module}/shared"
    destination = "/tmp"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.pk.private_key_pem
      host        = self.public_ip
    }
  }

  # initialises the instance with the runtime configuration
  user_data = templatefile("${path.module}/shared/data-scripts/user-data-client-prometheus.sh", {
    region                    = var.region
    cloud_env                 = "aws"
    retry_join                = var.retry_join
    prometheus_targets       = "${aws_instance.hello_service[0].private_ip}:8500\", \"${aws_instance.hello_service[1].private_ip}:8500\", \"${aws_instance.response_service[0].private_ip}:8500\", \"${aws_instance.response_service[1].private_ip}:8500\", \"${aws_instance.apigw_service.private_ip}:8500\", \"${aws_instance.consul.private_ip}"
  })

  vpc_security_group_ids = [aws_security_group.consul_ui_ingress.id]
}

# Update grafana
resource "aws_instance" "grafana" {
  depends_on = [aws_instance.consul, aws_instance.prometheus]
  ami = data.aws_ami.ubuntu.id
  instance_type = var.monitoring_instance_type
  key_name      = aws_key_pair.minion-key.key_name

  # instance tags
  # ConsulAutoJoin is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.name_prefix}-grafana-service-1"
    },
    {
      "ConsulAutoJoin" = "auto-join"
    },
    {
      "NomadType" = "client"
    }
  )

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }

  # copy files from ./shared to /ops with private key permissions
  provisioner "file" {
    source      = "${path.module}/shared"
    destination = "/tmp"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.pk.private_key_pem
      host        = self.public_ip
    }
  }

  # initialises the instance with the runtime configuration
  user_data = templatefile("${path.module}/shared/data-scripts/user-data-client-grafana.sh", {
    region                    = var.region
    cloud_env                 = "aws"
    retry_join                = var.retry_join
    prometheus_ip            = aws_instance.prometheus.private_ip
  })

  vpc_security_group_ids = [aws_security_group.consul_ui_ingress.id]
}


resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = var.name_prefix
  role        = aws_iam_role.instance_role.name
}

resource "aws_iam_role" "instance_role" {
  name_prefix        = var.name_prefix
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "auto_discover_cluster" {
  name   = "${var.name_prefix}-auto-discover-cluster"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.auto_discover_cluster.json
}

data "aws_iam_policy_document" "auto_discover_cluster" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "autoscaling:DescribeAutoScalingGroups",
    ]

    resources = ["*"]
  }
}




# generate a new key pair
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "minion-key" {
  key_name   = "minion-key"
  public_key = tls_private_key.pk.public_key_openssh
}

resource "local_file" "minion-key" {
  content         = tls_private_key.pk.private_key_pem
  filename        = "./minion-key.pem"
  file_permission = "0400"
}