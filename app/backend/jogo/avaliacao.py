import unicodedata
from collections import Counter
from enum import StrEnum

TAMANHO_PALAVRA = 5


class EstadoLetra(StrEnum):
    CORRETA = "correta"
    PRESENTE = "presente"
    AUSENTE = "ausente"


CODIGOS = {
    EstadoLetra.CORRETA: "C",
    EstadoLetra.PRESENTE: "P",
    EstadoLetra.AUSENTE: "A",
}
ESTADOS_POR_CODIGO = {codigo: estado for estado, codigo in CODIGOS.items()}


def normalizar_palavra(texto: str) -> str:
    decomposto = unicodedata.normalize("NFD", texto.strip().upper())
    return "".join(caractere for caractere in decomposto if unicodedata.category(caractere) != "Mn")


def palavra_valida(palavra: str) -> bool:
    return len(palavra) == TAMANHO_PALAVRA and palavra.isascii() and palavra.isalpha()


def avaliar_palpite(palpite: str, segredo: str) -> list[EstadoLetra]:
    if len(palpite) != len(segredo):
        raise ValueError("Palpite e segredo precisam ter o mesmo tamanho")

    resultado = [EstadoLetra.AUSENTE] * len(segredo)
    letras_disponiveis: Counter[str] = Counter()

    for posicao, (letra_palpite, letra_segredo) in enumerate(zip(palpite, segredo, strict=True)):
        if letra_palpite == letra_segredo:
            resultado[posicao] = EstadoLetra.CORRETA
            continue
        letras_disponiveis[letra_segredo] += 1

    for posicao, letra in enumerate(palpite):
        if resultado[posicao] is EstadoLetra.CORRETA:
            continue
        if letras_disponiveis[letra] == 0:
            continue
        resultado[posicao] = EstadoLetra.PRESENTE
        letras_disponiveis[letra] -= 1

    return resultado


def codificar_resultado(estados: list[EstadoLetra]) -> str:
    return "".join(CODIGOS[estado] for estado in estados)


def decodificar_resultado(codigo: str) -> list[EstadoLetra]:
    return [ESTADOS_POR_CODIGO[letra] for letra in codigo]
