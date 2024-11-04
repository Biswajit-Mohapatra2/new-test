# Provider configuration
provider "aws" {
  region = "ap-south-1"
}

# Variables for configuration
variable "region" {
  default = "ap-south-1"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "key_name" {
  description = "Name of the EC2 KeyPair to allow SSH access"
  default     = "my-key" # Replace with your actual key pair name
}

variable "admin_username" {
  default = "ec2-user"
}

variable "ami_id" {
  description = "AMI ID for Amazon linux in ap-south-1 (can be changed based on region)"
  default     = "ami-04a37924ffe27da53" # Ubuntu 20.04 AMI in ap-south-1
}

variable "action" {
  description = "Action to perform on the EC2 instance: start or stop"
  type        = string
  default     = "none"
}

# Resource to create a Security Group
resource "aws_security_group" "example" {
  name        = "example-security-group"
  description = "Allow SSH access"
  vpc_id      = aws_vpc.example.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a VPC
resource "aws_vpc" "example" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

# Create an Internet Gateway
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id
}

# Create a subnet
resource "aws_subnet" "example" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
}

# Create a route table
resource "aws_route_table" "example" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example.id
  }
}

# Associate the route table with the subnet
resource "aws_route_table_association" "example" {
  subnet_id      = aws_subnet.example.id
  route_table_id = aws_route_table.example.id
}

# Create a public IP for the instance
resource "aws_eip" "example" {
  instance = aws_instance.example.id
  vpc      = true
}

# EC2 Instance creation
resource "aws_instance" "example" {
  ami                    = var.ami_id
  instance_type         = var.instance_type
  key_name              = var.key_name
  subnet_id             = aws_subnet.example.id
  security_groups       = [aws_security_group.example.name]

  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }

  tags = {
    Name = "example-instance"
  }
}

# Outputs for connection and networking
output "ssh_connection_string" {
  description = "SSH connection string to connect to the instance"
  value       = "ssh -i ${var.key_name}.pem ${var.admin_username}@${aws_eip.example.public_ip}"
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.example.id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = aws_subnet.example.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.example.id
}

# Resource to Start EC2 Instance
resource "null_resource" "start_instance" {
  count = var.action == "start" ? 1 : 0

  provisioner "local-exec" {
    command = <<EOT
aws ec2 start-instances --instance-ids ${aws_instance.example.id}
EOT
  }

  triggers = {
    instance_id = aws_instance.example.id
  }
}

# Resource to Stop EC2 Instance
resource "null_resource" "stop_instance" {
  count = var.action == "stop" ? 1 : 0

  provisioner "local-exec" {
    command = <<EOT
aws ec2 stop-instances --instance-ids ${aws_instance.example.id}
EOT
  }

  triggers = {
    instance_id = aws_instance.example.id
  }
}
