# Progresso do port

Última atualização: 2026-10-20 (sessão 5)

Alvo: **Fedora** (o notebook do usuário está no 44; o app já rodou lá). UI em inglês com opção de português (ver `CLAUDE.md`).

## Status por funcionalidade do escopo

| Funcionalidade | Mecanismo no Windows | Status | Onde está documentado |
|---|---|---|---|
| **EQ** (3 perfis onboard "Game 1/2/3", ganhos −12…+12 dB, nome) | HID report `0x55` | Leitura validada; **troca de perfil (1), ganhos (18) e nome (24) validados e no app** (testados pelo usuário); restaurar (25) pendente | [02 §4](02-protocolo-hid-v9-pro-2.md#4-comandos-de-eq--configuração-eq_hid_cmd-obs) |
| EQ de 10 bandas do PC | DSP no Windows (`osConfLib.dll`/APO) | Não portável direto; substituir por PipeWire/EasyEffects | [02 §6](02-protocolo-hid-v9-pro-2.md#6-dois-eqs-diferentes) |
| **Volume** (fone e mic, mudo) | Mixer do endpoint USB Audio do Windows | Linux: ALSA/PipeWire nativo; precisa de `linux/51-mchose-v9pro2.conf` (soft-mixer: a faixa em dB do firmware é errada) **[obs]**. **Sliders e mudo ligados no app** (`pw-dump` + `wpctl`); falta testar no Fedora | [03 §3](03-mapa-de-settings.md#3-cada-setting-onde-roda-e-como-portar) |
| **Notificação sonora** (volume do prompt) | HID `GET/SET_PROMPT_VOLUME` (13/33), 1–16 | **Leitura e escrita validadas**; no app (slider) | [02 §4](02-protocolo-hid-v9-pro-2.md#4-comandos-de-eq--configuração-eq_hid_cmd-obs) |
| **Microfone** / **Microphone settings** (nivelamento, clareza, AI NR, Magic Voice, Mic Listen) | DSP do runtime THX no Windows + "Ouvir este dispositivo" | Nada em HID. Linux: PipeWire filter-chain/EasyEffects + `pw-loopback` | [03 §3](03-mapa-de-settings.md#mic-settings) |
| **Playback settings** (brilho, virtual bass, volume inteligente, clareza de voz) | DSP do runtime THX no Windows | Nada em HID. Linux: PipeWire filter-chain/EasyEffects | [03 §3](03-mapa-de-settings.md#speaker-settings-playback) |
| **Other settings**: auto-desligamento | HID `GET/SET_AUTO_SHUTDOWN` (14/26), u16 minutos | **Leitura e escrita validadas**; no app (menu 15/30/45/nunca) | [02 §4](02-protocolo-hid-v9-pro-2.md#4-comandos-de-eq--configuração-eq_hid_cmd-obs) |
| **Other settings**: bateria / dormindo | HID `GET_BATTERY_SLEEP` (11) + notify 34 | **Leitura validada** | [02 §4](02-protocolo-hid-v9-pro-2.md#4-comandos-de-eq--configuração-eq_hid_cmd-obs) |
| **Other settings**: restaurar padrões | HID `FACTORY_RESET` (27) | Payload conhecido — **não usar** sem confirmação | [02 §4](02-protocolo-hid-v9-pro-2.md#4-comandos-de-eq--configuração-eq_hid_cmd-obs) |
| Versão de firmware (leitura) | HID `OtaRequest` + `0x80` | **Validado** (dongle `0033`, headset `0031`) | [02 §7a](02-protocolo-hid-v9-pro-2.md#7a-consulta-de-versão--via-hid-obs) |
| Gravação de firmware (OTA) | `G9OTA.dll`? / UI no CDN | **Não localizado** — fora do escopo por enquanto | [02 §7b](02-protocolo-hid-v9-pro-2.md#7b-gravação-do-firmware--não-localizada) |
| THX | — | **Fora do escopo** (o usuário não usa) | — |

## O que já foi feito

1. Setup: REA instalado (MCP `rea` no Claude Code), repositório criado, remote SSH.
2. Análise do `app.asar`: o app é um Electron cujo main está em bytecode V8; a UI é um site
   remoto que fala com o hardware por **WebHID**. → [01](01-analise-inicial.md)
3. Recuperação da UI completa do cache do Electron e extração do protocolo HID do V9 Pro 2
   (formato do pacote, comandos de EQ, consulta de versão). → [02](02-protocolo-hid-v9-pro-2.md)
4. Shell `customPage/prod` baixado do CDN: payloads de notificação sonora, auto-desligamento,
   bateria, reset e sub-comandos do `GET_EQ_STATE`; mapa de cada setting entre HID, mixer do
   Windows e DSP THX. → [03](03-mapa-de-settings.md)
6. **UI refeita para ficar igual ao MCHOSE HUB** (sessão 3): prints e estilos computados do app
   original via CDP, opção do ECharts e código do editor de EQ → tokens em `Theme.qml`,
   sidebar/painel, telas Common/Playback/Mic/Other e editor de EQ com a mesma mecânica (curva
   suave do ECharts, gradiente que zera em 0 dB, arrasto, roda ±0,1 dB, desfazer/refazer, morph,
   presets com sparkline). Ícones e ilustração próprios. → [04](04-referencia-visual.md)
7. **Primeiras escritas** (sessão 4, 2026-10-19): o usuário rodou a UI no Fedora 44 com sucesso.
   Validados no hardware (Windows) os Set de prompt volume (33), perfil de EQ (1) e
   auto-desligamento (26), com ack Notify e releitura; valores restaurados. Ligados no app:
   slider da notificação (com debounce), clique na linha do modo de som, menu do desligamento.
   `python -m v9pro2 --set …` para testes pela linha de comando.
   Ganhos do EQ (18) validados (sem ack; conferido relendo) e ligados ao editor: grava sozinho
   400 ms depois que a curva para e ativa o perfil editado, como o app oficial. Os controles do
   app não foram clicados nos testes (o caminho HID é o mesmo do CLI validado).
8. **Nome do perfil** (sessão 5, 2026-10-20): o usuário testou o app e confirmou que o editor
   de EQ e o "Restaurar padrão" (curva plana) funcionam; faltava renomear. Cmd 24 validado no
   hardware pelo CLI (`--set eq-name M:NOME`, sem ack, conferido relendo o cmd 5; nome
   restaurado). No app: lápis ao lado do nome no cabeçalho do editor, edição inline (Enter grava,
   Esc cancela), corte em 54 bytes UTF-8 no Rust.
9. **Volume e microfone** (sessão 5): o usuário confirmou o renomear no Fedora. Sliders
   Volume/Microfone ligados ao PipeWire (`app/src/mixer.rs`): acha os nós do headset no
   `pw-dump` (`node.name` com `MCHOSE_V9_Pro_2`, `Audio/Sink` e `Audio/Source`), lê e grava com
   `wpctl get-volume`/`set-volume` (mesma escala em % do applet do KDE, limitado a 100 %),
   clique no ícone alterna o mudo. Relê a cada 1,5 s com a janela ativa para acompanhar
   mudanças feitas fora do app. A saturação em 15–20 % foi resolvida antes com
   `linux/51-mchose-v9pro2.conf` + `PCM` em 100 % **[obs]**.
5. Ferramenta de leitura `python -m v9pro2` (hidapi; `hidraw` no Linux) validada no hardware
   pelo Windows, com o MCHOSE HUB aberto. Testes do protocolo com bytes reais em `tests/`.

## Pendências (em ordem)

1. Testar no Fedora os sliders Volume/Microfone e o mudo (clique no ícone), inclusive se
   acompanham o volume mudado pelo applet do KDE. Renomear perfil, editor de EQ e "Restaurar
   padrão" já confirmados pelo usuário; falta confirmar slider da notificação, troca de modo e
   menu do desligamento.
2. Restaurar EQ de fábrica (25), com confirmação. Hoje "Restaurar padrão" no editor grava tudo
   em 0 dB (plano), não o EQ de fábrica do perfil.
3. Bandeja (`ksni`) e serviço em segundo plano.
4. Presets PipeWire para os efeitos THX (playback e mic) e loopback para Mic Listen.

Ambiente pronto no Windows: Rust 1.99.1, VS Build Tools 2022, Qt 6.10.3 em `C:\Qt`. O
`hidapi` do Python não fica instalado: criar um venv no scratchpad
(`pip install hidapi==0.14.0.post4`).

## Decisões

- **2026-10-16 — Stack do app: Rust + Qt 6/QML (CXX-Qt).** Alternativas avaliadas: Slint
  (mais leve, menos integrado ao KDE), Qt/QML em C++ (padrão do KDE, mas o usuário prefere
  Rust), PySide6 (pesado), Tauri (WebKitGTK no Linux), GTK4/libadwaita (cara de GNOME), Flutter.
  Motivos: integração com o KDE Plasma (o Qt é a base dele), interface própria com animações em
  placa de vídeo, Rust no backend. Integrações KDE planejadas: bandeja (StatusNotifierItem, ex.
  crate `ksni`), notificações freedesktop, configuração em `~/.config`. Mecanismo de i18n
  com troca de idioma em tempo de execução: **[?]** a definir no esqueleto (`QTranslator` +
  `retranslate()` ou tradução do lado Rust).

- Não redistribuir código, DLLs ou firmware da MCHOSE no repositório — só documentar o
  protocolo e reimplementar.
- Nenhum comando de escrita/OTA no hardware antes de validar as leituras.
