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
  description = "Tipo da instância EC2. A aplicação mais o stack de observabilidade pedem pelo menos 4 GB (t3.medium); micro só serve para testes de rede."
  type        = string
  default     = "t3.medium"

  validation {
    condition     = contains(["t2.micro", "t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "Use t2.micro, t3.micro, t3.small ou t3.medium."
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

variable "compose_version" {
  description = "Versão do Docker Compose instalada na EC2 (o plugin não vem nos repositórios do Amazon Linux)."
  type        = string
  default     = "v2.29.7"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.compose_version))
    error_message = "Use o formato vX.Y.Z, por exemplo v2.29.7."
  }
}

variable "ecr_images_to_keep" {
  description = "Quantidade de imagens mantidas em cada repositório ECR; as mais antigas expiram."
  type        = number
  default     = 10

  validation {
    condition     = var.ecr_images_to_keep >= 2
    error_message = "Mantenha pelo menos 2 imagens para permitir rollback."
  }
}

variable "db_engine_version" {
  description = "Versão do PostgreSQL no RDS. Informar só a major (ex.: 16) deixa a AWS escolher a minor mais recente."
  type        = string
  default     = "16"
}

variable "db_instance_class" {
  description = "Classe da instância RDS. Limitada a tipos pequenos permitidos no Learner Lab."
  type        = string
  default     = "db.t3.micro"

  validation {
    condition     = contains(["db.t3.micro", "db.t3.small"], var.db_instance_class)
    error_message = "Use db.t3.micro ou db.t3.small."
  }
}

variable "db_allocated_storage" {
  description = "Armazenamento do RDS em GB."
  type        = number
  default     = 20

  validation {
    condition     = var.db_allocated_storage >= 20 && var.db_allocated_storage <= 50
    error_message = "Use entre 20 e 50 GB."
  }
}

variable "db_name" {
  description = "Nome do banco de dados criado no RDS."
  type        = string
  default     = "termo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,62}$", var.db_name))
    error_message = "Use letras minúsculas, números ou _, começando por letra."
  }
}

variable "db_username" {
  description = "Usuário administrador do banco."
  type        = string
  default     = "termo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,31}$", var.db_username)) && var.db_username != "admin"
    error_message = "Use letras minúsculas, números ou _, começando por letra. \"admin\" é reservado."
  }
}

variable "db_password" {
  description = "Senha do banco. Sem default e sensível: informe via TF_VAR_db_password (ex.: infisical run -- terraform apply). Atenção: este valor é gravado no tfstate."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9!#$%^&*()_+=.,:;?~-]{16,128}$", var.db_password))
    error_message = "Use de 16 a 128 caracteres sem espaço e sem / @ \" ' \\ (restrições do RDS)."
  }
}
