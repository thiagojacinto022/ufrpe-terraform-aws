# Um módulo também declara de quais providers depende. Ele NÃO configura o
# provider (região, credenciais): isso é responsabilidade de quem chama o
# módulo (o root). Assim o mesmo módulo funciona em qualquer região.
terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
