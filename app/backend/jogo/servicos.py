import logging
from dataclasses import dataclass
from datetime import UTC, date, datetime

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from jogo import metricas
from jogo.avaliacao import (
    TAMANHO_PALAVRA,
    avaliar_palpite,
    codificar_resultado,
    normalizar_palavra,
    palavra_valida,
)
from jogo.estatisticas import Estatisticas, calcular_estatisticas
from jogo.modelos import (
    STATUS_EM_ANDAMENTO,
    STATUS_PERDIDA,
    STATUS_VENCIDA,
    Jogador,
    Palpite,
    Partida,
)
from jogo.palavras import palavra_do_dia

MAXIMO_TENTATIVAS = 6
LIMITE_RANKING = 10

logger = logging.getLogger("jogo.servicos")


class ErroDominio(Exception):
    codigo_http = 400

    def __init__(self, mensagem: str) -> None:
        super().__init__(mensagem)
        self.mensagem = mensagem


class RecursoNaoEncontrado(ErroDominio):
    codigo_http = 404


class PartidaFinalizada(ErroDominio):
    codigo_http = 409


class PalpiteInvalido(ErroDominio):
    codigo_http = 422


@dataclass(frozen=True)
class LinhaRanking:
    apelido: str
    vitorias: int
    partidas: int
    media_tentativas: float | None


def _buscar_jogador(sessao: Session, apelido: str) -> Jogador | None:
    return sessao.scalar(select(Jogador).where(Jogador.apelido == apelido))


def _buscar_partida_do_dia(sessao: Session, jogador: Jogador, data: date) -> Partida | None:
    return sessao.scalar(
        select(Partida).where(Partida.jogador_id == jogador.id, Partida.data == data)
    )


def entrar_jogador(sessao: Session, apelido: str) -> tuple[Jogador, bool]:
    apelido = apelido.lower()
    existente = _buscar_jogador(sessao, apelido)
    if existente is not None:
        return existente, False

    jogador = Jogador(apelido=apelido)
    sessao.add(jogador)
    try:
        sessao.commit()
    except IntegrityError:
        sessao.rollback()
        return _buscar_jogador(sessao, apelido), False

    logger.info("jogador_criado", extra={"apelido": apelido})
    return jogador, True


def iniciar_partida(
    sessao: Session, jogador: Jogador, data: date, segredo: str
) -> tuple[Partida, bool]:
    existente = _buscar_partida_do_dia(sessao, jogador, data)
    if existente is not None:
        return existente, False

    partida = Partida(
        jogador_id=jogador.id,
        data=data,
        palavra=palavra_do_dia(data, segredo),
        status=STATUS_EM_ANDAMENTO,
        tentativas=0,
    )
    sessao.add(partida)
    try:
        sessao.commit()
    except IntegrityError:
        sessao.rollback()
        return _buscar_partida_do_dia(sessao, jogador, data), False

    metricas.registrar_partida_iniciada()
    logger.info(
        "partida_iniciada",
        extra={"apelido": jogador.apelido, "partida_id": partida.id, "data": data.isoformat()},
    )
    return partida, True


def _proximo_status(palavra: str, partida: Partida) -> str:
    if palavra == partida.palavra:
        return STATUS_VENCIDA
    if partida.tentativas >= MAXIMO_TENTATIVAS:
        return STATUS_PERDIDA
    return STATUS_EM_ANDAMENTO


def registrar_palpite(
    sessao: Session, jogador: Jogador, partida_id: int, texto: str
) -> tuple[Partida, Palpite]:
    partida = sessao.scalar(
        select(Partida)
        .where(Partida.id == partida_id, Partida.jogador_id == jogador.id)
        .with_for_update()
    )
    if partida is None:
        raise RecursoNaoEncontrado("Partida não encontrada")
    if partida.status != STATUS_EM_ANDAMENTO:
        raise PartidaFinalizada("Esta partida já foi finalizada")

    palavra = normalizar_palavra(texto)
    if not palavra_valida(palavra):
        raise PalpiteInvalido(f"O palpite deve ter exatamente {TAMANHO_PALAVRA} letras")

    estados = avaliar_palpite(palavra, partida.palavra)
    partida.tentativas += 1
    palpite = Palpite(
        ordem=partida.tentativas, palavra=palavra, resultado=codificar_resultado(estados)
    )
    partida.palpites.append(palpite)
    partida.status = _proximo_status(palavra, partida)
    if partida.status != STATUS_EM_ANDAMENTO:
        partida.finalizada_em = datetime.now(UTC)
    sessao.commit()

    metricas.registrar_palpite(partida.status)
    logger.info(
        "palpite_registrado",
        extra={
            "apelido": jogador.apelido,
            "partida_id": partida.id,
            "tentativa": partida.tentativas,
            "status_partida": partida.status,
        },
    )
    return partida, palpite


def obter_estatisticas(sessao: Session, apelido: str, hoje: date) -> Estatisticas:
    jogador = _buscar_jogador(sessao, apelido.lower())
    if jogador is None:
        raise RecursoNaoEncontrado("Jogador não encontrado")

    partidas = sessao.scalars(select(Partida).where(Partida.jogador_id == jogador.id)).all()
    return calcular_estatisticas(partidas, hoje)


def obter_ranking(sessao: Session, limite: int = LIMITE_RANKING) -> list[LinhaRanking]:
    vitorias = func.count(Partida.id).filter(Partida.status == STATUS_VENCIDA)
    partidas = func.count(Partida.id).filter(Partida.status != STATUS_EM_ANDAMENTO)
    media = func.avg(Partida.tentativas).filter(Partida.status == STATUS_VENCIDA)

    consulta = (
        select(Jogador.apelido, vitorias, partidas, media)
        .join(Partida, Partida.jogador_id == Jogador.id)
        .group_by(Jogador.id)
        .having(partidas > 0)
        .order_by(vitorias.desc(), media.asc().nulls_last(), Jogador.apelido)
        .limit(limite)
    )
    return [
        LinhaRanking(
            apelido=apelido,
            vitorias=total_vitorias,
            partidas=total_partidas,
            media_tentativas=_arredondar_media(media_tentativas),
        )
        for apelido, total_vitorias, total_partidas, media_tentativas in sessao.execute(consulta)
    ]


def _arredondar_media(media: object) -> float | None:
    if media is None:
        return None
    return round(float(media), 2)
