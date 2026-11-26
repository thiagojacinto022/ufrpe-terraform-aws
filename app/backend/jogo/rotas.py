import logging
from dataclasses import asdict
from datetime import date, datetime
from typing import Annotated
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Response, status
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from jogo import metricas, servicos
from jogo.autenticacao import emitir_token, obter_jogador_autenticado
from jogo.avaliacao import decodificar_resultado
from jogo.banco import obter_sessao
from jogo.configuracao import Configuracao, obter_configuracao
from jogo.esquemas import (
    EntradaJogador,
    EntradaPalpite,
    LetraAvaliada,
    SaidaEstatisticas,
    SaidaJogador,
    SaidaLinhaRanking,
    SaidaPalpite,
    SaidaPalpiteRegistrado,
    SaidaPartida,
)
from jogo.modelos import STATUS_EM_ANDAMENTO, Jogador, Palpite, Partida

logger = logging.getLogger("jogo.rotas")

SessaoDep = Annotated[Session, Depends(obter_sessao)]
ConfiguracaoDep = Annotated[Configuracao, Depends(obter_configuracao)]
JogadorDep = Annotated[Jogador, Depends(obter_jogador_autenticado)]


def obter_data_hoje(configuracao: ConfiguracaoDep) -> date:
    return datetime.now(ZoneInfo(configuracao.fuso_horario)).date()


HojeDep = Annotated[date, Depends(obter_data_hoje)]

roteador = APIRouter()


def montar_saida_palpite(palpite: Palpite) -> SaidaPalpite:
    letras = [
        LetraAvaliada(letra=letra, estado=estado)
        for letra, estado in zip(
            palpite.palavra, decodificar_resultado(palpite.resultado), strict=True
        )
    ]
    return SaidaPalpite(ordem=palpite.ordem, letras=letras)


def _tentativas_restantes(partida: Partida) -> int:
    if partida.status != STATUS_EM_ANDAMENTO:
        return 0
    return servicos.MAXIMO_TENTATIVAS - partida.tentativas


def montar_saida_partida(partida: Partida) -> SaidaPartida:
    return SaidaPartida(
        id=partida.id,
        data=partida.data,
        status=partida.status,
        tentativas=partida.tentativas,
        tentativas_restantes=_tentativas_restantes(partida),
        palpites=[montar_saida_palpite(palpite) for palpite in partida.palpites],
    )


@roteador.get("/health")
def verificar_saude(sessao: SessaoDep) -> JSONResponse:
    try:
        sessao.execute(text("SELECT 1"))
    except SQLAlchemyError:
        logger.exception("banco_indisponivel")
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"status": "erro", "banco": "indisponivel"},
        )
    return JSONResponse(content={"status": "ok", "banco": "ok"})


@roteador.get("/metrics", include_in_schema=False)
def expor_metricas() -> Response:
    conteudo, tipo = metricas.exportar()
    return Response(content=conteudo, media_type=tipo)


@roteador.post("/api/jogadores")
def entrar(
    entrada: EntradaJogador,
    resposta: Response,
    sessao: SessaoDep,
    configuracao: ConfiguracaoDep,
) -> SaidaJogador:
    jogador, criado = servicos.entrar_jogador(sessao, entrada.apelido)
    resposta.status_code = status.HTTP_201_CREATED if criado else status.HTTP_200_OK
    return SaidaJogador(apelido=jogador.apelido, token=emitir_token(jogador, configuracao))


@roteador.post("/api/partidas")
def iniciar_partida(
    resposta: Response,
    jogador: JogadorDep,
    sessao: SessaoDep,
    configuracao: ConfiguracaoDep,
    hoje: HojeDep,
) -> SaidaPartida:
    partida, criada = servicos.iniciar_partida(sessao, jogador, hoje, configuracao.token_segredo)
    resposta.status_code = status.HTTP_201_CREATED if criada else status.HTTP_200_OK
    return montar_saida_partida(partida)


@roteador.post("/api/partidas/{partida_id}/palpites")
def enviar_palpite(
    partida_id: int,
    entrada: EntradaPalpite,
    jogador: JogadorDep,
    sessao: SessaoDep,
) -> SaidaPalpiteRegistrado:
    partida, palpite = servicos.registrar_palpite(sessao, jogador, partida_id, entrada.palavra)
    return SaidaPalpiteRegistrado(
        palpite=montar_saida_palpite(palpite),
        status=partida.status,
        tentativas=partida.tentativas,
        tentativas_restantes=_tentativas_restantes(partida),
    )


@roteador.get("/api/ranking")
def consultar_ranking(sessao: SessaoDep) -> list[SaidaLinhaRanking]:
    return [
        SaidaLinhaRanking(
            posicao=posicao,
            apelido=linha.apelido,
            vitorias=linha.vitorias,
            partidas=linha.partidas,
            taxa_vitoria=round(linha.vitorias / linha.partidas, 3),
            media_tentativas=linha.media_tentativas,
        )
        for posicao, linha in enumerate(servicos.obter_ranking(sessao), start=1)
    ]


@roteador.get("/api/jogadores/{apelido}/estatisticas")
def consultar_estatisticas(apelido: str, sessao: SessaoDep, hoje: HojeDep) -> SaidaEstatisticas:
    estatisticas = servicos.obter_estatisticas(sessao, apelido, hoje)
    return SaidaEstatisticas(apelido=apelido.lower(), **asdict(estatisticas))
