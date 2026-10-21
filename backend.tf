# -----------------------------------------------------------------------------
# backend.tf
#
# O "backend" define ONDE o Terraform guarda o state (terraform.tfstate), que é
# o arquivo onde ele anota o que já criou na AWS.
#
# ETAPA 1 (agora): backend LOCAL.
#   Não declaro nenhum bloco `backend`, então o Terraform usa o padrão: o state
#   fica em ./terraform.tfstate. Simples para estudar, mas tem problemas:
#     - só existe na minha máquina (se eu perder, perco o controle da infra);
#     - não dá para trabalhar em equipe com segurança;
#     - pode conter dados sensíveis, por isso está no .gitignore.
#
# ETAPA 2 (próxima): backend S3 com lock.
#   O bloco abaixo entrará aqui, descomentado, depois que eu criar o bucket.
#   `use_lockfile = true` (Terraform >= 1.10) cria um arquivo .tflock no próprio
#   S3 para impedir que duas pessoas rodem `apply` ao mesmo tempo, dispensando
#   a antiga tabela DynamoDB.
#
# terraform {
#   backend "s3" {
#     bucket       = "<nome-do-bucket-de-state>"
#     key          = "etapa-1/terraform.tfstate"
#     region       = "us-east-1"
#     encrypt      = true
#     use_lockfile = true
#   }
# }
#
# Obs.: blocos `backend` não aceitam variáveis; os valores precisam ser
# literais ou passados via `terraform init -backend-config=...`.
# -----------------------------------------------------------------------------
