# -----------------------------------------------------------------------------
# Módulo vpc: monta a rede da aplicação.
#
#                       Internet
#                          |
#                   [Internet Gateway]
#                          |
#   +----------------------VPC-----------------------+
#   |  AZ a                          AZ b             |
#   |  [public  10.0.0.0/24]         [public  10.0.1.0/24]   -> rota 0.0.0.0/0 -> IGW
#   |  [private 10.0.10.0/24]        [private 10.0.11.0/24]  -> só rota local
#   +-------------------------------------------------+
# -----------------------------------------------------------------------------

# A VPC é a rede isolada onde todo o resto vive.
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  # Habilitam resolução de DNS e nomes DNS públicos para as instâncias
  # (ex.: ec2-1-2-3-4.compute-1.amazonaws.com), usados no output web_url.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# O Internet Gateway é a "porta" entre a VPC e a internet.
# Sozinho ele não faz nada: precisa de uma rota apontando para ele.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# =============================================================================
# Subnets
#
# Por que for_each e não count?
#   Com count, cada subnet é identificada pela POSIÇÃO na lista:
#   aws_subnet.public[0], aws_subnet.public[1]... Se eu remover o primeiro item,
#   todos os outros "andam" uma posição e o Terraform entende que precisa
#   destruir e recriar subnets que não mudaram (derrubando o que estiver nelas).
#
#   Com for_each, cada subnet é identificada por uma CHAVE estável:
#   aws_subnet.public["public-us-east-1a"]. Adicionar ou remover uma subnet
#   afeta só ela. Regra prática: count para "N cópias iguais"; for_each para
#   coisas que têm identidade própria (como subnets em AZs diferentes).
# =============================================================================

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.az

  # Instâncias lançadas aqui recebem IP público automaticamente.
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-${each.key}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.az

  # Subnets privadas nunca entregam IP público: ficam inacessíveis da internet.
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-${each.key}"
    Tier = "private"
  }
}

# =============================================================================
# Roteamento
#
# O que torna uma subnet "pública" não é o nome, e sim a ROTA: se a route table
# associada a ela tem 0.0.0.0/0 apontando para o Internet Gateway, ela é pública.
# =============================================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  # Todo tráfego que não é da VPC (rota "local" implícita) vai para a internet.
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

# Route table privada: só tem a rota "local" (criada automaticamente pela AWS),
# então as subnets privadas conversam com a VPC, mas não com a internet.
#
# PRÓXIMA ETAPA: para instâncias privadas baixarem pacotes, adicionar aqui uma
# rota 0.0.0.0/0 para um NAT Gateway. Ficou de fora por custo (NAT é cobrado
# por hora) e por não ser necessário ainda.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-private-rt"
  }
}

# Associações: ligam cada subnet à sua route table. Também uso for_each, iterando
# sobre as próprias subnets criadas, para manter as mesmas chaves estáveis.
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
