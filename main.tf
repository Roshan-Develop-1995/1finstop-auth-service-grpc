module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.5.1"

  name = "finstop-dev-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "dev"
    Project     = "FinStop"
    Service     = "Auth"
    Terraform   = "true"
  }
}

// Create DB subnet group
resource "aws_db_subnet_group" "auth_db" {
  name        = "finstop-dev-db-subnet-group"
  description = "Subnet group for RDS instance"
  subnet_ids  = module.vpc.private_subnets

  tags = {
    Name        = "finstop-dev-db-subnet-group"
    Environment = "dev"
    Project     = "FinStop"
    Service     = "Auth"
    Terraform   = "true"
  }
}

// Create security group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "finstop-dev-rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_service_sg.id]
  }

  tags = {
    Name        = "finstop-dev-rds-sg"
    Environment = "dev"
    Project     = "FinStop"
    Service     = "Auth"
    Terraform   = "true"
  }
}

// Create security group for ECS service
resource "aws_security_group" "ecs_service_sg" {
  name        = "finstop-dev-ecs-service-sg"
  description = "Security group for ECS service"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 9090
    to_port     = 9090
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
    Name        = "finstop-dev-ecs-service-sg"
    Environment = "dev"
    Project     = "FinStop"
    Service     = "Auth"
    Terraform   = "true"
  }
}

resource "aws_db_parameter_group" "auth_db" {
  name   = "finstop-dev-auth-db-pg"
  family = "aurora-postgresql16"

  parameter {
    name  = "client_encoding"
    value = "UTF8"
  }

  parameter {
    name  = "timezone"
    value = "UTC"
  }

  tags = {
    Name        = "finstop-dev-auth-db-pg"
    Environment = "dev"
    Project     = "FinStop"
    Service     = "Auth"
    Terraform   = "true"
  }
}

resource "aws_rds_cluster_parameter_group" "auth_db" {
  name   = "finstop-dev-auth-db-cluster-pg"
  family = "aurora-postgresql16"

  parameter {
    name  = "timezone"
    value = "UTC"
  }

  tags = {
    Name        = "finstop-dev-auth-db-cluster-pg"
    Environment = "dev"
    Project     = "FinStop"
    Service     = "Auth"
    Terraform   = "true"
  }
}

resource "aws_rds_cluster" "auth_db" {
  cluster_identifier     = "finstop-development-auth-db"
  engine                = "aurora-postgresql"
  engine_version        = "16.6"
  database_name         = "finstop_auth"
  master_username       = var.db_username
  master_password       = var.db_password
  
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.auth_db.name
  
  skip_final_snapshot     = true
  deletion_protection     = false
  storage_encrypted      = true
  
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.auth_db.name
  
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1d"]
  
  tags = {
    Name        = "finstop-development-auth-db"
    Environment = "dev"
    Project     = "FinStop"
    Service     = "Auth"
    Terraform   = "true"
  }
}

resource "aws_rds_cluster_instance" "auth_db_instances" {
  count               = 2
  identifier          = count.index == 0 ? "auth-service-app-user-instance-1" : "auth-service-app-reader-instance-1"
  cluster_identifier  = aws_rds_cluster.auth_db.id
  instance_class      = "db.t3.medium"
  engine             = aws_rds_cluster.auth_db.engine
  engine_version     = aws_rds_cluster.auth_db.engine_version
  
  db_parameter_group_name = aws_db_parameter_group.auth_db.name
  
  publicly_accessible    = false
  
  tags = {
    Name        = count.index == 0 ? "finstop-dev-auth-db-writer" : "finstop-dev-auth-db-reader"
    Environment = "dev"
    Project     = "FinStop"
    Service     = "Auth"
    Terraform   = "true"
  }
}

// Update security group rules
resource "aws_security_group_rule" "rds_inbound" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  security_group_id = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.ecs_service_sg.id
}

resource "aws_security_group_rule" "rds_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.rds_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
} 