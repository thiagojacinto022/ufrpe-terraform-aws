from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, MetaData, String, UniqueConstraint, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship

STATUS_EM_ANDAMENTO = "em_andamento"
STATUS_VENCIDA = "vencida"
STATUS_PERDIDA = "perdida"

CONVENCAO_NOMES = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}


class Base(DeclarativeBase):
    metadata = MetaData(naming_convention=CONVENCAO_NOMES)


class Jogador(Base):
    __tablename__ = "jogadores"

    id: Mapped[int] = mapped_column(primary_key=True)
    apelido: Mapped[str] = mapped_column(String(20), unique=True)
    criado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    partidas: Mapped[list["Partida"]] = relationship(back_populates="jogador")


class Partida(Base):
    __tablename__ = "partidas"
    __table_args__ = (UniqueConstraint("jogador_id", "data", name="uq_partidas_jogador_data"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    jogador_id: Mapped[int] = mapped_column(ForeignKey("jogadores.id", ondelete="CASCADE"))
    data: Mapped[date] = mapped_column(Date)
    palavra: Mapped[str] = mapped_column(String(5))
    status: Mapped[str] = mapped_column(String(15), default=STATUS_EM_ANDAMENTO)
    tentativas: Mapped[int] = mapped_column(default=0)
    criada_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    finalizada_em: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    jogador: Mapped[Jogador] = relationship(back_populates="partidas")
    palpites: Mapped[list["Palpite"]] = relationship(
        back_populates="partida", order_by="Palpite.ordem", cascade="all, delete-orphan"
    )


class Palpite(Base):
    __tablename__ = "palpites"
    __table_args__ = (UniqueConstraint("partida_id", "ordem", name="uq_palpites_partida_ordem"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    partida_id: Mapped[int] = mapped_column(ForeignKey("partidas.id", ondelete="CASCADE"))
    ordem: Mapped[int]
    palavra: Mapped[str] = mapped_column(String(5))
    resultado: Mapped[str] = mapped_column(String(5))
    criado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    partida: Mapped[Partida] = relationship(back_populates="palpites")
