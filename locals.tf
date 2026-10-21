# -----------------------------------------------------------------------------
# locals.tf
#
# Locals são "variáveis internas": valores calculados uma vez e reutilizados.
# Diferente de `variable`, quem usa o projeto não consegue sobrescrevê-los.
# Uso para evitar repetição (DRY) e para dar nome a expressões complicadas.
# -----------------------------------------------------------------------------

locals {
  # Prefixo padrão dos nomes: ex. "webapp-dev-vpc", "webapp-dev-web".
  name_prefix = "${var.project_name}-${var.environment}"

  # Tags aplicadas em tudo via default_tags (providers.tf).
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # As duas primeiras AZs disponíveis na região escolhida. Buscar via data
  # source (main.tf), em vez de escrever "us-east-1a", faz o código funcionar
  # igual em us-east-1 e us-west-2. Duas AZs = alta disponibilidade básica.
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # Mapas de subnets no formato que o módulo vpc espera:
  #   { "<chave estável>" = { cidr_block = "...", az = "..." } }
  #
  # cidrsubnet(vpc_cidr, 8, n) pega a VPC /16 e devolve a n-ésima /24:
  #   públicas : n = 0, 1   -> 10.0.0.0/24,  10.0.1.0/24
  #   privadas : n = 10, 11 -> 10.0.10.0/24, 10.0.11.0/24
  # O "salto" para 10 deixa espaço para crescer as públicas sem colidir.
  #
  # A chave usa o nome da AZ (ex. "public-us-east-1a"), e não um índice, para
  # que o for_each do módulo identifique cada subnet de forma estável.
  public_subnets = {
    for index, az in local.azs : "public-${az}" => {
      cidr_block = cidrsubnet(var.vpc_cidr, 8, index)
      az         = az
    }
  }

  private_subnets = {
    for index, az in local.azs : "private-${az}" => {
      cidr_block = cidrsubnet(var.vpc_cidr, 8, index + 10)
      az         = az
    }
  }
}
