# Teoria — conceitos usados na etapa 1

Resumo do que eu aprendi montando esta etapa, com o lugar do código onde cada
conceito aparece.

## 1. IaC declarativo

Infraestrutura como Código é descrever a infra em arquivos de texto em vez de
clicar no console. No Terraform o estilo é **declarativo**: eu digo *o que* quero
ter no final ("uma VPC com 4 subnets e uma EC2") e não *os passos* para chegar lá.
O Terraform compara o desejado com o que existe e calcula sozinho o que criar,
alterar ou destruir — é isso que o `terraform plan` mostra.

Vantagens que percebi: o código vira documentação da infra, dá para revisar
mudanças antes de aplicar, versionar no Git e recriar tudo igual depois de um
`destroy` (o que é ótimo no Learner Lab, onde a sessão acaba).

📄 Onde aparece: [`main.tf`](../main.tf) — a EC2 e o security group são só a
descrição do estado final; não existe nenhum "passo 1, passo 2".

## 2. State

O state (`terraform.tfstate`) é a "memória" do Terraform: um JSON que liga cada
bloco do código (ex.: `aws_instance.web`) ao recurso real na AWS (ex.: `i-0abc...`).
Sem ele, o Terraform não saberia que a instância já existe e tentaria criar outra.

Cuidados: ele pode conter dados sensíveis, então não vai para o Git; e se duas
pessoas rodarem `apply` ao mesmo tempo o state pode corromper — por isso o
próximo passo é um backend remoto (S3) com **lock**.

📄 Onde aparece: [`backend.tf`](../backend.tf) (backend local agora, S3 comentado)
e [`.gitignore`](../.gitignore) (ignora `*.tfstate*`).

## 3. Providers

O Terraform sozinho não sabe falar com nenhuma nuvem. Quem faz isso são os
**providers**, plugins que traduzem os recursos do HCL em chamadas de API.
Aqui uso o `hashicorp/aws`, travado em `~> 5.0` para não pegar uma versão major
nova com breaking changes. O `terraform init` baixa o plugin e grava a versão
exata no `.terraform.lock.hcl`.

A configuração do provider define a região (vinda de variável, por causa da
restrição do Learner Lab) e as `default_tags`, que vão para todos os recursos.
As credenciais **não** ficam no código: o provider lê de `~/.aws/credentials`.

📄 Onde aparece: [`versions.tf`](../versions.tf) (qual provider e versão) e
[`providers.tf`](../providers.tf) (região e tags).

## 4. Módulos

Um módulo é uma pasta com arquivos `.tf` que funciona como uma "função": recebe
entradas (`variables.tf`), cria recursos (`main.tf`) e devolve saídas
(`outputs.tf`). A própria raiz do projeto é um módulo (o *root module*).

Coloquei a rede num módulo próprio porque ela é um bloco coeso que eu vou querer
reaproveitar (outro ambiente = chamar o módulo de novo com outros valores).
O módulo não configura o provider nem conhece o Learner Lab: só recebe
prefixo, CIDR e subnets. O root usa o que ele expõe, como `module.vpc.vpc_id`.

📄 Onde aparece: [`modules/vpc/`](../modules/vpc/) e a chamada
`module "vpc"` em [`main.tf`](../main.tf).

## 5. `for_each` vs `count`

Os dois criam várias cópias de um recurso, mas identificam cada cópia de jeito
diferente:

| | `count` | `for_each` |
|---|---|---|
| Entrada | um número | um mapa ou set |
| Endereço | `aws_subnet.public[0]` | `aws_subnet.public["public-us-east-1a"]` |
| Remover um item do meio | os seguintes "andam" de índice e são **recriados** | só aquele item é destruído |

Para subnets, recriar sem necessidade derruba tudo que está dentro delas, então
usei `for_each` com uma chave estável (o nome da AZ). `count` faz mais sentido
para "N cópias idênticas" ou para ligar/desligar um recurso (`count = var.x ? 1 : 0`).

📄 Onde aparece: [`modules/vpc/main.tf`](../modules/vpc/main.tf) (subnets e
associações) e [`locals.tf`](../locals.tf) (onde os mapas com as chaves são montados).

## Extras que apareceram no caminho

- **Variáveis com validation** — erros pegos antes de chamar a AWS (ex.: região
  fora do lab, SSH aberto para `0.0.0.0/0`). 📄 [`variables.tf`](../variables.tf)
- **Locals** — valores calculados e reutilizados, como o prefixo de nomes e os
  CIDRs gerados com `cidrsubnet()`. 📄 [`locals.tf`](../locals.tf)
- **Data sources** — *leem* dados que já existem (AZs disponíveis, AMI mais
  recente) em vez de chumbar IDs. 📄 [`main.tf`](../main.tf)
- **Outputs** — valores de retorno, como o IP público da EC2. 📄 [`outputs.tf`](../outputs.tf)
