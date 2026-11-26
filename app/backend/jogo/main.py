import logging
import time
import uuid
from collections.abc import Awaitable, Callable

from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse

from jogo import metricas
from jogo.logs import configurar_logs
from jogo.rotas import roteador
from jogo.servicos import ErroDominio

ROTAS_NAO_OBSERVADAS = {"/metrics"}
ROTA_DESCONHECIDA = "nao_mapeada"

logger = logging.getLogger("jogo.http")


def rota_da_requisicao(request: Request) -> str:
    rota = request.scope.get("route")
    if rota is None:
        return ROTA_DESCONHECIDA
    return getattr(rota, "path", ROTA_DESCONHECIDA)


def _nivel_do_log(rota: str, status: int) -> int:
    if status >= 500:
        return logging.ERROR
    if status >= 400:
        return logging.WARNING
    if rota == "/health":
        return logging.DEBUG
    return logging.INFO


def _registrar_requisicao(
    request: Request, status: int, inicio: float, id_requisicao: str, com_excecao: bool = False
) -> None:
    duracao = time.perf_counter() - inicio
    rota = rota_da_requisicao(request)
    metricas.registrar_requisicao(request.method, rota, status, duracao)
    logger.log(
        _nivel_do_log(rota, status),
        "requisicao",
        exc_info=com_excecao,
        extra={
            "metodo": request.method,
            "rota": rota,
            "caminho": request.url.path,
            "status": status,
            "duracao_ms": round(duracao * 1000, 2),
            "id_requisicao": id_requisicao,
        },
    )


async def observar_requisicao(
    request: Request, call_next: Callable[[Request], Awaitable[Response]]
) -> Response:
    if request.url.path in ROTAS_NAO_OBSERVADAS:
        return await call_next(request)

    inicio = time.perf_counter()
    id_requisicao = request.headers.get("x-request-id") or uuid.uuid4().hex
    try:
        resposta = await call_next(request)
    except Exception:
        _registrar_requisicao(request, 500, inicio, id_requisicao, com_excecao=True)
        raise

    resposta.headers["X-Request-ID"] = id_requisicao
    _registrar_requisicao(request, resposta.status_code, inicio, id_requisicao)
    return resposta


async def tratar_erro_dominio(request: Request, erro: Exception) -> JSONResponse:
    codigo = getattr(erro, "codigo_http", 400)
    return JSONResponse(status_code=codigo, content={"detail": str(erro)})


def criar_app() -> FastAPI:
    configurar_logs()
    app = FastAPI(title="Termo UFRPE", version="1.0.0")
    app.middleware("http")(observar_requisicao)
    app.add_exception_handler(ErroDominio, tratar_erro_dominio)
    app.include_router(roteador)
    return app


app = criar_app()
