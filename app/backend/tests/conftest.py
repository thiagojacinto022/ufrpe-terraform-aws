import os
from collections.abc import Iterator
from datetime import date
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import Engine, text

os.environ.setdefault("DB_HOST", "localhost")
os.environ.setdefault("DB_PORT", "5433")
os.environ.setdefault("DB_NAME", "termo_teste")
os.environ.setdefault("DB_USER", "termo")
os.environ.setdefault("DB_PASSWORD", "termo")
os.environ.setdefault("TOKEN_SECRET", "segredo-exclusivo-dos-testes-automatizados")

RAIZ_BACKEND = Path(__file__).resolve().parents[1]
DATA_INICIAL = date(2026, 1, 10)


class Relogio:
    def __init__(self) -> None:
        self.hoje = DATA_INICIAL


@pytest.fixture(scope="session")
def banco() -> Engine:
    from jogo.banco import obter_engine
    from jogo.configuracao import obter_configuracao

    if not obter_configuracao().db_nome.endswith("_teste"):
        pytest.exit("DB_NAME precisa terminar com _teste para rodar os testes de API")

    configuracao_alembic = Config(str(RAIZ_BACKEND / "alembic.ini"))
    command.downgrade(configuracao_alembic, "base")
    command.upgrade(configuracao_alembic, "head")
    return obter_engine()


@pytest.fixture
def relogio() -> Relogio:
    return Relogio()


@pytest.fixture
def cliente(banco: Engine, relogio: Relogio) -> Iterator[TestClient]:
    from jogo.main import app
    from jogo.rotas import obter_data_hoje

    with banco.begin() as conexao:
        conexao.execute(text("TRUNCATE palpites, partidas, jogadores RESTART IDENTITY CASCADE"))

    app.dependency_overrides[obter_data_hoje] = lambda: relogio.hoje
    with TestClient(app) as cliente_teste:
        yield cliente_teste
    app.dependency_overrides.clear()
