"use strict";

const TAMANHO = 5;
const MAXIMO_TENTATIVAS = 6;
const CHAVE_SESSAO = "termo.sessao";
const FILEIRAS_TECLADO = [
  ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
  ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
  ["ENTER", "Z", "X", "C", "V", "B", "N", "M", "BACKSPACE"],
];
const ROTULOS_TECLAS = { ENTER: "Enviar", BACKSPACE: "⌫" };
const PRIORIDADE_ESTADO = { ausente: 1, presente: 2, correta: 3 };

const elementos = {
  telaEntrada: document.getElementById("tela-entrada"),
  telaJogo: document.getElementById("tela-jogo"),
  painel: document.getElementById("painel"),
  formEntrada: document.getElementById("form-entrada"),
  campoApelido: document.getElementById("apelido"),
  jogadorAtual: document.getElementById("jogador-atual"),
  botaoSair: document.getElementById("botao-sair"),
  tabuleiro: document.getElementById("tabuleiro"),
  teclado: document.getElementById("teclado"),
  mensagem: document.getElementById("mensagem"),
  estatisticas: document.getElementById("estatisticas"),
  ranking: document.getElementById("ranking"),
};

const estado = {
  sessao: carregarSessao(),
  partida: null,
  linhaAtual: "",
  enviando: false,
};

function carregarSessao() {
  try {
    return JSON.parse(localStorage.getItem(CHAVE_SESSAO));
  } catch {
    return null;
  }
}

function salvarSessao(sessao) {
  estado.sessao = sessao;
  try {
    localStorage.setItem(CHAVE_SESSAO, JSON.stringify(sessao));
  } catch {
    return;
  }
}

function limparSessao() {
  estado.sessao = null;
  estado.partida = null;
  estado.linhaAtual = "";
  try {
    localStorage.removeItem(CHAVE_SESSAO);
  } catch {
    return;
  }
}

function mensagemDeErro(dados) {
  if (typeof dados.detail === "string") return dados.detail;
  if (Array.isArray(dados.detail)) return "Dados inválidos.";
  return "Não foi possível completar a ação.";
}

async function requisitar(caminho, { metodo = "GET", corpo } = {}) {
  const cabecalhos = { "Content-Type": "application/json" };
  if (estado.sessao) cabecalhos.Authorization = `Bearer ${estado.sessao.token}`;

  const resposta = await fetch(caminho, {
    method: metodo,
    headers: cabecalhos,
    body: corpo === undefined ? undefined : JSON.stringify(corpo),
  });
  const dados = await resposta.json().catch(() => ({}));

  if (resposta.status === 401) {
    sair();
    throw new Error("Sessão expirada. Entre novamente.");
  }
  if (!resposta.ok) throw new Error(mensagemDeErro(dados));
  return dados;
}

function mostrarMensagem(texto) {
  elementos.mensagem.textContent = texto;
}

function partidaEmAndamento() {
  return estado.partida !== null && estado.partida.status === "em_andamento";
}

function textoDoStatus(partida) {
  if (partida.status === "vencida") {
    const plural = partida.tentativas === 1 ? "tentativa" : "tentativas";
    return `Você acertou em ${partida.tentativas} ${plural}! Volte amanhã.`;
  }
  if (partida.status === "perdida") return "Não foi dessa vez. Volte amanhã para uma nova palavra.";
  return `${partida.tentativas_restantes} tentativas restantes.`;
}

function montarCelula(indiceLinha, indiceColuna) {
  const celula = document.createElement("div");
  celula.className = "celula";

  const palpite = estado.partida.palpites[indiceLinha];
  if (palpite) {
    const letra = palpite.letras[indiceColuna];
    celula.textContent = letra.letra;
    celula.classList.add(letra.estado);
    return celula;
  }

  if (indiceLinha !== estado.partida.palpites.length) return celula;
  celula.textContent = estado.linhaAtual[indiceColuna] ?? "";
  return celula;
}

function renderizarTabuleiro() {
  const linhas = [];
  for (let indiceLinha = 0; indiceLinha < MAXIMO_TENTATIVAS; indiceLinha += 1) {
    const linha = document.createElement("div");
    linha.className = "linha";
    for (let indiceColuna = 0; indiceColuna < TAMANHO; indiceColuna += 1) {
      linha.append(montarCelula(indiceLinha, indiceColuna));
    }
    linhas.push(linha);
  }
  elementos.tabuleiro.replaceChildren(...linhas);
}

function estadosDasTeclas() {
  const estados = {};
  for (const palpite of estado.partida.palpites) {
    for (const { letra, estado: estadoLetra } of palpite.letras) {
      const atual = estados[letra];
      if (atual && PRIORIDADE_ESTADO[atual] >= PRIORIDADE_ESTADO[estadoLetra]) continue;
      estados[letra] = estadoLetra;
    }
  }
  return estados;
}

function renderizarTeclado() {
  const estados = estadosDasTeclas();
  const fileiras = FILEIRAS_TECLADO.map((teclas) => {
    const fileira = document.createElement("div");
    fileira.className = "fileira";
    for (const tecla of teclas) {
      const botao = document.createElement("button");
      botao.type = "button";
      botao.className = "tecla";
      botao.dataset.tecla = tecla;
      botao.textContent = ROTULOS_TECLAS[tecla] ?? tecla;
      if (ROTULOS_TECLAS[tecla]) botao.classList.add("larga");
      if (estados[tecla]) botao.classList.add(estados[tecla]);
      fileira.append(botao);
    }
    return fileira;
  });
  elementos.teclado.replaceChildren(...fileiras);
}

function renderizarJogo() {
  renderizarTabuleiro();
  renderizarTeclado();
  mostrarMensagem(textoDoStatus(estado.partida));
}

function renderizarSessao() {
  const logado = estado.sessao !== null;
  elementos.telaEntrada.hidden = logado;
  elementos.telaJogo.hidden = !logado;
  elementos.painel.hidden = !logado;
  elementos.botaoSair.hidden = !logado;
  elementos.jogadorAtual.textContent = logado ? estado.sessao.apelido : "";
}

function formatarTaxa(taxa) {
  return `${Math.round(taxa * 100)}%`;
}

function formatarMedia(media) {
  if (media === null) return "–";
  return media.toFixed(1).replace(".", ",");
}

function renderizarEstatisticas(estatisticas) {
  const itens = [
    ["Jogos", estatisticas.partidas_jogadas],
    ["Vitórias", formatarTaxa(estatisticas.taxa_vitoria)],
    ["Média", formatarMedia(estatisticas.media_tentativas)],
    ["Sequência", estatisticas.sequencia_atual],
    ["Melhor", estatisticas.melhor_sequencia],
    ["Acertos", estatisticas.vitorias],
  ];
  const nos = itens.flatMap(([rotulo, valor]) => {
    const termo = document.createElement("dt");
    termo.textContent = rotulo;
    const descricao = document.createElement("dd");
    descricao.textContent = String(valor);
    const grupo = document.createElement("div");
    grupo.append(termo, descricao);
    return [grupo];
  });
  elementos.estatisticas.replaceChildren(...nos);
}

function renderizarRanking(linhas) {
  const nos = linhas.map((linha) => {
    const tr = document.createElement("tr");
    const valores = [
      linha.posicao,
      linha.apelido,
      linha.vitorias,
      formatarTaxa(linha.taxa_vitoria),
      formatarMedia(linha.media_tentativas),
    ];
    for (const valor of valores) {
      const td = document.createElement("td");
      td.textContent = String(valor);
      tr.append(td);
    }
    return tr;
  });
  elementos.ranking.replaceChildren(...nos);
}

async function atualizarPainel() {
  if (!estado.sessao) return;
  try {
    const apelido = encodeURIComponent(estado.sessao.apelido);
    const [estatisticas, ranking] = await Promise.all([
      requisitar(`/api/jogadores/${apelido}/estatisticas`),
      requisitar("/api/ranking"),
    ]);
    renderizarEstatisticas(estatisticas);
    renderizarRanking(ranking);
  } catch (erro) {
    mostrarMensagem(erro.message);
  }
}

async function iniciarJogo() {
  renderizarSessao();
  try {
    estado.partida = await requisitar("/api/partidas", { metodo: "POST" });
    estado.linhaAtual = "";
    renderizarJogo();
    await atualizarPainel();
  } catch (erro) {
    mostrarMensagem(erro.message);
  }
}

async function enviarPalpite() {
  if (estado.linhaAtual.length !== TAMANHO) {
    mostrarMensagem(`A palavra precisa ter ${TAMANHO} letras.`);
    return;
  }

  estado.enviando = true;
  try {
    const resultado = await requisitar(`/api/partidas/${estado.partida.id}/palpites`, {
      metodo: "POST",
      corpo: { palavra: estado.linhaAtual },
    });
    estado.partida.palpites.push(resultado.palpite);
    estado.partida.status = resultado.status;
    estado.partida.tentativas = resultado.tentativas;
    estado.partida.tentativas_restantes = resultado.tentativas_restantes;
    estado.linhaAtual = "";
    renderizarJogo();
    if (!partidaEmAndamento()) await atualizarPainel();
  } catch (erro) {
    mostrarMensagem(erro.message);
  } finally {
    estado.enviando = false;
  }
}

function tratarTecla(tecla) {
  if (!partidaEmAndamento() || estado.enviando) return;

  if (tecla === "ENTER") {
    enviarPalpite();
    return;
  }

  if (tecla === "BACKSPACE") {
    estado.linhaAtual = estado.linhaAtual.slice(0, -1);
    renderizarTabuleiro();
    return;
  }

  if (!/^[A-Z]$/.test(tecla)) return;
  if (estado.linhaAtual.length >= TAMANHO) return;
  estado.linhaAtual += tecla;
  renderizarTabuleiro();
}

function normalizarTecla(chave) {
  if (chave === "Enter") return "ENTER";
  if (chave === "Backspace") return "BACKSPACE";
  return chave.normalize("NFD").replace(/[̀-ͯ]/g, "").toUpperCase();
}

function sair() {
  limparSessao();
  renderizarSessao();
  mostrarMensagem("");
}

elementos.formEntrada.addEventListener("submit", async (evento) => {
  evento.preventDefault();
  try {
    const dados = await requisitar("/api/jogadores", {
      metodo: "POST",
      corpo: { apelido: elementos.campoApelido.value.trim() },
    });
    salvarSessao({ apelido: dados.apelido, token: dados.token });
    await iniciarJogo();
  } catch (erro) {
    alert(erro.message);
  }
});

elementos.botaoSair.addEventListener("click", sair);

elementos.teclado.addEventListener("click", (evento) => {
  const botao = evento.target.closest("[data-tecla]");
  if (!botao) return;
  tratarTecla(botao.dataset.tecla);
});

document.addEventListener("keydown", (evento) => {
  if (evento.ctrlKey || evento.metaKey || evento.altKey) return;
  if (evento.target instanceof HTMLInputElement) return;
  tratarTecla(normalizarTecla(evento.key));
});

renderizarSessao();
if (estado.sessao) iniciarJogo();
