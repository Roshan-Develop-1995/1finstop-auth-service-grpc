resource "aws_secretsmanager_secret" "db_credentials" {
  name = "finstop-dev/auth-service/db-credentials-${formatdate("YYYYMMDD-HHmmss", timestamp())}"
  
  tags = {
    Name        = "Database Credentials"
    Environment = "dev"
    Project     = "FinStop"
    Service     = "Auth"
    Terraform   = "true"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name = "finstop-dev/auth-service/jwt-secret-${formatdate("YYYYMMDD-HHmmss", timestamp())}"
  
  tags = {
    Name        = "JWT Secret"
    Environment = "dev"
    Project     = "FinStop"
    Service     = "Auth"
    Terraform   = "true"
  }
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = random_password.jwt_secret.result
} 