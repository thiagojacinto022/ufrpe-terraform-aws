# -----------------------------------------------------------------------------
# providers.tf
#
# O provider é o "tradutor" entre o HCL que eu escrevo e a API da AWS.
# Aqui configuro EM QUAL região trabalhar e quais tags todo recurso recebe.
#
# Credenciais: propositalmente NÃO aparecem aqui. O provider procura sozinho
# pela cadeia padrão da AWS (variáveis de ambiente AWS_* ou ~/.aws/credentials,
# perfil "default"). Assim nenhum segredo vai parar no código ou no Git.
# -----------------------------------------------------------------------------

provider "aws" {
  # A região vem de variável: o Learner Lab só permite us-east-1 e us-west-2,
  # e a validação em variables.tf impede escolher outra por engano.
  region = var.aws_region

  # default_tags aplica estas tags em TODOS os recursos que suportam tags,
  # sem eu precisar repetir em cada bloco. Isso facilita filtrar custos e
  # descobrir "quem criou isso?" no console.
  default_tags {
    tags = local.common_tags
  }
}
