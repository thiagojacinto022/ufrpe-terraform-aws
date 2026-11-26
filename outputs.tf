# -----------------------------------------------------------------------------
# outputs.tf
#
# Outputs são os "valores de retorno" do projeto: aparecem no fim do `apply`
# e podem ser consultados depois com `terraform output`. Também servem para
# outra configuração Terraform consumir estes dados no futuro.
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID da VPC criada."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Mapa das subnets públicas (chave => ID)."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Mapa das subnets privadas (chave => ID)."
  value       = module.vpc.private_subnet_ids
}

output "web_instance_id" {
  description = "ID da instância EC2 do servidor web."
  value       = aws_instance.web.id
}

output "web_public_ip" {
  description = "IP público da instância EC2."
  value       = aws_instance.web.public_ip
}

output "alb_dns_name" {
  description = "DNS do Application Load Balancer."
  value       = aws_lb.app.dns_name
}

output "app_url" {
  description = "URL pública da aplicação, pelo ALB."
  value       = "http://${aws_lb.app.dns_name}"
}

output "ssh_command" {
  description = "Comando pronto para acessar a instância (chave labsuser.pem do Learner Lab)."
  value       = "ssh -i labsuser.pem ec2-user@${aws_instance.web.public_ip}"
}

output "grafana_tunnel_command" {
  description = "Túnel SSH para abrir o Grafana em http://localhost:3000."
  value       = "ssh -i labsuser.pem -L 3000:localhost:3000 ec2-user@${aws_instance.web.public_ip}"
}

output "ecr_backend_url" {
  description = "URL do repositório ECR do backend."
  value       = aws_ecr_repository.app["backend"].repository_url
}

output "ecr_frontend_url" {
  description = "URL do repositório ECR do frontend."
  value       = aws_ecr_repository.app["frontend"].repository_url
}

output "db_endpoint" {
  description = "Endpoint do RDS (host:porta)."
  value       = aws_db_instance.main.endpoint
}

output "db_address" {
  description = "Host do RDS, sem a porta."
  value       = aws_db_instance.main.address
}
