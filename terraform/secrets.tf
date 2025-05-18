# Database Credentials Secret
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "finstop-${var.environment}/auth-service/db-credentials"
  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}

# JWT Secret
resource "aws_secretsmanager_secret" "jwt_secret" {
  name = "finstop-${var.environment}/auth-service/jwt-secret"
  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id = aws_secretsmanager_secret.jwt_secret.id
  secret_string = jsonencode({
    secret = random_password.jwt_secret.result
  })
}

resource "random_password" "jwt_secret" {
  length  = 32
  special = true
} 