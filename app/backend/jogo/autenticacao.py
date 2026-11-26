from datetime import UTC, datetime, timedelta
from typing import Annotated

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from jogo.banco import obter_sessao
from jogo.configuracao import Configuracao, obter_configuracao
from jogo.modelos import Jogador

ALGORITMO = "HS256"

esquema_bearer = HTTPBearer(auto_error=False)


def emitir_token(jogador: Jogador, configuracao: Configuracao) -> str:
    agora = datetime.now(UTC)
    carga = {
        "sub": str(jogador.id),
        "apelido": jogador.apelido,
        "iat": agora,
        "exp": agora + timedelta(hours=configuracao.token_validade_horas),
    }
    return jwt.encode(carga, configuracao.token_segredo, algorithm=ALGORITMO)


def _nao_autorizado(detalhe: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detalhe,
        headers={"WWW-Authenticate": "Bearer"},
    )


def obter_jogador_autenticado(
    credenciais: Annotated[HTTPAuthorizationCredentials | None, Depends(esquema_bearer)],
    sessao: Annotated[Session, Depends(obter_sessao)],
    configuracao: Annotated[Configuracao, Depends(obter_configuracao)],
) -> Jogador:
    if credenciais is None:
        raise _nao_autorizado("Token ausente")

    try:
        carga = jwt.decode(
            credenciais.credentials,
            configuracao.token_segredo,
            algorithms=[ALGORITMO],
            options={"require": ["exp", "sub"]},
        )
    except jwt.PyJWTError as erro:
        raise _nao_autorizado("Token inválido") from erro

    jogador = sessao.get(Jogador, int(carga["sub"]))
    if jogador is None:
        raise _nao_autorizado("Jogador não encontrado")
    return jogador
