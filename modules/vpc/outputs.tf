# Saídas do módulo: é a "interface pública" dele. O root só enxerga o que for
# exposto aqui (ex.: module.vpc.vpc_id), o resto fica encapsulado.

output "vpc_id" {
  description = "ID da VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "Bloco CIDR da VPC."
  value       = aws_vpc.this.cidr_block
}

# Devolvo mapas (chave => id) em vez de listas para preservar as chaves
# estáveis do for_each: quem consome escolhe a subnet pelo nome, não pela posição.
output "public_subnet_ids" {
  description = "Mapa das subnets públicas: chave => ID."
  value       = { for key, subnet in aws_subnet.public : key => subnet.id }
}

output "private_subnet_ids" {
  description = "Mapa das subnets privadas: chave => ID."
  value       = { for key, subnet in aws_subnet.private : key => subnet.id }
}

output "internet_gateway_id" {
  description = "ID do Internet Gateway."
  value       = aws_internet_gateway.this.id
}
