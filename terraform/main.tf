provider "aws" {
region = "us-east-1"
}
 
variable "region" {
default = "us-east-1"
}
 
variable "instance_type" {
default = "t2.micro"
}
 
variable "key_name" {
description = "Name of the EC2 KeyPair to allow SSH access"
default = "my-key" # Replace with your actual key pair name
}
 
variable "admin_username" {
default = "ec2-user"
}
 
variable "ami_id" {
description = "AMI ID for Ubuntu 20.04 in us-east-1 (can be changed based on region)"
default = "ami-04a37924ffe27da53" # Ubuntu 20.04 AMI in us-east-1
}
 
variable "action" {
description = "Action to perform on the EC2 instance: start or stop"
type = string
default = "none"
}
 
# Resource to create a Security Group
resource "aws_security_group" "example" {
name = "example-security-group"
description = "Allow SSH access"
vpc_id = aws_vpc.example.id
 
ingress {
description = "SSH"
from_port = 22
to_port = 22
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
 
egress {
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
}
 
# Create a VPC
resource "aws_vpc" "example" {
cidr_block = "10.0.0.0/16"
}
 
# Create a subnet
resource "aws_subnet" "example" {
vpc_id = aws_vpc.example.id
cidr_block = "10.0.1.0/24"
availability_zone = "us-east-1a"
}
 
# Create a public IP for the instance
resource "aws_eip" "example" {
instance = aws_instance.example.id
vpc = true
}
 
# Create a Network Interface
resource "aws_network_interface" "example" {
subnet_id = aws_subnet.example.id
private_ips = ["10.0.1.5"]
security_groups = [
aws_security_group.example.id
]
}
 
# EC2 Instance creation
resource "aws_instance" "example" {
ami = var.ami_id
instance_type = var.instance_type
key_name = var.key_name
associate_public_ip_address = true
network_interface {
device_index = 0
network_interface_id = aws_network_interface.example.id
}
 
tags = {
Name = "example-instance"
}
}
 
output "instance_public_ip" {
value = aws_eip.example.public_ip
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