module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "finstop-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway = true
  single_nat_gateway = true  # Always use single NAT gateway in dev

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

// Create DB subnet group
resource "aws_db_subnet_group" "auth_db" {
  name_prefix = "finstop-${var.environment}-db-subnet-"
  description = "Subnet group for RDS instance"
  subnet_ids  = module.vpc.private_subnets

  tags = merge(local.common_tags, {
    Name = "finstop-${var.environment}-db-subnet-group"
  })

  lifecycle {
    create_before_destroy = true
  }
}

// Create security group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "finstop-${var.environment}-rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_service_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "finstop-${var.environment}-rds-sg"
  })
}

// Create security group for ECS service
resource "aws_security_group" "ecs_service_sg" {
  name        = "finstop-${var.environment}-ecs-service-sg"
  description = "Security group for ECS service"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "finstop-${var.environment}-ecs-service-sg"
  })
}

resource "aws_db_parameter_group" "aurora_instance_postgres16" {
  family = "aurora-postgresql16"
  name   = "finstop-${var.environment}-aurora-instance-pg16"

  tags = merge(local.common_tags, {
    Name = "finstop-${var.environment}-aurora-instance-pg16"
  })
}

resource "aws_rds_cluster_parameter_group" "aurora_cluster_postgres16" {
  family = "aurora-postgresql16"
  name   = "finstop-${var.environment}-aurora-pg16"

  parameter {
    name  = "timezone"
    value = "UTC"
  }

  tags = merge(local.common_tags, {
    Name = "finstop-${var.environment}-aurora-pg16"
  })
}

resource "aws_rds_cluster" "aurora_postgres_cluster" {
  cluster_identifier     = "finstop-${var.environment}-auth-db"
  engine                = "aurora-postgresql"
  engine_version        = "16.6"
  database_name         = "finstop_auth"
  master_username       = var.db_username
  master_password       = var.db_password
  
  db_subnet_group_name   = aws_db_subnet_group.auth_db.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_cluster_postgres16.name
  
  backup_retention_period = 1  # Fixed to 1 day for dev
  preferred_backup_window = "03:00-04:00"
  skip_final_snapshot    = true  # Always skip final snapshot in dev
  
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  tags = local.common_tags
}

resource "aws_rds_cluster_instance" "aurora_postgres_instance" {
  count               = 1  # Fixed to 1 instance for dev
  identifier          = "finstop-${var.environment}-auth-db-${count.index + 1}"
  cluster_identifier  = aws_rds_cluster.aurora_postgres_cluster.id
  instance_class      = "db.t3.medium"
  engine              = "aurora-postgresql"
  engine_version      = "16.6"
  
  db_parameter_group_name = aws_db_parameter_group.aurora_instance_postgres16.name
  
  publicly_accessible    = false
  
  tags = local.common_tags
}

# ECS Service
resource "aws_ecs_service" "auth_service" {
  name            = "finstop-${var.environment}-auth-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.auth_service.arn
  desired_count   = 1  # Fixed to 1 for dev
  launch_type     = "FARGATE"
  force_new_deployment = true

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.auth_service.arn
    container_name   = "auth-service"
    container_port   = 9090
  }

  tags = local.common_tags

  depends_on = [aws_lb_listener.http, aws_lb_listener.https]
} 