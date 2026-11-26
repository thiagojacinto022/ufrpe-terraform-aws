from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram,
    disable_created_metrics,
    generate_latest,
)

from jogo.modelos import STATUS_PERDIDA, STATUS_VENCIDA

disable_created_metrics()

PARTIDAS_INICIADAS = Counter("partidas_iniciadas_total", "Partidas iniciadas")
PARTIDAS_VENCIDAS = Counter("partidas_vencidas_total", "Partidas vencidas")
PARTIDAS_PERDIDAS = Counter("partidas_perdidas_total", "Partidas perdidas")
PALPITES = Counter("palpites_total", "Palpites avaliados")
REQUISICOES = Counter(
    "http_requisicoes_total", "Requisições HTTP atendidas", ["metodo", "rota", "status"]
)
LATENCIA = Histogram(
    "http_requisicao_duracao_segundos",
    "Latência das requisições HTTP por rota",
    ["metodo", "rota"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0),
)


def registrar_requisicao(metodo: str, rota: str, status: int, duracao: float) -> None:
    REQUISICOES.labels(metodo=metodo, rota=rota, status=str(status)).inc()
    LATENCIA.labels(metodo=metodo, rota=rota).observe(duracao)


def registrar_partida_iniciada() -> None:
    PARTIDAS_INICIADAS.inc()


def registrar_palpite(status_partida: str) -> None:
    PALPITES.inc()
    if status_partida == STATUS_VENCIDA:
        PARTIDAS_VENCIDAS.inc()
        return
    if status_partida == STATUS_PERDIDA:
        PARTIDAS_PERDIDAS.inc()


def exportar() -> tuple[bytes, str]:
    return generate_latest(), CONTENT_TYPE_LATEST
