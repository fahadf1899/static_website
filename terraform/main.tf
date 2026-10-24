terraform{
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

variable region {
    description = "The AWS region to deploy resources in"
    type        = string
    default     = "us-east-1"
}

variable ami_id {
    description = "The ID of the AMI to use for the EC2 instance"
    type        = string
    default     = "ami-02a9cdd4e98bc3c78"   # Ubuntu Server 24.04 LTS
}

variable instance_type {
    description = "The type of EC2 instance to create"
    type        = string
    default     = "t3.small"
}

variable key_name {
    description = "The name of the SSH key pair to use for the EC2 instance"
    type        = string
    default     = "my-server-key"  # Replace with your actual key pair name
}

provider "aws" {
    region = var.region
}

data "aws_vpc" "default" {
    default = true
}

resource "aws_security_group" "allow_ssh" {
    name        = "allow_ssh"
    description = "Allow SSH inbound traffic"
    vpc_id      = data.aws_vpc.default.id

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

resource "aws_instance" "web_server" {
    ami           = var.ami_id
    instance_type = var.instance_type
    key_name      = var.key_name
    security_groups = [aws_security_group.allow_ssh.name]
    associate_public_ip_address = true

    tags = {
        Name = "MyServer"
    }

      user_data = <<-EOT
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx
    systemctl enable --now nginx
  EOT
}

output "public_ip" {
    description = "The public IP address of the EC2 instance"
    value       = aws_instance.web_server.public_ip
}

output "website_url" {
    description = "The URL of the deployed website"
    value       = "http://${aws_instance.web_server.public_ip}"
}
