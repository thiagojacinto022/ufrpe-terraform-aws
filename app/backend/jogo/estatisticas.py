from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date, timedelta
from typing import Protocol

from jogo.modelos import STATUS_EM_ANDAMENTO, STATUS_VENCIDA

UM_DIA = timedelta(days=1)


class PartidaResumida(Protocol):
    data: date
    status: str
    tentativas: int


@dataclass(frozen=True)
class Estatisticas:
    partidas_jogadas: int
    vitorias: int
    taxa_vitoria: float
    sequencia_atual: int
    melhor_sequencia: int
    media_tentativas: float | None


def _media_tentativas(vencidas: Sequence[PartidaResumida]) -> float | None:
    if not vencidas:
        return None
    return round(sum(partida.tentativas for partida in vencidas) / len(vencidas), 2)


def calcular_estatisticas(partidas: Sequence[PartidaResumida], hoje: date) -> Estatisticas:
    finalizadas = sorted(
        (partida for partida in partidas if partida.status != STATUS_EM_ANDAMENTO),
        key=lambda partida: partida.data,
    )
    vencidas = [partida for partida in finalizadas if partida.status == STATUS_VENCIDA]

    sequencia = 0
    melhor_sequencia = 0
    data_anterior: date | None = None
    for partida in finalizadas:
        consecutiva = data_anterior is not None and partida.data - data_anterior == UM_DIA
        data_anterior = partida.data
        if partida.status != STATUS_VENCIDA:
            sequencia = 0
            continue
        sequencia = sequencia + 1 if consecutiva else 1
        melhor_sequencia = max(melhor_sequencia, sequencia)

    sequencia_vigente = data_anterior is not None and hoje - data_anterior <= UM_DIA
    taxa = round(len(vencidas) / len(finalizadas), 3) if finalizadas else 0.0

    return Estatisticas(
        partidas_jogadas=len(finalizadas),
        vitorias=len(vencidas),
        taxa_vitoria=taxa,
        sequencia_atual=sequencia if sequencia_vigente else 0,
        melhor_sequencia=melhor_sequencia,
        media_tentativas=_media_tentativas(vencidas),
    )
