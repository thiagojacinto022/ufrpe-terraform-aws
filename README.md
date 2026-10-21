# Terraform na AWS — Infraestrutura de uma aplicação web com rede pública/privada

Projeto de estudo de Infraestrutura como Código (IaC) com Terraform, rodando no
**AWS Academy Learner Lab**.

Nesta **etapa 1** o código cria:

- uma **VPC** com 2 subnets públicas e 2 privadas, em 2 AZs diferentes;
- **Internet Gateway**, route tables e associações (públicas saem para a internet; privadas não);
- um **security group** que libera HTTP (80) para todos e SSH (22) só para o meu IP;
- uma **EC2** (Amazon Linux 2023, `t3.micro`) na subnet pública, com nginx instalado no boot.

```
                       Internet
                          |
                   [Internet Gateway]
                          |
   +----------------------VPC 10.0.0.0/16-------------------+
   |  AZ a                           AZ b                    |
   |  [public  10.0.0.0/24]  <- EC2  [public  10.0.1.0/24]   |  rota 0.0.0.0/0 -> IGW
   |  [private 10.0.10.0/24]         [private 10.0.11.0/24]  |  só rota local
   +---------------------------------------------------------+
```

> ⚠️ **Antes de encerrar a sessão do Learner Lab, rode `terraform destroy`.**
> As credenciais expiram com a sessão; se você esquecer, os recursos continuam
> existindo (consumindo seu crédito) e você terá que renovar as credenciais
> para conseguir destruí-los depois.

## Pré-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/install) **>= 1.5**
  (`terraform version` para conferir). No Fedora:
  ```bash
  sudo dnf install -y dnf-plugins-core
  sudo dnf config-manager addrepo --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
  sudo dnf install -y terraform
  ```
- Acesso ao **AWS Academy Learner Lab** (sessão iniciada, bolinha verde em "AWS").
- Opcional: [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) para conferir as credenciais.

### Restrições do Learner Lab que moldaram o código

| Restrição | Como o código lida |
|---|---|
| Só `us-east-1` e `us-west-2` | `aws_region` tem `validation` com essas duas opções |
| Não é possível criar IAM (roles/policies) | A EC2 usa o instance profile existente `LabInstanceProfile` |
| Key pair pré-criado | SSH usa o key pair `vockey` (arquivo `labsuser.pem`) |
| Credenciais temporárias | Nada de credenciais no código; o provider lê de `~/.aws/credentials` |

## Configurando as credenciais do Learner Lab

1. No Learner Lab, clique em **Start Lab** e espere o indicador "AWS" ficar verde.
2. Clique em **AWS Details** → **AWS CLI: Show**.
3. Copie o bloco exibido (`[default]`, `aws_access_key_id`, `aws_secret_access_key`, `aws_session_token`)
   e cole em `~/.aws/credentials`, **substituindo** o conteúdo anterior.
4. Confira (opcional): `aws sts get-caller-identity`.

As credenciais **mudam a cada nova sessão**: repita os passos sempre que iniciar o lab.
Elas nunca devem ser coladas em arquivos deste projeto (`.tf`, `.tfvars`, README...).

### Chave SSH

Em **AWS Details**, clique em **Download PEM** para baixar `labsuser.pem`, depois:

```bash
chmod 400 labsuser.pem
```

## Como rodar

```bash
# 1. Crie seu arquivo de variáveis a partir do exemplo e ajuste os valores,
#    principalmente allowed_ssh_cidr (seu IP: curl https://checkip.amazonaws.com).
cp terraform.tfvars.example terraform.tfvars

# 2. Baixa o provider AWS e prepara o diretório (.terraform/).
terraform init

# 3. (Opcional) Formata e valida a sintaxe.
terraform fmt -recursive
terraform validate

# 4. Mostra o que SERÁ criado, sem mudar nada na AWS.
terraform plan

# 5. Cria a infraestrutura (pede confirmação "yes").
terraform apply

# 6. Consulta os outputs (IP público, URL, comando SSH...).
terraform output

# 7. Acessa a instância.
ssh -i labsuser.pem ec2-user@$(terraform output -raw web_public_ip)

# 8. Destrói TUDO antes de encerrar a sessão do lab.
terraform destroy
```

Depois do `apply`, aguarde ~1 minuto para o nginx instalar e abra o valor de
`web_url` no navegador.

## Estrutura de pastas

```
.
├── versions.tf               # Versão do Terraform e do provider AWS
├── providers.tf              # Provider AWS: região (variável) e default_tags
├── backend.tf                # Backend local agora; comentário do S3 com lock (etapa 2)
├── variables.tf              # Entradas do projeto, com type/description/validation
├── locals.tf                 # Valores calculados: prefixo de nomes, tags, AZs, subnets
├── main.tf                   # Data sources, chamada do módulo vpc, security group e EC2
├── outputs.tf                # IDs da VPC/subnets, IP público, URL e comando SSH
├── terraform.tfvars.example  # Modelo de variáveis (sem dados sensíveis)
├── .gitignore                # Ignora state, .terraform/, *.tfvars, credenciais
├── docs/
│   └── teoria.md             # Resumo dos conceitos usados, ligados ao código
└── modules/
    └── vpc/                  # Módulo próprio de rede
        ├── versions.tf
        ├── variables.tf
        ├── main.tf           # VPC, IGW, subnets (for_each), route tables
        └── outputs.tf
```

## Variáveis

| Nome | Padrão | Descrição |
|---|---|---|
| `project_name` | — (obrigatória) | Prefixo dos nomes e tag `Project` |
| `environment` | `dev` | `dev`, `hml` ou `prod` |
| `aws_region` | `us-east-1` | `us-east-1` ou `us-west-2` |
| `vpc_cidr` | `10.0.0.0/16` | CIDR da VPC (/16) |
| `instance_type` | `t3.micro` | `t2.micro` ou `t3.micro` |
| `allowed_ssh_cidr` | — (obrigatória) | Seu IP com `/32`; `0.0.0.0/0` é recusado |
| `key_name` | `vockey` | Key pair existente para SSH |
| `instance_profile_name` | `LabInstanceProfile` | Instance profile existente |

## Próximas etapas

- Backend remoto em S3 com lock (`backend.tf`).
- NAT Gateway para as subnets privadas e uma camada de aplicação/banco nelas.

Conceitos teóricos: veja [docs/teoria.md](docs/teoria.md).
