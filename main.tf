# --- Provider Configuration ---
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.9.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Fetches the AWS Account ID for custom pricing (this is not completed yet)
# data "aws_caller_identity" "current" {}

# --- Network Infrastructure ---

# Create a VPC for our resources
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "cloudability-test-vpc"
    Environment = "testing"
    cost-center = "engineering-research"
  }
}

# Create an internet gateway to provide internet access
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "cloudability-test-igw"
    Environment = "testing"
    cost-center = "engineering-research"
  }
}

# Create a public subnet for our EC2 instance
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "cloudability-test-public-subnet"
    Environment = "testing"
    cost-center = "engineering-research"
  }
}

# Create a route table for the public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "cloudability-test-public-rt"
    Environment = "testing"
    cost-center = "engineering-research"
  }
}

# Associate the route table with the public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# --- Infrastructure Resources ---

# 1. INTENTIONAL POLICY VIOLATION
# This EC2 instance is missing the 'cost-center' tag, which should
# cause your Cloudability policy check to fail.
resource "aws_instance" "test_vm" {
  ami                    = "ami-0ff8a91507f77f867" # Amazon Linux AMI (us-east-1)
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  tags = {
    Name        = "Cloudability-Run-Task-Test"
    Environment = "testing"
    // Notice: The 'cost-center' tag is missing!
  }
}

# 2. RESOURCE FOR COST ESTIMATION
# This S3 bucket will be used to test the cost estimation feature
# based on the values provided in the usage.json file.
resource "aws_s3_bucket" "test_bucket" {
  bucket = "cloudability-run-task-test-bucket-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "Cloudability-Run-Task-Test-Bucket"
    Environment = "testing"
    cost-center = "engineering-research" // This one is compliant
  }
}

# Helper to ensure the S3 bucket name is unique
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Security group for the EC2 instance
resource "aws_security_group" "instance_sg" {
  name        = "cloudability-test-sg"
  description = "Security group for test instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "cloudability-test-sg"
    Environment = "testing"
    cost-center = "engineering-research"
  }
}