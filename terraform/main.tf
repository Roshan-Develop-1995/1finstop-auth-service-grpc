terraform {
  backend "s3" {
    bucket         = "finstop-tf-auth-service"
    key            = "env:/dev/auth-service/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# VPC and Network Configuration
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "finstop-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway = true
  single_nat_gateway = true  # Always use single NAT gateway in dev

  tags = local.common_tags
}

# Security Group for RDS
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

  tags = merge(local.common_tags, {
    Name = "finstop-${var.environment}-rds-sg"
  })
}

# Security Group for ECS Service
resource "aws_security_group" "ecs_service_sg" {
  name        = "finstop-${var.environment}-ecs-service-sg"
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

  tags = merge(local.common_tags, {
    Name = "finstop-${var.environment}-ecs-service-sg"
  })
}

# DB Subnet Group
resource "aws_db_subnet_group" "auth_db" {
  name        = "finstop-${var.environment}-db-subnet-group"
  description = "Subnet group for RDS instance"
  subnet_ids  = module.vpc.private_subnets

  tags = merge(local.common_tags, {
    Name = "finstop-${var.environment}-db-subnet-group"
  })
}

# DB Parameter Group for Aurora PostgreSQL 16
resource "aws_rds_cluster_parameter_group" "aurora_cluster_postgres16" {
  family = "aurora-postgresql16"
  name   = "finstop-${var.environment}-aurora-pg16"

  tags = merge(local.common_tags, {
    Name = "finstop-${var.environment}-aurora-pg16"
  })
}

resource "aws_db_parameter_group" "aurora_instance_postgres16" {
  family = "aurora-postgresql16"
  name   = "finstop-${var.environment}-aurora-instance-pg16"

  tags = merge(local.common_tags, {
    Name = "finstop-${var.environment}-aurora-instance-pg16"
  })
}

# Aurora PostgreSQL Cluster
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

# Aurora PostgreSQL Instance
resource "aws_rds_cluster_instance" "aurora_postgres_instance" {
  count               = 1  # Fixed to 1 instance for dev
  identifier          = "finstop-${var.environment}-auth-db-${count.index + 1}"
  cluster_identifier  = aws_rds_cluster.aurora_postgres_cluster.id
  instance_class      = "db.t3.medium"
  engine              = "aurora-postgresql"
  engine_version      = "16.6"
  
  db_parameter_group_name = aws_db_parameter_group.aurora_instance_postgres16.name
  
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.auth_db.name
  
  tags = local.common_tags
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "finstop-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

# ECS Task Definition
resource "aws_ecs_task_definition" "auth_service" {
  family                   = "finstop-${var.environment}-auth-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"  # Fixed to dev size
  memory                   = "512"  # Fixed to dev size
  execution_role_arn      = aws_iam_role.ecs_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "auth-service"
      image = "${aws_ecr_repository.auth_service.repository_url}:latest"
      portMappings = [
        {
          containerPort = 9090
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = var.environment
        },
        {
          name  = "SPRING_DATASOURCE_URL"
          value = "jdbc:postgresql://${aws_rds_cluster.aurora_postgres_cluster.endpoint}:5432/${aws_rds_cluster.aurora_postgres_cluster.database_name}"
        }
      ]
      secrets = [
        {
          name      = "SPRING_DATASOURCE_USERNAME"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:username::"
        },
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:password::"
        },
        {
          name      = "JWT_SECRET"
          valueFrom = "${aws_secretsmanager_secret.jwt_secret.arn}:secret::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/finstop-${var.environment}-auth-service"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
          awslogs-create-group  = "true"
        }
      }
      essential = true
    }
  ])

  tags = merge(local.common_tags, {
    DeploymentTime = timestamp()
  })
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
  }

  tags = local.common_tags
}

# Add necessary IAM permissions for the ECS execution role
resource "aws_iam_role_policy" "ecs_execution_role_permissions" {
  name = "finstop-${var.environment}-ecs-execution-permissions"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:ListInstanceProfilesForRole",
          "iam:PassRole",
          "iam:GetRole"
        ]
        Resource = [
          aws_iam_role.ecs_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      }
    ]
  })
} 