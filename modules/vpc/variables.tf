# -----------------------------------------------------------------------------
# Entradas do módulo vpc.
#
# O módulo não sabe nada sobre "projeto", "Learner Lab" ou região: recebe só o
# que precisa para montar a rede. Isso o torna genérico e reutilizável.
# -----------------------------------------------------------------------------

variable "name_prefix" {
  description = "Prefixo usado na tag Name de todos os recursos de rede (ex.: webapp-dev)."
  type        = string
}

variable "vpc_cidr" {
  description = "Bloco CIDR IPv4 da VPC."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr deve ser um CIDR IPv4 válido."
  }
}

variable "public_subnets" {
  description = "Subnets públicas: mapa de chave estável => { cidr_block, az }."
  type = map(object({
    cidr_block = string
    az         = string
  }))

  validation {
    # O enunciado pede pelo menos duas AZs diferentes (alta disponibilidade).
    condition     = length(distinct([for s in values(var.public_subnets) : s.az])) >= 2
    error_message = "As subnets públicas devem estar em pelo menos 2 AZs diferentes."
  }
}

variable "private_subnets" {
  description = "Subnets privadas: mapa de chave estável => { cidr_block, az }."
  type = map(object({
    cidr_block = string
    az         = string
  }))

  validation {
    condition     = length(distinct([for s in values(var.private_subnets) : s.az])) >= 2
    error_message = "As subnets privadas devem estar em pelo menos 2 AZs diferentes."
  }
}
