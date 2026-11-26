# -----------------------------------------------------------------------------
# main.tf
#
# Ponto de entrada da infraestrutura. Aqui eu "monto as peças":
#   1. busco informações que já existem na AWS (data sources);
#   2. chamo o módulo de rede (modules/vpc);
#   3. crio o security group e a instância EC2 do servidor web.
# -----------------------------------------------------------------------------

# =============================================================================
# Data sources: LEEM dados da AWS, não criam nada.
# =============================================================================

# Lista de AZs ativas na região. Usada em locals.tf para espalhar as subnets.
data "aws_availability_zones" "available" {
  state = "available"
}

# AMI mais recente do Amazon Linux 2023. Buscar dinamicamente evita "chumbar"
# um ID de AMI (ami-xxxx), que muda por região e fica desatualizado.
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"] # só imagens publicadas pela própria AWS (segurança)

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"] # x86_64 combina com t2/t3.micro
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =============================================================================
# Rede: módulo próprio em ./modules/vpc
#
# Por que um módulo? A rede é um bloco coeso e reutilizável. Isolada num módulo,
# eu posso criar outra VPC (ex.: ambiente hml) só chamando o módulo de novo com
# outros parâmetros, sem copiar e colar dezenas de recursos.
# =============================================================================

module "vpc" {
  source = "./modules/vpc"

  name_prefix     = local.name_prefix
  vpc_cidr        = var.vpc_cidr
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets
}

# =============================================================================
# Security Group: o "firewall" da instância.
#
# Uso recursos separados para cada regra (aws_vpc_security_group_*_rule), que
# é a prática recomendada no provider AWS 5.x: cada regra vira um recurso com
# ID próprio, fica mais fácil de ler no plan e evita conflitos de regras inline.
# =============================================================================

resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "Permite HTTP apenas do ALB e SSH apenas do IP autorizado"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${local.name_prefix}-web-sg"
  }
}

# SSH (22) somente do meu IP: reduz drasticamente a superfície de ataque.
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.web.id
  description       = "SSH a partir do IP autorizado"
  cidr_ipv4         = var.allowed_ssh_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id            = aws_security_group.web.id
  description                  = "HTTP somente do ALB"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

# Saída liberada: sem NAT Gateway, a instância precisa chegar sozinha ao ECR,
# ao SSM e aos repositórios de pacotes. ip_protocol "-1" = todos os protocolos.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  description       = "Saida liberada para a internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# =============================================================================
# EC2: servidor web na primeira subnet pública.
# =============================================================================

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  # O módulo devolve um mapa { chave => id }. Pego a subnet pública da
  # primeira AZ usando a mesma chave estável gerada em locals.tf.
  subnet_id                   = module.vpc.public_subnet_ids["public-${local.azs[0]}"]
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true # necessário para ser acessível da internet

  # Recursos que já existem no Learner Lab (não posso criar IAM lá):
  key_name             = var.key_name
  iam_instance_profile = var.instance_profile_name

  # IMDSv2 obrigatório: protege as credenciais temporárias da instância contra
  # ataques do tipo SSRF. É uma recomendação de segurança da própria AWS.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    compose_version = var.compose_version
    aws_region      = var.aws_region
    ecr_registry    = split("/", aws_ecr_repository.app["backend"].repository_url)[0]
    ecr_backend     = aws_ecr_repository.app["backend"].repository_url
    ecr_frontend    = aws_ecr_repository.app["frontend"].repository_url
    db_host         = aws_db_instance.main.address
    db_port         = aws_db_instance.main.port
    db_name         = var.db_name
    db_user         = var.db_username
  })

  # Se eu mudar o user_data, a instância é recriada (o script só roda no
  # primeiro boot, então mudar sem recriar não teria efeito nenhum).
  user_data_replace_on_change = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "${local.name_prefix}-web"
  }
}
