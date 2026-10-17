# 04 — Referência visual da UI (MCHOSE HUB → Qt/QML)

Objetivo (decidido pelo usuário em 2026-10-16): a UI do port fica **o mais próxima possível do
MCHOSE HUB**, com atenção especial ao **editor de EQ**. Assets da MCHOSE (fotos, ícones da
iconfont, vídeos, presets oficiais) **não** são usados: ícones e ilustração do headset foram
desenhados para o projeto (opção "A" escolhida pelo usuário); a fonte MiSans é gratuita e o app
usa a fonte do sistema se ela não estiver instalada.

## Como a referência foi obtida **[obs]**

1. MCHOSE HUB reaberto com `--remote-debugging-port=9333 --remote-debugging-address=127.0.0.1`
   (os fuses do Electron permitem; o processo principal roda como admin, então o usuário precisa
   fechar o app pela bandeja antes).
2. A UI do headset é a página `customPage/prod` (Vue + Element Plus + ECharts) servida por
   `mchose-renderer://app/cdn.mchose.com.cn/customPage/prod/index.html`; a home é um iframe de
   `www.mchose.com.cn`.
3. Navegação e prints via CDP: `node tools/re/cdp.mjs <targetId> eval|shot|move`.
4. Estilos computados por classe: `node tools/re/cdp.mjs <id> eval "$(cat tools/re/styles.js)"`.
5. Opção do gráfico: instância ECharts do `.erp__chart` → `getOption()`. Código do editor:
   chunk `index-*.js` (componente `eqRoutineEditorPanel`), `hidEqChartOptions-*.js` e `eq-*.js`
   (baixados com `fetch` dentro da página; ficam só no scratchpad).

Prints do original e do port ficam no scratchpad da sessão (não vão para o repo).

## Tokens (tema escuro) **[obs]**

| Uso | Valor |
|---|---|
| Fundo da janela | `#0c0c0c` |
| Painel principal, linha selecionada da sidebar, painéis do EQ | `#141414`, raio 12 (painel) / 8 (linha) |
| Cards dentro do painel, cards de preset | `#1a1a1b`, raio 12, padding 24 (preset: raio 8, padding 20/16/16) |
| Linhas de modo, botões secundários | `#212121`, borda `#2f2f2f`, raio 8, altura 40 |
| Modo ativo | fundo `rgba(0,83,226,.1)`, borda `rgba(0,83,226,.4)`, triângulo azul 24×24 com check no canto |
| Tooltip / menus | `#303134`, raio 4, padding 16, sombra `0 6px 16px rgba(0,0,0,.18)` |
| Linhas de grade / divisórias | `#2b2b2b` |
| Slider | trilho 4 px `#414141`, barra `#226bee`, alça 16 px azul com borda branca 1 px (cresce 1.2× no hover) |
| Switch | 40×20, desligado `#606166`, ligado `#226bee`, bolinha 16 px, transição 150 ms |
| Texto | `#fff`; secundário `rgba(255,255,255,.5)` |
| Acento | `#226bee` |
| Fonte | MiSans; títulos 16/600, nome do device 26/700, corpo 14, descrições 13, rótulos 12 |
| Layout | barra superior 60 px; sidebar 320 px (linhas 40 px, gap 16, ícone 20); painel com margens de 24 |

Implementado em `app/qml/Theme.qml`.

## Editor de EQ **[obs]**

ECharts, série `line` única, `smooth: true` (= 0.5 com `smoothConstraint`), 10 pontos em
**eixo de categorias** (espaçamento igual; o original rotula 20Hz…20KHz, o port usa as fc
reais lidas do headset: 45/100/250/400/1k/2k/4k/6k/8k/12k). **Não** é a resposta de frequência
real dos filtros: a curva só liga os ganhos.

- Grid: `left 24, right 73, top 12, bottom 72`; o canvas fica 24 px à esquerda do conteúdo e 12 px
  acima, abaixo da faixa "Bass | Mid | High" (16 px, divisórias verticais, 12 px de margem).
- Eixo Y à direita, −12…+12, linhas a cada 3 dB (`#2b2b2b`), rótulos a cada 6 dB (`+12 dB`, `0 dB`).
- Linha de 0 dB: tracejado `[4]`, `dashOffset 4`, cor `#226bee` (é o eixo X com `onZero`).
- Curva 2 px `#226bee`; pontos círculo 16 px azul com borda branca 1 px; rótulo do valor
  abaixo de cada ponto (`+4.0`, distância 4, 12 px, branco 50%).
- **Área**: gradiente vertical recalculado a cada mudança: alfa 0.2 nos extremos e **0 exatamente
  na linha de 0 dB** (`offset = max / (max − min)`); só positivos → 0.2 em cima e 0 embaixo; só
  negativos → o inverso.
- Tooltip `trigger: item`: "+7.9 dB", à esquerda do ponto (16 px), vira para a direita se não
  couber, transição de 0.4 s.
- Interação (código `eqRoutineEditorPanel`): raio de acerto 12 px; arrastar define o ganho na
  posição Y do mouse (`convertFromPixel`, clamp −12…+12, arredonda 0.1); roda do mouse sobre um
  ponto = ±0.1 dB, sessão de 220 ms; histórico Back/Forward empilhado no início do gesto; envio
  ao device com debounce de 50 ms durante o arrasto.
- Atualizações animam 500 ms `cubicInOut` (morph da curva ao trocar modo/preset).
- Painel de presets (384 px): abas Official / Cloud Community / My; card 124 px com ícone, nome,
  sparkline 88×46 (traço branco 50%) e "Apply".

Implementado em `app/qml/EqChart.qml` (o algoritmo da curva está em `app/qml/eqpath.js`, porte
do `drawSmooth` do ECharts) e `app/qml/EqEditor.qml`. O que o port **não** traz: aba Cloud
Community, Share, "Preview" com vídeos de jogos e os presets oficiais (conteúdo da MCHOSE); no
lugar há presets próprios e "Meus presets" salvos em `QtCore.Settings`.

## Comparar o port com o original

`mchose-v9 --shot <pasta>` percorre Common, EQ, Playback, Mic e Other, salva um PNG de cada e
fecha (precisa do headset conectado).
