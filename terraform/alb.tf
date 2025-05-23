# Application Load Balancer
resource "aws_lb" "auth_service" {
  name               = "finstop-${var.environment}-auth-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets           = module.vpc.public_subnets

  enable_deletion_protection = false # Set to true for production

  tags = local.common_tags
}

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "finstop-${var.environment}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# ALB Target Group
resource "aws_lb_target_group" "auth_service" {
  name        = "finstop-${var.environment}-auth-tg"
  port        = 9090
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher            = "200"
    path               = "/actuator/health"
    port               = "traffic-port"
    protocol           = "HTTP"
    timeout            = 5
    unhealthy_threshold = 3
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  tags = local.common_tags
}

# HTTP Listener - Redirect to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.auth_service.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.auth_service.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.auth_service.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth_service.arn
  }

  depends_on = [aws_acm_certificate_validation.auth_service]
}

# ACM Certificate
resource "aws_acm_certificate" "auth_service" {
  domain_name       = "auth.${var.domain_name}"
  validation_method = "DNS"

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# DNS Validation Record
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.auth_service.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

# Certificate Validation
resource "aws_acm_certificate_validation" "auth_service" {
  certificate_arn         = aws_acm_certificate.auth_service.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Route53 Record for the ALB
resource "aws_route53_record" "auth_service" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "auth.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.auth_service.dns_name
    zone_id                = aws_lb.auth_service.zone_id
    evaluate_target_health = true
  }
}

# Output the ALB DNS names
output "auth_service_url" {
  description = "URL of the auth service"
  value       = "https://auth.${var.domain_name}"
}

output "auth_service_alb_dns" {
  description = "ALB DNS name"
  value       = aws_lb.auth_service.dns_name
} 