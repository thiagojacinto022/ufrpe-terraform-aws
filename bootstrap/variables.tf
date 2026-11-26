variable "aws_region" {
  description = "Região da AWS. O Learner Lab só permite us-east-1 e us-west-2."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = contains(["us-east-1", "us-west-2"], var.aws_region)
    error_message = "O Learner Lab só permite as regiões us-east-1 ou us-west-2."
  }
}

variable "project_name" {
  description = "Nome curto do projeto. Deve ser o mesmo usado no Terraform da raiz."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project_name))
    error_message = "Use de 3 a 20 caracteres: letras minúsculas, números ou hífen."
  }
}

variable "environment" {
  description = "Ambiente da infraestrutura (dev, hml ou prod). Deve ser o mesmo usado na raiz."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "hml", "prod"], var.environment)
    error_message = "O ambiente deve ser dev, hml ou prod."
  }
}

variable "noncurrent_version_retention_days" {
  description = "Dias que as versões antigas do state são mantidas antes de expirar."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_retention_days >= 7
    error_message = "Mantenha as versões antigas por pelo menos 7 dias."
  }
}
