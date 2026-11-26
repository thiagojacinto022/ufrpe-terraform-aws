from datetime import date, timedelta
from types import SimpleNamespace

from jogo.estatisticas import calcular_estatisticas
from jogo.modelos import STATUS_EM_ANDAMENTO, STATUS_PERDIDA, STATUS_VENCIDA

INICIO = date(2026, 2, 1)


def partida(dia: int, status: str, tentativas: int) -> SimpleNamespace:
    return SimpleNamespace(data=INICIO + timedelta(days=dia), status=status, tentativas=tentativas)


def test_sem_partidas() -> None:
    estatisticas = calcular_estatisticas([], INICIO)

    assert estatisticas.partidas_jogadas == 0
    assert estatisticas.vitorias == 0
    assert estatisticas.taxa_vitoria == 0.0
    assert estatisticas.sequencia_atual == 0
    assert estatisticas.melhor_sequencia == 0
    assert estatisticas.media_tentativas is None


def test_sequencias_media_e_taxa() -> None:
    partidas = [
        partida(0, STATUS_VENCIDA, 3),
        partida(1, STATUS_VENCIDA, 4),
        partida(2, STATUS_VENCIDA, 2),
        partida(3, STATUS_PERDIDA, 6),
        partida(4, STATUS_VENCIDA, 5),
        partida(5, STATUS_VENCIDA, 1),
    ]

    estatisticas = calcular_estatisticas(partidas, INICIO + timedelta(days=5))

    assert estatisticas.partidas_jogadas == 6
    assert estatisticas.vitorias == 5
    assert estatisticas.taxa_vitoria == 0.833
    assert estatisticas.melhor_sequencia == 3
    assert estatisticas.sequencia_atual == 2
    assert estatisticas.media_tentativas == 3.0


def test_dia_sem_jogar_quebra_a_sequencia() -> None:
    partidas = [partida(0, STATUS_VENCIDA, 3), partida(2, STATUS_VENCIDA, 3)]

    estatisticas = calcular_estatisticas(partidas, INICIO + timedelta(days=2))

    assert estatisticas.melhor_sequencia == 1
    assert estatisticas.sequencia_atual == 1


def test_sequencia_atual_zera_quando_o_jogador_some() -> None:
    partidas = [partida(0, STATUS_VENCIDA, 3), partida(1, STATUS_VENCIDA, 3)]

    ontem = calcular_estatisticas(partidas, INICIO + timedelta(days=2))
    semana_depois = calcular_estatisticas(partidas, INICIO + timedelta(days=8))

    assert ontem.sequencia_atual == 2
    assert semana_depois.sequencia_atual == 0
    assert semana_depois.melhor_sequencia == 2


def test_partida_em_andamento_nao_conta() -> None:
    partidas = [partida(0, STATUS_VENCIDA, 2), partida(1, STATUS_EM_ANDAMENTO, 3)]

    estatisticas = calcular_estatisticas(partidas, INICIO + timedelta(days=1))

    assert estatisticas.partidas_jogadas == 1
    assert estatisticas.sequencia_atual == 1
