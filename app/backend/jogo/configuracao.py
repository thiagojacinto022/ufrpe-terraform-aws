import os
from dataclasses import dataclass
from functools import lru_cache

TAMANHO_MINIMO_SEGREDO = 16


@dataclass(frozen=True)
class Configuracao:
    db_host: str
    db_port: int
    db_nome: str
    db_usuario: str
    db_senha: str
    db_sslmode: str
    token_segredo: str
    token_validade_horas: int
    fuso_horario: str


def _obrigatoria(nome: str) -> str:
    valor = os.environ.get(nome, "")
    if not valor:
        raise RuntimeError(f"Variável de ambiente obrigatória ausente: {nome}")
    return valor


def _segredo_do_token() -> str:
    segredo = _obrigatoria("TOKEN_SECRET")
    if len(segredo) < TAMANHO_MINIMO_SEGREDO:
        raise RuntimeError(
            f"TOKEN_SECRET precisa ter pelo menos {TAMANHO_MINIMO_SEGREDO} caracteres"
        )
    return segredo


@lru_cache
def obter_configuracao() -> Configuracao:
    return Configuracao(
        db_host=os.environ.get("DB_HOST", "localhost"),
        db_port=int(os.environ.get("DB_PORT", "5432")),
        db_nome=os.environ.get("DB_NAME", "termo"),
        db_usuario=os.environ.get("DB_USER", "termo"),
        db_senha=_obrigatoria("DB_PASSWORD"),
        db_sslmode=os.environ.get("DB_SSLMODE", "prefer"),
        token_segredo=_segredo_do_token(),
        token_validade_horas=int(os.environ.get("TOKEN_VALIDADE_HORAS", "168")),
        fuso_horario=os.environ.get("FUSO_HORARIO", "America/Recife"),
    )
