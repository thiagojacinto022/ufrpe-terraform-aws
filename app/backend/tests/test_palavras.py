from datetime import date, timedelta

from jogo.avaliacao import normalizar_palavra, palavra_valida
from jogo.palavras import PALAVRAS, palavra_do_dia


def test_todas_as_palavras_sao_validas_e_normalizadas() -> None:
    invalidas = [
        palavra
        for palavra in PALAVRAS
        if not palavra_valida(palavra) or normalizar_palavra(palavra) != palavra
    ]

    assert invalidas == []


def test_palavras_nao_se_repetem() -> None:
    assert len(PALAVRAS) == len(set(PALAVRAS))


def test_palavra_do_dia_e_deterministica_e_pertence_a_lista() -> None:
    data = date(2026, 3, 1)

    assert palavra_do_dia(data, "segredo-a") == palavra_do_dia(data, "segredo-a")
    assert palavra_do_dia(data, "segredo-a") in PALAVRAS


def test_palavra_do_dia_varia_ao_longo_dos_dias() -> None:
    inicio = date(2026, 1, 1)
    palavras = {palavra_do_dia(inicio + timedelta(days=dia), "segredo-a") for dia in range(30)}

    assert len(palavras) > 15
