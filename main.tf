
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
# Look up the latest Amazon Linux 2023 AMI
data "aws_ssm_parameter" "amazon_linux" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
# 1. Create VPC
resource "aws_vpc" "exam_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "exam-vpc"
  }
}
# 2. Public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.exam_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "exam-public-subnet"
  }
}

# 3. Private subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.exam_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "exam-private-subnet"
  }
}

# 4. Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.exam_vpc.id

  tags = {
    Name = "exam-igw"
  }
}

# 5. Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.exam_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "exam-public-rt"
  }
}

# 6. Associate the public subnet with the route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
# 7. Security Group
resource "aws_security_group" "web_sg" {
  name        = "exam-web-sg"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = aws_vpc.exam_vpc.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "exam-web-sg"
  }
}
# 8. Register the SSH public key with AWS
resource "aws_key_pair" "exam_key" {
  key_name   = "terraform-exam-key"
  public_key = file(pathexpand(var.public_key_path))

  tags = {
    Name = "terraform-exam-key"
  }
}

# 9. EC2 instance in the public subnet
resource "aws_instance" "web" {
  ami                         = data.aws_ssm_parameter.amazon_linux.value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  key_name                    = aws_key_pair.exam_key.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y httpd
    systemctl enable --now httpd
    echo "<h1>Terraform AWS Exam - Web Server</h1>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "exam-web-server"
  }
}
# 10. KMS encryption key
resource "aws_kms_key" "s3_key" {
  description             = "Key for encrypting the exam logs S3 bucket"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  tags = {
    Name = "S3-KMS"
  }
}

# Requested KMS alias
resource "aws_kms_alias" "s3_key_alias" {
  name          = "alias/S3-KMS"
  target_key_id = aws_kms_key.s3_key.key_id
}
# 11. Generate a unique suffix
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# 12. Create the S3 logs bucket
resource "aws_s3_bucket" "logs" {
  bucket        = "exam-logs-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = {
    Name        = "exam-logs"
    Environment = "exam"
  }
}

# 13. Block public access
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 14. Enable SSE-KMS encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_key.arn
    }

    bucket_key_enabled = true
  }

  depends_on = [aws_kms_alias.s3_key_alias]
}
# 15. DynamoDB session storage
resource "aws_dynamodb_table" "sessions" {
  name         = "exam-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "SessionId"

  attribute {
    name = "SessionId"
    type = "S"
  }

  tags = {
    Name = "exam-sessions"
  }
}
