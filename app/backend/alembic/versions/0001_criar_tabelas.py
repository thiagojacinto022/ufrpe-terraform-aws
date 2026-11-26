"""criar tabelas de jogadores, partidas e palpites

Revision ID: 0001
Revises:
Create Date: 2026-11-25
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "jogadores",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("apelido", sa.String(length=20), nullable=False),
        sa.Column(
            "criado_em",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id", name="pk_jogadores"),
        sa.UniqueConstraint("apelido", name="uq_jogadores_apelido"),
    )
    op.create_table(
        "partidas",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("jogador_id", sa.Integer(), nullable=False),
        sa.Column("data", sa.Date(), nullable=False),
        sa.Column("palavra", sa.String(length=5), nullable=False),
        sa.Column("status", sa.String(length=15), nullable=False),
        sa.Column("tentativas", sa.Integer(), nullable=False),
        sa.Column(
            "criada_em",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("finalizada_em", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(
            ["jogador_id"],
            ["jogadores.id"],
            name="fk_partidas_jogador_id_jogadores",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_partidas"),
        sa.UniqueConstraint("jogador_id", "data", name="uq_partidas_jogador_data"),
    )
    op.create_table(
        "palpites",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("partida_id", sa.Integer(), nullable=False),
        sa.Column("ordem", sa.Integer(), nullable=False),
        sa.Column("palavra", sa.String(length=5), nullable=False),
        sa.Column("resultado", sa.String(length=5), nullable=False),
        sa.Column(
            "criado_em",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["partida_id"],
            ["partidas.id"],
            name="fk_palpites_partida_id_partidas",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_palpites"),
        sa.UniqueConstraint("partida_id", "ordem", name="uq_palpites_partida_ordem"),
    )


def downgrade() -> None:
    op.drop_table("palpites")
    op.drop_table("partidas")
    op.drop_table("jogadores")
