# Progresso do port

Última atualização: 2026-10-16 (sessão 2)

Alvo: **Fedora 43**. UI em inglês com opção de português (ver `CLAUDE.md`).

## Status por funcionalidade do escopo

| Funcionalidade | Mecanismo no Windows | Status | Onde está documentado |
|---|---|---|---|
| **EQ** (3 perfis onboard "Game 1/2/3", ganhos −12…+12 dB, nome) | HID report `0x55` | **Leitura validada no hardware** (Windows); escrita não testada | [02 §4](02-protocolo-hid-v9-pro-2.md#4-comandos-de-eq--configuração-eq_hid_cmd-obs) |
| EQ de 10 bandas do PC | DSP no Windows (`osConfLib.dll`/APO) | Não portável direto; substituir por PipeWire/EasyEffects | [02 §6](02-protocolo-hid-v9-pro-2.md#6-dois-eqs-diferentes) |
| **Volume** (fone e mic, mudo) | Mixer do endpoint USB Audio do Windows | Linux: ALSA/PipeWire nativo, sem código próprio **[inf]** | [03 §3](03-mapa-de-settings.md#3-cada-setting-onde-roda-e-como-portar) |
| **Notificação sonora** (volume do prompt) | HID `GET/SET_PROMPT_VOLUME` (13/33), 1–16 | **Leitura validada**; escrita não testada | [02 §4](02-protocolo-hid-v9-pro-2.md#4-comandos-de-eq--configuração-eq_hid_cmd-obs) |
| **Microfone** / **Microphone settings** (nivelamento, clareza, AI NR, Magic Voice, Mic Listen) | DSP do runtime THX no Windows + "Ouvir este dispositivo" | Nada em HID. Linux: PipeWire filter-chain/EasyEffects + `pw-loopback` | [03 §3](03-mapa-de-settings.md#mic-settings) |
| **Playback settings** (brilho, virtual bass, volume inteligente, clareza de voz) | DSP do runtime THX no Windows | Nada em HID. Linux: PipeWire filter-chain/EasyEffects | [03 §3](03-mapa-de-settings.md#speaker-settings-playback) |
| **Other settings**: auto-desligamento | HID `GET/SET_AUTO_SHUTDOWN` (14/26), u16 minutos | **Leitura validada**; escrita não testada | [02 §4](02-protocolo-hid-v9-pro-2.md#4-comandos-de-eq--configuração-eq_hid_cmd-obs) |
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
5. Ferramenta de leitura `python -m v9pro2` (hidapi; `hidraw` no Linux) validada no hardware
   pelo Windows, com o MCHOSE HUB aberto. Testes do protocolo com bytes reais em `tests/`.

## Pendências (em ordem)

1. **Rodar `python -m v9pro2` no Fedora 43** (ver `linux/README.md`): regra udev, módulo
   `hidraw`, conferir que a saída bate com a do Windows.
2. Comandos de escrita (Set) com confirmação do usuário a cada um, começando pelos reversíveis:
   prompt volume (33) e trocar perfil de EQ (1); depois auto-desligamento (26) e ganhos (18).
3. ~~Instalar o ambiente~~ feito no Windows (Rust 1.99.1, VS Build Tools 2022, Qt 6.10.3 em
   `C:\Qt`, `QMAKE` no ambiente do usuário). Esqueleto pronto: `crates/protocol` (9 testes) e
   `app/` (CXX-Qt 0.10 + QML, leitura funcionando no hardware, en/pt-BR em `app/i18n/`).
   Pendente: arco da bateria com artefato amarelo no início; salvar idioma escolhido; testar no
   Fedora; bandeja (`ksni`). Original: Instalar o ambiente (Rust, MSVC Build Tools e Qt 6 no Windows; Rust e Qt 6 devel no Fedora)
   e montar o esqueleto: workspace Cargo com crate `protocol` (porte do `v9pro2/protocol.py`
   + testes com bytes reais) e app CXX-Qt/QML só de leitura, com i18n en/pt-BR.
4. Presets PipeWire para os efeitos THX (playback e mic) e loopback para Mic Listen.

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
