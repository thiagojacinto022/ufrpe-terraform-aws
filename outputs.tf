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

output "web_url" {
  description = "URL para testar o nginx no navegador."
  value       = "http://${aws_instance.web.public_dns}"
}

output "ssh_command" {
  description = "Comando pronto para acessar a instância (chave labsuser.pem do Learner Lab)."
  value       = "ssh -i labsuser.pem ec2-user@${aws_instance.web.public_ip}"
}
