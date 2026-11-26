# Checklist: requisitos do projeto × onde foram atendidos

Legenda: ✅ atendido e verificado · 🟡 atendido, com ressalva descrita

## 1. Terraform

| Requisito | Situação | Onde |
|---|---|---|
| ECR | ✅ | [ecr.tf](../ecr.tf): repositórios `backend` e `frontend`, scan no push e retenção |
| EC2 | ✅ | [main.tf](../main.tf) + [templates/user_data.sh.tftpl](../templates/user_data.sh.tftpl) |
| ALB | ✅ | [alb.tf](../alb.tf): ALB, target group com health check `/health`, listener 80, 2 AZs |
| Security groups | ✅ | [security_groups.tf](../security_groups.tf) (ALB e banco) e SG da EC2 em [main.tf](../main.tf), encadeados por referência |
| Banco de dados | ✅ | [rds.tf](../rds.tf): PostgreSQL 16, subnets privadas, criptografado |
| S3 (state remoto, criptografia e versionamento) | 🟡 | [bootstrap/main.tf](../bootstrap/main.tf) + [backend.tf](../backend.tf). O bucket em si é criado por [scripts/criar-bucket-state.sh](../scripts/criar-bucket-state.sh) porque a SCP do Learner Lab bloqueia a leitura de object lock feita pelo recurso `aws_s3_bucket` (README, seção 14) |
| Versionado no Git, organizado em módulos ou arquivos claros | ✅ | Módulo [modules/vpc](../modules/vpc) reaproveitado sem alterações; um arquivo `.tf` por assunto |
| Variáveis e outputs | ✅ | [variables.tf](../variables.tf) (com `validation`), [outputs.tf](../outputs.tf) |
| Comando de destruição documentado | ✅ | [scripts/destruir.sh](../scripts/destruir.sh) e README, seção 13 |
| Reaproveita a rede existente | ✅ | Todos os recursos novos usam `module.vpc.*`; o módulo `vpc` não foi alterado |
| Sem NAT Gateway | ✅ | A EC2 usa IP público em subnet pública; o RDS não precisa de saída |

## 2. CI/CD com GitHub Actions

| Requisito | Situação | Onde |
|---|---|---|
| Jobs encadeados com `needs` | ✅ | [.github/workflows/ci-cd.yml](../.github/workflows/ci-cd.yml): `testar`/`validar-infra` → `construir` → `implantar` → `verificar` |
| Lint + testes; falha interrompe tudo | ✅ | Jobs `testar` e `validar-infra`; `construir` depende de ambos (README, seção 9) |
| Build das imagens e push no ECR | ✅ | Job `construir` (`docker/build-push-action`, tags `SHA` e `latest`) |
| Deploy automatizado na EC2 (SSH ou SSM, justificado) | ✅ | SSM: [scripts/enviar-deploy.sh](../scripts/enviar-deploy.sh) e [deploy/implantar.sh](../deploy/implantar.sh). Justificativa: não abre a porta 22 para IPs do GitHub |
| Verificação pós-deploy (`/health` e endpoint de jogo pelo DNS do ALB, com retry e timeout) | ✅ | Job `verificar` + [scripts/verificar-deploy.sh](../scripts/verificar-deploy.sh) (24 tentativas, timeout de 10 s; falha derruba o pipeline) |

## 3. Segredos

| Requisito | Situação | Onde |
|---|---|---|
| Nada no código nem em arquivos versionados | ✅ | `.gitignore`, `.env.example` sem valores reais, gitleaks no job `validar-infra` (zero achados no histórico) |
| Infisical com machine identity (Universal Auth); client id/secret nos GitHub Secrets | 🟡 | Implementado em [scripts/obter-token-infisical.sh](../scripts/obter-token-infisical.sh), [deploy/buscar_segredos.py](../deploy/buscar_segredos.py) e no job `implantar`. Testado contra servidores Infisical **simulados** (sucesso, token inválido, segredo ausente, valor perigoso); a conta do Infisical precisa ser criada e ligada (README, seção 10) |
| Senha do banco e chave de assinatura do token vindas do Infisical | 🟡 | `DB_PASSWORD` e `TOKEN_SECRET` (e `GRAFANA_ADMIN_PASSWORD`); Terraform via [scripts/terraform-com-infisical.sh](../scripts/terraform-com-infisical.sh). Até o Infisical ser configurado, o deploy reaproveita o `segredos.env` já presente na EC2 e emite um aviso |
| Segredos fora dos logs (mascaramento) | ✅ | `::add-mask::` nos tokens; valores por stdin/variáveis de ambiente; o buscador só imprime nomes de chaves |
| Aviso sobre segredos no tfstate | ✅ | README, seção 10 (a senha do RDS fica em texto claro no state; bucket privado, criptografado e versionado) |

## 4. Testes automatizados

| Requisito | Situação | Onde |
|---|---|---|
| Unitários da avaliação (incluindo letras repetidas) | ✅ | [app/backend/tests/test_avaliacao.py](../app/backend/tests/test_avaliacao.py): 10 casos de repetição + normalização e validação |
| Testes de API com PostgreSQL como service | ✅ | [app/backend/tests/test_api.py](../app/backend/tests/test_api.py) (16 testes, inclui a checagem migrações × modelos); `services.postgres` no job `testar` |
| README explica como os testes bloqueiam o deploy | ✅ | README, seção 9 |
| Resultado | ✅ | 49 testes passando localmente e no GitHub Actions |

## 5. Observabilidade

| Requisito | Situação | Onde |
|---|---|---|
| `partidas_iniciadas_total`, `partidas_vencidas_total`, `palpites_total` | ✅ | [app/backend/jogo/metricas.py](../app/backend/jogo/metricas.py) (mais `partidas_perdidas_total`) |
| Histograma de latência por rota | ✅ | `http_requisicao_duracao_segundos{metodo,rota}`, rótulo com o padrão da rota |
| Logs estruturados em JSON enviados ao Loki | ✅ | [app/backend/jogo/logs.py](../app/backend/jogo/logs.py), [nginx.conf](../app/frontend/nginx.conf), Promtail em [deploy/observabilidade/promtail](../deploy/observabilidade/promtail) |
| Dashboard do Grafana provisionado por arquivo (taxa de vitória, req/s, latência p95, erros) | ✅ | [termo-visao-geral.json](../deploy/observabilidade/grafana/dashboards/termo-visao-geral.json) + [provisioning](../deploy/observabilidade/grafana/provisioning) |
| Prometheus + Grafana + Loki (+ Promtail) em Compose | ✅ | [deploy/docker-compose.observabilidade.yml](../deploy/docker-compose.observabilidade.yml), na mesma EC2 |

## 6. Documentação

| Requisito | Situação | Onde |
|---|---|---|
| Problema e funcionalidades | ✅ | README, seções 1 e 2 |
| Diagrama de arquitetura (Mermaid) | ✅ | README, seção 3 (arquitetura e fluxo do pipeline) |
| Justificativa de cada tecnologia | ✅ | README, seção 4 |
| Divisão de tarefas do grupo | 🟡 | Seção 5, **a preencher pelo grupo** |
| Como executar localmente | ✅ | README, seção 7 |
| Como implantar e remover os recursos | ✅ | README, seções 8 e 13 |
| Medidas de segurança | ✅ | README, seção 11 |
| Como acessar a observabilidade | ✅ | README, seção 12 |

## 7. Restrições do Learner Lab

| Requisito | Situação | Onde |
|---|---|---|
| Script `atualizar-secrets-aws.sh` que lê `~/.aws/credentials` e usa `gh secret set` | ✅ | [scripts/atualizar-secrets-aws.sh](../scripts/atualizar-secrets-aws.sh); documentado no README, seção 8.1 |
| Sem roles ou usuários IAM; usar LabRole e LabInstanceProfile | ✅ | `instance_profile_name = "LabInstanceProfile"`; nenhum recurso IAM no Terraform |
| Aviso e alternativa para permissões não concedidas | ✅ | SCP do S3 (object lock): alternativa em README, seção 14 |
| Custos baixos | ✅ | `t3.medium`, `db.t3.micro`, sem NAT, sem recursos ociosos; custo estimado no README, seção 15 |

## 8. Convenções de código

| Convenção | Situação |
|---|---|
| Nomes de domínio em português | ✅ `Partida`, `Palpite`, `Jogador`, `avaliar_palpite`, `iniciar_partida`... |
| Guard clauses e retorno antecipado | ✅ Funções de serviço e rotas |
| Nenhum comentário inline | ✅ nos arquivos novos. Os arquivos da etapa 1 mantêm os comentários didáticos originais |
| Arquivos completos | ✅ |

## Pendências conhecidas

1. **Preencher a divisão de tarefas** (README, seção 5).
2. **Configurar o Infisical** (README, seção 10): criar projeto, os 3 segredos e a machine identity; gravar
   `INFISICAL_CLIENT_ID`, `INFISICAL_CLIENT_SECRET` e as variáveis `INFISICAL_PROJECT_ID` e `INFISICAL_ENV` no GitHub.
3. As credenciais do Learner Lab expiram: rode `./scripts/atualizar-secrets-aws.sh` a cada novo Start Lab,
   antes de dar push na `main`.
4. ✅ **Dashboard renderizado conferido no navegador** (26/11/2026, ambiente local com
   `docker-compose.observabilidade.yml`): todos os painéis do **Termo - Visão geral** exibem dados e acompanham as
   partidas. Na AWS, o acesso é pelo túnel `$(terraform output -raw grafana_tunnel_command)` e
   <http://localhost:3000> (README, seção 12).
