from datetime import date

from pydantic import BaseModel, Field

from jogo.avaliacao import EstadoLetra


class EntradaJogador(BaseModel):
    apelido: str = Field(pattern=r"^[A-Za-z0-9_]{3,20}$")


class SaidaJogador(BaseModel):
    apelido: str
    token: str


class EntradaPalpite(BaseModel):
    palavra: str = Field(min_length=1, max_length=20)


class LetraAvaliada(BaseModel):
    letra: str
    estado: EstadoLetra


class SaidaPalpite(BaseModel):
    ordem: int
    letras: list[LetraAvaliada]


class SaidaPartida(BaseModel):
    id: int
    data: date
    status: str
    tentativas: int
    tentativas_restantes: int
    palpites: list[SaidaPalpite]


class SaidaPalpiteRegistrado(BaseModel):
    palpite: SaidaPalpite
    status: str
    tentativas: int
    tentativas_restantes: int


class SaidaLinhaRanking(BaseModel):
    posicao: int
    apelido: str
    vitorias: int
    partidas: int
    taxa_vitoria: float
    media_tentativas: float | None


class SaidaEstatisticas(BaseModel):
    apelido: str
    partidas_jogadas: int
    vitorias: int
    taxa_vitoria: float
    sequencia_atual: int
    melhor_sequencia: int
    media_tentativas: float | None
