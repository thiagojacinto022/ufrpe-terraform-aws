from collections.abc import Iterator
from functools import lru_cache

from sqlalchemy import URL, Engine, create_engine
from sqlalchemy.orm import Session, sessionmaker

from jogo.configuracao import Configuracao, obter_configuracao


def montar_url(configuracao: Configuracao) -> URL:
    return URL.create(
        "postgresql+psycopg",
        username=configuracao.db_usuario,
        password=configuracao.db_senha,
        host=configuracao.db_host,
        port=configuracao.db_port,
        database=configuracao.db_nome,
        query={"sslmode": configuracao.db_sslmode},
    )


@lru_cache
def obter_engine() -> Engine:
    return create_engine(montar_url(obter_configuracao()), pool_pre_ping=True)


@lru_cache
def obter_fabrica_sessoes() -> sessionmaker[Session]:
    return sessionmaker(bind=obter_engine(), expire_on_commit=False)


def obter_sessao() -> Iterator[Session]:
    sessao = obter_fabrica_sessoes()()
    try:
        yield sessao
    finally:
        sessao.close()
