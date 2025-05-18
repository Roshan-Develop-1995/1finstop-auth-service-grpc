variable "db_username" {
  description = "Username for the RDS database"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Password for the RDS database"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Local variables for common tags
locals {
  common_tags = {
    Environment = var.environment
    Project     = "FinStop"
    Service     = "Auth"
    Terraform   = "true"
  }
} 