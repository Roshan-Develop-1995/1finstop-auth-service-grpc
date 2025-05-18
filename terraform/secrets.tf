# Random password for JWT secret
resource "random_password" "jwt_secret" {
  length           = 32
  special          = true
  override_special = "!@#$%^&*()_+-=[]{}|;:,.<>?"
}

# Database Credentials Secret
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "finstop-${var.environment}/auth-service/db-credentials"
  recovery_window_in_days = 0  # Force immediate deletion
  force_overwrite_replica_secret = true

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
  name                    = "finstop-${var.environment}/auth-service/jwt-secret-v2"
  recovery_window_in_days = 0  # Force immediate deletion
  force_overwrite_replica_secret = true

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id = aws_secretsmanager_secret.jwt_secret.id
  secret_string = random_password.jwt_secret.result
}

# Output the JWT secret ARN (but not the value for security)
output "jwt_secret_arn" {
  description = "ARN of the JWT secret"
  value       = aws_secretsmanager_secret.jwt_secret.arn
} 