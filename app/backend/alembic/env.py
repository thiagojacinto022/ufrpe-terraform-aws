from alembic import context
from sqlalchemy import create_engine

from jogo.banco import montar_url
from jogo.configuracao import obter_configuracao
from jogo.logs import configurar_logs
from jogo.modelos import Base

configurar_logs()

metadados_alvo = Base.metadata


def executar_offline() -> None:
    url = montar_url(obter_configuracao()).render_as_string(hide_password=False)
    context.configure(url=url, target_metadata=metadados_alvo, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()


def executar_online() -> None:
    engine = create_engine(montar_url(obter_configuracao()))
    with engine.connect() as conexao:
        context.configure(connection=conexao, target_metadata=metadados_alvo)
        with context.begin_transaction():
            context.run_migrations()
    engine.dispose()


if context.is_offline_mode():
    executar_offline()
else:
    executar_online()
