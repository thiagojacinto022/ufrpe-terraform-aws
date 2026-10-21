# -----------------------------------------------------------------------------
# variables.tf
#
# Variáveis são os "parâmetros de entrada" do projeto. Tudo que pode mudar
# entre ambientes ou pessoas (região, meu IP, tamanho da máquina...) fica aqui,
# em vez de escrito fixo no código.
#
# Cada variável tem:
#   - type: o Terraform recusa valores do tipo errado logo no plan;
#   - description: documenta para quem for usar (aparece em ferramentas e docs);
#   - validation (quando faz sentido): pega erros ANTES de chamar a AWS.
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "Região da AWS. O AWS Academy Learner Lab só permite us-east-1 e us-west-2."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = contains(["us-east-1", "us-west-2"], var.aws_region)
    error_message = "O Learner Lab só permite as regiões us-east-1 ou us-west-2."
  }
}

variable "project_name" {
  description = "Nome curto do projeto, usado como prefixo nos nomes e nas tags dos recursos."
  type        = string

  validation {
    # Letras minúsculas, números e hífen: formato aceito em nomes de quase
    # todos os recursos da AWS (alguns, como buckets S3, recusam maiúsculas).
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project_name))
    error_message = "Use de 3 a 20 caracteres: letras minúsculas, números ou hífen."
  }
}

variable "environment" {
  description = "Ambiente da infraestrutura (dev, hml ou prod). Entra nos nomes e nas tags."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "hml", "prod"], var.environment)
    error_message = "O ambiente deve ser dev, hml ou prod."
  }
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC. As subnets /24 são calculadas a partir dele em locals.tf."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    # cidrhost() falha se o texto não for um CIDR válido; can() transforma
    # essa falha em false, que dispara a mensagem de erro abaixo.
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Informe um CIDR IPv4 válido, por exemplo 10.0.0.0/16."
  }

  validation {
    # A AWS aceita VPCs de /16 (maior) a /28 (menor). Como as subnets são
    # calculadas somando 8 bits (/16 + 8 = /24), fixo a VPC em /16.
    condition     = endswith(var.vpc_cidr, "/16")
    error_message = "Nesta etapa a VPC deve ser /16 (as subnets são /24 calculadas com cidrsubnet)."
  }
}

variable "instance_type" {
  description = "Tipo da instância EC2. Limitado a tipos pequenos permitidos/baratos no Learner Lab."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro"], var.instance_type)
    error_message = "Use t2.micro ou t3.micro."
  }
}

variable "allowed_ssh_cidr" {
  description = "CIDR autorizado a acessar a EC2 por SSH (porta 22). Use o seu IP público com /32, ex.: 200.1.2.3/32."
  type        = string
  # Sem default de propósito: obriga cada pessoa a informar o próprio IP,
  # em vez de herdar um valor inseguro.

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "Informe um CIDR IPv4 válido, por exemplo 200.1.2.3/32."
  }

  validation {
    # Liberar SSH para a internet inteira é um erro clássico de segurança.
    condition     = var.allowed_ssh_cidr != "0.0.0.0/0"
    error_message = "Não libere SSH para 0.0.0.0/0. Use o seu IP com /32."
  }
}

variable "key_name" {
  description = "Nome de um key pair EC2 já existente para SSH. No Learner Lab o padrão é \"vockey\" (chave labsuser.pem)."
  type        = string
  default     = "vockey"
}

variable "instance_profile_name" {
  description = "Instance profile anexado à EC2. O Learner Lab não permite criar IAM, então usamos o LabInstanceProfile (LabRole)."
  type        = string
  default     = "LabInstanceProfile"
}
