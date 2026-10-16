# Progresso do port

Última atualização: 2026-10-16 (sessão 2)

## Status por funcionalidade do escopo

| Funcionalidade | Mecanismo no Windows | Status | Onde está documentado |
|---|---|---|---|
| **EQ** (3 perfis onboard "Game 1/2/3", ganhos −12…+12 dB, nome) | HID report `0x55` | Protocolo lido no código, **não testado no hardware** | [02 §4](02-protocolo-hid-v9-pro-2.md#4-comandos-de-eq--configuração-eq_hid_cmd-obs) |
| EQ de 10 bandas do PC | DSP no Windows (`osConfLib.dll`/APO) | Não portável direto; substituir por PipeWire/EasyEffects | [02 §6](02-protocolo-hid-v9-pro-2.md#6-dois-eqs-diferentes) |
| **Volume** (fone e mic, mudo) | Mixer do endpoint USB Audio do Windows | Linux: ALSA/PipeWire nativo, sem código próprio **[inf]** | [03 §3](03-mapa-de-settings.md#3-cada-setting-onde-roda-e-como-portar) |
| **Notificação sonora** (volume do prompt) | HID `GET/SET_PROMPT_VOLUME` (13/33), 1–16 | Payload conhecido, **não testado** | [02 §4](02-protocolo-hid-v9-pro-2.md#4-comandos-de-eq--configuração-eq_hid_cmd-obs) |
| **Microfone** / **Microphone settings** (nivelamento, clareza, AI NR, Magic Voice, Mic Listen) | DSP do runtime THX no Windows + "Ouvir este dispositivo" | Nada em HID. Linux: PipeWire filter-chain/EasyEffects + `pw-loopback` | [03 §3](03-mapa-de-settings.md#mic-settings) |
| **Playback settings** (brilho, virtual bass, volume inteligente, clareza de voz) | DSP do runtime THX no Windows | Nada em HID. Linux: PipeWire filter-chain/EasyEffects | [03 §3](03-mapa-de-settings.md#speaker-settings-playback) |
| **Other settings**: auto-desligamento | HID `GET/SET_AUTO_SHUTDOWN` (14/26), u16 minutos | Payload conhecido, **não testado** | [02 §4](02-protocolo-hid-v9-pro-2.md#4-comandos-de-eq--configuração-eq_hid_cmd-obs) |
| **Other settings**: bateria / dormindo | HID `GET_BATTERY_SLEEP` (11) + notify 34 | Payload conhecido, **não testado** | [02 §4](02-protocolo-hid-v9-pro-2.md#4-comandos-de-eq--configuração-eq_hid_cmd-obs) |
| **Other settings**: restaurar padrões | HID `FACTORY_RESET` (27) | Payload conhecido — **não usar** sem confirmação | [02 §4](02-protocolo-hid-v9-pro-2.md#4-comandos-de-eq--configuração-eq_hid_cmd-obs) |
| Versão de firmware (leitura) | HID `OtaRequest` + `0x80` | Protocolo lido, não testado | [02 §7a](02-protocolo-hid-v9-pro-2.md#7a-consulta-de-versão--via-hid-obs) |
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

## Pendências (em ordem)

1. **Ferramenta Linux somente leitura** (`hidraw`, em `tools/`): GET_CURRENT_EQ_MODE,
   GET_EQ_MODE_DESC, GET_EQ_STATE, GET_BATTERY_SLEEP, GET_PROMPT_VOLUME, GET_AUTO_SHUTDOWN e
   versão. Definir onde testar (máquina Linux nativa ou live USB; WSL não serve bem para HID).
   Alternativa já no Windows: mesmo script com `hidapi` (o app MCHOSE fechado).
2. Opcional: capturar com Wireshark + USBPcap uma troca de setting no app para conferir bytes.
3. Comandos de escrita (Set), começando pelo EQ onboard e prompt volume — só após validar 1.
4. Presets PipeWire para os efeitos THX (playback e mic) e loopback para Mic Listen.

## Decisões

- Não redistribuir código, DLLs ou firmware da MCHOSE no repositório — só documentar o
  protocolo e reimplementar.
- Nenhum comando de escrita/OTA no hardware antes de validar as leituras.
