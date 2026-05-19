provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "available" {}

# =============================================================================
# NETWORK INFRASTRUCTURE (The "Front Porch")
# =============================================================================

resource "aws_vpc" "main_network" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "enterprise_vpc" }
}

resource "aws_internet_gateway" "main_gateway" {
  vpc_id = aws_vpc.main_network.id
  tags   = { Name = "enterprise_igw" }
}

resource "aws_subnet" "public_zone_one" {
  vpc_id                  = aws_vpc.main_network.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "public_subnet_1" }
}

resource "aws_subnet" "public_zone_two" {
  vpc_id                  = aws_vpc.main_network.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags                    = { Name = "public_subnet_2" }
}

resource "aws_route_table" "public_routing" {
  vpc_id = aws_vpc.main_network.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_gateway.id
  }
  tags = { Name = "public_route_table" }
}

resource "aws_route_table_association" "public_link_one" {
  subnet_id      = aws_subnet.public_zone_one.id
  route_table_id = aws_route_table.public_routing.id
}

resource "aws_route_table_association" "public_link_two" {
  subnet_id      = aws_subnet.public_zone_two.id
  route_table_id = aws_route_table.public_routing.id
}

# =============================================================================
# SECURITY & DATABASE (The "Honeypot")
# =============================================================================

resource "aws_security_group" "database_sg" {
  name        = "database_security_group"
  description = "Honeypot Security Group - Wide Open for Simulation"
  vpc_id      = aws_vpc.main_network.id

  # PostgreSQL
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH (Simulated Attack Port)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP (Simulated Attack Port)
  ingress {
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
}

resource "aws_db_subnet_group" "database_group" {
  name       = "enterprise_database_group"
  subnet_ids = [aws_subnet.public_zone_one.id, aws_subnet.public_zone_two.id]
  tags       = { Name = "database_subnet_group" }
}

variable "db_password" {
  description = "RDS Master Password"
  type        = string
  sensitive   = true
}

resource "aws_db_instance" "vulnerable_db" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  db_name                = "incident_db"
  username               = "db_admin"
  password               = var.db_password
  apply_immediately      = true
  db_subnet_group_name   = aws_db_subnet_group.database_group.name
  vpc_security_group_ids = [aws_security_group.database_sg.id]
  publicly_accessible    = true
  skip_final_snapshot    = true
  storage_encrypted      = true

  tags = { Name = "vulnerable_postgresql" }
}

# =============================================================================
# LOGGING & MONITORING
# =============================================================================

resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_s3_bucket" "log_storage" {
  bucket        = "enterprise-threat-logs-${random_id.bucket_id.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "log_storage_ownership" {
  bucket = aws_s3_bucket.log_storage.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_flow_log" "vpc_traffic" {
  log_destination      = aws_s3_bucket.log_storage.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main_network.id
}

resource "aws_cloudtrail" "enterprise_trail" {
  name                          = "enterprise_audit_trail"
  s3_bucket_name                = aws_s3_bucket.log_storage.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  depends_on                    = [aws_s3_bucket_policy.log_delivery_policy]
}

resource "aws_s3_bucket_policy" "log_delivery_policy" {
  bucket = aws_s3_bucket.log_storage.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSFlowLogsDeliveryWrite"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.log_storage.arn}/*"
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      },
      {
        Sid       = "AWSFlowLogsDeliveryAclCheck"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.log_storage.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.log_storage.arn}/AWSLogs/*"
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      },
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.log_storage.arn
      }
    ]
  })
}

# =============================================================================
# IAM & ALERTS (The SOC Tools)
# =============================================================================

resource "aws_iam_user" "splunk_user" {
  name = "kenny-splunk-svc" 
}

resource "aws_iam_access_key" "splunk_user_keys" {
  user = aws_iam_user.splunk_user.name
}

resource "aws_iam_user_policy" "kenny_s3_policy" {
  name = "kenny-s3-read-policy"
  user = aws_iam_user.splunk_user.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetObject"]
        Resource = [aws_s3_bucket.log_storage.arn, "${aws_s3_bucket.log_storage.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = "s3:ListAllMyBuckets"
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# OUTPUTS (The Cheat Codes)
# =============================================================================

output "db_endpoint" {
  value       = aws_db_instance.vulnerable_db.address
  description = "The endpoint of the RDS instance"
}