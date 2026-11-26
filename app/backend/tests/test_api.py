from datetime import UTC, date, datetime, timedelta

import jwt
from alembic.autogenerate import compare_metadata
from alembic.migration import MigrationContext
from fastapi.testclient import TestClient
from prometheus_client import REGISTRY
from sqlalchemy import Engine

from jogo.avaliacao import avaliar_palpite
from jogo.configuracao import obter_configuracao
from jogo.modelos import Base
from jogo.palavras import PALAVRAS, palavra_do_dia
from tests.conftest import Relogio


def palavra_secreta(data: date) -> str:
    return palavra_do_dia(data, obter_configuracao().token_segredo)


def palavra_errada(data: date) -> str:
    segredo = palavra_secreta(data)
    return next(palavra for palavra in PALAVRAS if palavra != segredo)


def entrar(cliente: TestClient, apelido: str) -> dict[str, str]:
    resposta = cliente.post("/api/jogadores", json={"apelido": apelido})
    return {"Authorization": f"Bearer {resposta.json()['token']}"}


def iniciar(cliente: TestClient, cabecalhos: dict[str, str]) -> dict:
    return cliente.post("/api/partidas", headers=cabecalhos).json()


def palpitar(cliente: TestClient, cabecalhos: dict[str, str], partida_id: int, palavra: str):
    return cliente.post(
        f"/api/partidas/{partida_id}/palpites", headers=cabecalhos, json={"palavra": palavra}
    )


def jogar(
    cliente: TestClient, cabecalhos: dict[str, str], data: date, acertar_na: int | None
) -> None:
    partida = iniciar(cliente, cabecalhos)
    tentativas = acertar_na or 6
    for tentativa in range(1, tentativas + 1):
        acertou = tentativa == acertar_na
        palavra = palavra_secreta(data) if acertou else palavra_errada(data)
        palpitar(cliente, cabecalhos, partida["id"], palavra)


def amostra(nome: str, rotulos: dict[str, str] | None = None) -> float:
    return REGISTRY.get_sample_value(nome, rotulos or {}) or 0.0


def test_migracoes_estao_sincronizadas_com_os_modelos(banco: Engine) -> None:
    with banco.connect() as conexao:
        diferencas = compare_metadata(MigrationContext.configure(conexao), Base.metadata)

    assert diferencas == []


def test_health(cliente: TestClient) -> None:
    resposta = cliente.get("/health")

    assert resposta.status_code == 200
    assert resposta.json() == {"status": "ok", "banco": "ok"}
    assert "X-Request-ID" in resposta.headers


def test_criar_jogador_e_entrar_de_novo(cliente: TestClient) -> None:
    primeira = cliente.post("/api/jogadores", json={"apelido": "Maria_1"})
    segunda = cliente.post("/api/jogadores", json={"apelido": "maria_1"})

    assert primeira.status_code == 201
    assert segunda.status_code == 200
    assert primeira.json()["apelido"] == "maria_1"
    assert segunda.json()["apelido"] == "maria_1"
    assert primeira.json()["token"]


def test_apelido_invalido(cliente: TestClient) -> None:
    for apelido in ["ab", "nome com espaco", "x" * 21, "ação"]:
        resposta = cliente.post("/api/jogadores", json={"apelido": apelido})
        assert resposta.status_code == 422


def bearer(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_partida_exige_token_valido(cliente: TestClient) -> None:
    entrar(cliente, "joao")
    agora = datetime.now(UTC)
    outro_segredo = jwt.encode(
        {"sub": "1", "exp": agora + timedelta(hours=1)}, "outro-segredo-qualquer-123", "HS256"
    )
    expirado = jwt.encode(
        {"sub": "1", "exp": agora - timedelta(minutes=1)},
        obter_configuracao().token_segredo,
        "HS256",
    )

    assert cliente.post("/api/partidas").status_code == 401
    assert cliente.post("/api/partidas", headers=bearer("abc")).status_code == 401
    assert cliente.post("/api/partidas", headers=bearer(outro_segredo)).status_code == 401
    assert cliente.post("/api/partidas", headers=bearer(expirado)).status_code == 401


def test_iniciar_partida_e_idempotente_no_mesmo_dia(cliente: TestClient) -> None:
    cabecalhos = entrar(cliente, "ana")

    primeira = cliente.post("/api/partidas", headers=cabecalhos)
    segunda = cliente.post("/api/partidas", headers=cabecalhos)

    assert primeira.status_code == 201
    assert segunda.status_code == 200
    assert primeira.json()["id"] == segunda.json()["id"]
    assert primeira.json()["tentativas_restantes"] == 6
    assert "palavra" not in primeira.json()


def test_palpite_errado_devolve_resultado_por_letra(cliente: TestClient, relogio: Relogio) -> None:
    cabecalhos = entrar(cliente, "bia")
    partida = iniciar(cliente, cabecalhos)
    palavra = palavra_errada(relogio.hoje)

    resposta = palpitar(cliente, cabecalhos, partida["id"], palavra.lower())

    assert resposta.status_code == 200
    corpo = resposta.json()
    esperado = [estado.value for estado in avaliar_palpite(palavra, palavra_secreta(relogio.hoje))]
    assert [letra["estado"] for letra in corpo["palpite"]["letras"]] == esperado
    assert "".join(letra["letra"] for letra in corpo["palpite"]["letras"]) == palavra
    assert corpo["status"] == "em_andamento"
    assert corpo["tentativas_restantes"] == 5
    assert palavra_secreta(relogio.hoje) not in resposta.text


def test_acertar_vence_e_bloqueia_novos_palpites(cliente: TestClient, relogio: Relogio) -> None:
    cabecalhos = entrar(cliente, "caio")
    partida = iniciar(cliente, cabecalhos)

    resposta = palpitar(cliente, cabecalhos, partida["id"], palavra_secreta(relogio.hoje))
    depois = palpitar(cliente, cabecalhos, partida["id"], palavra_errada(relogio.hoje))

    assert resposta.json()["status"] == "vencida"
    assert resposta.json()["tentativas_restantes"] == 0
    assert all(letra["estado"] == "correta" for letra in resposta.json()["palpite"]["letras"])
    assert depois.status_code == 409


def test_seis_erros_perdem_sem_revelar_a_palavra(cliente: TestClient, relogio: Relogio) -> None:
    cabecalhos = entrar(cliente, "duda")
    partida = iniciar(cliente, cabecalhos)
    segredo = palavra_secreta(relogio.hoje)

    respostas = [
        palpitar(cliente, cabecalhos, partida["id"], palavra_errada(relogio.hoje)) for _ in range(6)
    ]
    retomada = cliente.post("/api/partidas", headers=cabecalhos)
    excedente = palpitar(cliente, cabecalhos, partida["id"], segredo)

    assert respostas[-1].json()["status"] == "perdida"
    assert retomada.json()["status"] == "perdida"
    assert len(retomada.json()["palpites"]) == 6
    assert excedente.status_code == 409
    assert all(segredo not in resposta.text for resposta in [*respostas, retomada])


def test_palpite_invalido_nao_consome_tentativa(cliente: TestClient) -> None:
    cabecalhos = entrar(cliente, "edu")
    partida = iniciar(cliente, cabecalhos)

    for palavra in ["casa", "casais", "c4sas", "ab de"]:
        assert palpitar(cliente, cabecalhos, partida["id"], palavra).status_code == 422

    assert iniciar(cliente, cabecalhos)["tentativas_restantes"] == 6


def test_palpite_com_acento_e_aceito(cliente: TestClient) -> None:
    cabecalhos = entrar(cliente, "fabi")
    partida = iniciar(cliente, cabecalhos)

    resposta = palpitar(cliente, cabecalhos, partida["id"], "pátio")

    assert resposta.status_code == 200
    assert "".join(letra["letra"] for letra in resposta.json()["palpite"]["letras"]) == "PATIO"


def test_nao_e_possivel_jogar_a_partida_de_outro_jogador(
    cliente: TestClient, relogio: Relogio
) -> None:
    dono = entrar(cliente, "gabi")
    intruso = entrar(cliente, "hugo")
    partida = iniciar(cliente, dono)

    resposta = palpitar(cliente, intruso, partida["id"], palavra_secreta(relogio.hoje))

    assert resposta.status_code == 404


def test_ranking_ordena_por_vitorias_e_media(cliente: TestClient, relogio: Relogio) -> None:
    jogar(cliente, entrar(cliente, "bia"), relogio.hoje, acertar_na=3)
    jogar(cliente, entrar(cliente, "ana"), relogio.hoje, acertar_na=1)
    jogar(cliente, entrar(cliente, "caio"), relogio.hoje, acertar_na=None)
    entrar(cliente, "sem_partidas")

    ranking = cliente.get("/api/ranking").json()

    assert [linha["apelido"] for linha in ranking] == ["ana", "bia", "caio"]
    assert [linha["posicao"] for linha in ranking] == [1, 2, 3]
    assert ranking[0]["media_tentativas"] == 1.0
    assert ranking[1]["media_tentativas"] == 3.0
    assert ranking[2]["vitorias"] == 0
    assert ranking[2]["media_tentativas"] is None
    assert ranking[2]["taxa_vitoria"] == 0.0


def test_estatisticas_com_sequencia_de_dias(cliente: TestClient, relogio: Relogio) -> None:
    cabecalhos = entrar(cliente, "iris")
    resultados = [2, 4, None, 3, 5]
    for dia, acertar_na in enumerate(resultados):
        relogio.hoje = date(2026, 1, 10) + timedelta(days=dia)
        jogar(cliente, cabecalhos, relogio.hoje, acertar_na)

    estatisticas = cliente.get("/api/jogadores/IRIS/estatisticas").json()
    relogio.hoje += timedelta(days=3)
    depois_da_pausa = cliente.get("/api/jogadores/iris/estatisticas").json()

    assert estatisticas == {
        "apelido": "iris",
        "partidas_jogadas": 5,
        "vitorias": 4,
        "taxa_vitoria": 0.8,
        "sequencia_atual": 2,
        "melhor_sequencia": 2,
        "media_tentativas": 3.5,
    }
    assert depois_da_pausa["sequencia_atual"] == 0


def test_estatisticas_de_jogador_inexistente(cliente: TestClient) -> None:
    assert cliente.get("/api/jogadores/ninguem/estatisticas").status_code == 404


def test_metricas_de_negocio_e_latencia_por_rota(cliente: TestClient, relogio: Relogio) -> None:
    rota_palpites = {"metodo": "POST", "rota": "/api/partidas/{partida_id}/palpites"}
    iniciadas = amostra("partidas_iniciadas_total")
    vencidas = amostra("partidas_vencidas_total")
    palpites = amostra("palpites_total")
    latencias = amostra("http_requisicao_duracao_segundos_count", rota_palpites)

    jogar(cliente, entrar(cliente, "joana"), relogio.hoje, acertar_na=2)
    resposta = cliente.get("/metrics")

    assert amostra("partidas_iniciadas_total") == iniciadas + 1
    assert amostra("partidas_vencidas_total") == vencidas + 1
    assert amostra("palpites_total") == palpites + 2
    assert amostra("http_requisicao_duracao_segundos_count", rota_palpites) == latencias + 2
    assert resposta.status_code == 200
    assert 'rota="/api/partidas/{partida_id}/palpites"' in resposta.text
    assert "partidas_iniciadas_total" in resposta.text
