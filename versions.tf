# -----------------------------------------------------------------------------
# versions.tf
#
# Por que este arquivo existe?
# Fixar as versões do Terraform e dos providers garante que o código se comporte
# igual na minha máquina, na de um colega ou numa pipeline de CI. Sem isso, um
# `terraform init` feito daqui a seis meses poderia baixar um provider com
# mudanças incompatíveis e quebrar o projeto "do nada".
# -----------------------------------------------------------------------------

terraform {
  # Versão mínima do binário do Terraform. A 1.5 trouxe recursos que uso
  # aqui (ex.: blocos `check`/`import` e melhorias em validation).
  required_version = ">= 1.5"

  required_providers {
    aws = {
      # "source" diz de qual registry/namespace baixar o plugin.
      source = "hashicorp/aws"

      # "~> 5.0" = qualquer 5.x (aceita 5.1, 5.99...), mas NUNCA 6.0.
      # Versões major costumam trazer breaking changes, então só subo de major
      # quando eu decidir, e não por acidente.
      version = "~> 5.0"
    }
  }
}
