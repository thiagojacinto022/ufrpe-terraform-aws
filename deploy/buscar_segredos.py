import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

CHAVES_OBRIGATORIAS = ("DB_PASSWORD", "TOKEN_SECRET", "GRAFANA_ADMIN_PASSWORD")
VALOR_SEGURO = re.compile(r"^[\x21-\x26\x28-\x5b\x5d-\x7e]{12,200}$")
TENTATIVAS = 3
LIMITE_SEGUNDOS = 15


def obrigatoria(nome: str) -> str:
    valor = os.environ.get(nome, "")
    if not valor:
        sys.exit(f"Variavel de ambiente ausente: {nome}")
    return valor


def montar_url() -> str:
    base = os.environ.get("INFISICAL_URL", "https://app.infisical.com").rstrip("/")
    parametros = urllib.parse.urlencode(
        {
            "workspaceId": obrigatoria("INFISICAL_PROJECT_ID"),
            "environment": os.environ.get("INFISICAL_ENV", "prod"),
            "secretPath": os.environ.get("INFISICAL_SECRET_PATH", "/"),
            "expandSecretReferences": "true",
        }
    )
    return f"{base}/api/v3/secrets/raw?{parametros}"


def consultar(url: str, token: str) -> dict:
    requisicao = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    ultimo_erro = ""
    for tentativa in range(1, TENTATIVAS + 1):
        try:
            with urllib.request.urlopen(requisicao, timeout=LIMITE_SEGUNDOS) as resposta:
                return json.load(resposta)
        except urllib.error.HTTPError as erro:
            if erro.code in (401, 403, 404):
                sys.exit(f"Infisical recusou a consulta (HTTP {erro.code}). Verifique projeto, ambiente e permissoes.")
            ultimo_erro = f"HTTP {erro.code}"
        except (urllib.error.URLError, TimeoutError) as erro:
            ultimo_erro = type(erro).__name__
        time.sleep(2 * tentativa)
    sys.exit(f"Infisical indisponivel apos {TENTATIVAS} tentativas ({ultimo_erro})")


def extrair(resposta: dict) -> dict[str, str]:
    encontrados = {item["secretKey"]: item["secretValue"] for item in resposta.get("secrets", [])}
    ambiente = os.environ.get("INFISICAL_ENV", "prod")
    caminho = os.environ.get("INFISICAL_SECRET_PATH", "/")

    if not encontrados:
        sys.exit(
            f"Nenhum segredo encontrado no ambiente '{ambiente}' (caminho '{caminho}') deste projeto. "
            "Confira se os segredos foram salvos neste ambiente (Development, Staging ou Production) "
            "e se o Project ID e o slug do ambiente estao certos."
        )

    ausentes = [chave for chave in CHAVES_OBRIGATORIAS if not encontrados.get(chave)]
    if ausentes:
        sys.exit(
            f"Segredos ausentes no ambiente '{ambiente}': {', '.join(ausentes)}. "
            f"Nomes encontrados: {', '.join(sorted(encontrados))}"
        )

    invalidos = [chave for chave in CHAVES_OBRIGATORIAS if not VALOR_SEGURO.match(encontrados[chave])]
    if invalidos:
        sys.exit(
            "Segredos fora do formato aceito (12 a 200 caracteres ASCII visiveis, sem aspas simples "
            f"nem barra invertida): {', '.join(invalidos)}"
        )
    return {chave: encontrados[chave] for chave in CHAVES_OBRIGATORIAS}


def gravar(destino: str, segredos: dict[str, str]) -> None:
    descritor = os.open(destino, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descritor, "w") as arquivo:
        for chave, valor in segredos.items():
            arquivo.write(f"{chave}='{valor}'\n")


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit("uso: buscar_segredos.py <arquivo-de-destino>")

    token = obrigatoria("INFISICAL_ACCESS_TOKEN")
    segredos = extrair(consultar(montar_url(), token))
    gravar(sys.argv[1], segredos)
    print(f"Segredos obtidos do Infisical: {', '.join(segredos)} (valores nao exibidos)")


if __name__ == "__main__":
    main()
