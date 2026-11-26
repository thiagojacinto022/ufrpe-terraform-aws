import pytest

from jogo.avaliacao import (
    EstadoLetra,
    avaliar_palpite,
    codificar_resultado,
    decodificar_resultado,
    normalizar_palavra,
    palavra_valida,
)

C = EstadoLetra.CORRETA
P = EstadoLetra.PRESENTE
A = EstadoLetra.AUSENTE


@pytest.mark.parametrize(
    ("palpite", "segredo", "esperado"),
    [
        ("PORTA", "PORTA", [C, C, C, C, C]),
        ("FUNDO", "BRISA", [A, A, A, A, A]),
        ("TORPA", "PORTA", [P, C, C, P, C]),
        ("RARAS", "CARRO", [P, C, C, A, A]),
        ("PAPAI", "PORTA", [C, P, A, A, A]),
        ("SSSSS", "MASSA", [A, A, C, C, A]),
        ("ACACA", "CASCA", [P, P, A, C, C]),
        ("OOOOO", "LIVRO", [A, A, A, A, C]),
        ("ARARA", "TERRA", [A, P, A, C, C]),
        ("ERRAR", "TERRA", [P, P, C, P, A]),
    ],
)
def test_avaliar_palpite(palpite: str, segredo: str, esperado: list[EstadoLetra]) -> None:
    assert avaliar_palpite(palpite, segredo) == esperado


def test_letra_repetida_no_palpite_so_marca_presente_ate_a_quantidade_do_segredo() -> None:
    resultado = avaliar_palpite("AAAEE", "BAIXA")

    assert resultado.count(C) + resultado.count(P) == 2
    assert resultado == [P, C, A, A, A]


def test_letra_correta_tem_prioridade_sobre_presente_anterior() -> None:
    assert avaliar_palpite("AAAAA", "PORTA") == [A, A, A, A, C]
    assert avaliar_palpite("LLAMA", "MALHA") == [P, A, P, P, C]


def test_tamanhos_diferentes_geram_erro() -> None:
    with pytest.raises(ValueError):
        avaliar_palpite("CASA", "CASAL")


@pytest.mark.parametrize(
    ("texto", "esperado"),
    [
        ("pátio", "PATIO"),
        ("  União ", "UNIAO"),
        ("PREÇO", "PRECO"),
        ("saúde", "SAUDE"),
    ],
)
def test_normalizar_palavra_remove_acentos_e_espacos(texto: str, esperado: str) -> None:
    assert normalizar_palavra(texto) == esperado


@pytest.mark.parametrize(
    ("palavra", "valida"),
    [
        ("PORTA", True),
        ("PORT", False),
        ("PORTAS", False),
        ("PORT4", False),
        ("PO TA", False),
        ("", False),
    ],
)
def test_palavra_valida(palavra: str, valida: bool) -> None:
    assert palavra_valida(palavra) is valida


def test_codificar_e_decodificar_resultado_sao_inversos() -> None:
    estados = [C, P, A, A, C]

    assert codificar_resultado(estados) == "CPAAC"
    assert decodificar_resultado("CPAAC") == estados
