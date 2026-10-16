# Progresso do port

Última atualização: 2026-10-16

## Status por funcionalidade do escopo

| Funcionalidade | Mecanismo no Windows | Status | Onde está documentado |
|---|---|---|---|
| **EQ** (3 perfis onboard "Game 1/2/3", ganhos −12…+12 dB, nome) | HID report `0x55` | Protocolo lido no código, **não testado no hardware** | [02 §4](02-protocolo-hid-v9-pro-2.md#4-comandos-de-eq--configuração-eq_hid_cmd-obs) |
| EQ de 10 bandas do PC | DSP no Windows (`osConfLib.dll`/APO) | Não portável direto; substituir por PipeWire/EasyEffects | [02 §6](02-protocolo-hid-v9-pro-2.md#6-dois-eqs-diferentes) |
| **Volume** | Provável: volume padrão do USB Audio (driver Microsoft) | A investigar | [01 §2](01-analise-inicial.md#2-dispositivo-do-usuário) |
| **Notificação sonora** | HID: `GET_PROMPT_VOLUME`(13) / `SET_PROMPT_VOLUME`(33); notify `VoiceBroadcast`(2) | cmd conhecido, **payload desconhecido** | [02 §4–5](02-protocolo-hid-v9-pro-2.md) |
| **Microfone** / **Microphone settings** | Mistura: HID **[?]** e DSP do Windows (AI Noise Reduction, Magic Voice, Mic Listen) | A investigar | [01 §4](01-analise-inicial.md#4-portar-o-driver) |
| **Playback settings** | Provável DSP do Windows (Virtual Bass, Voice Clarity, surround…) + possivelmente HID | A investigar | [01 §4](01-analise-inicial.md#4-portar-o-driver) |
| **Other settings** | HID: `GET/SET_AUTO_SHUTDOWN`(14/26), `GET_BATTERY_SLEEP`(11), `FACTORY_RESET`(27) | cmd conhecido, **payload desconhecido** | [02 §4](02-protocolo-hid-v9-pro-2.md#4-comandos-de-eq--configuração-eq_hid_cmd-obs) |
| Versão de firmware (leitura) | HID `OtaRequest` + `0x80` | Protocolo lido, não testado | [02 §7a](02-protocolo-hid-v9-pro-2.md#7a-consulta-de-versão--via-hid-obs) |
| Gravação de firmware (OTA) | `G9OTA.dll`? / UI no CDN | **Não localizado** — fora do escopo por enquanto | [02 §7b](02-protocolo-hid-v9-pro-2.md#7b-gravação-do-firmware--não-localizada) |
| THX | — | **Fora do escopo** (o usuário não usa) | — |

## O que já foi feito

1. Setup: REA instalado (MCP `rea` no Claude Code), repositório criado, remote SSH.
2. Análise do `app.asar`: o app é um Electron cujo main está em bytecode V8; a UI é um site
   remoto que fala com o hardware por **WebHID**. → [01](01-analise-inicial.md)
3. Recuperação da UI completa do cache do Electron e extração do protocolo HID do V9 Pro 2
   (formato do pacote, comandos de EQ, consulta de versão). → [02](02-protocolo-hid-v9-pro-2.md)

## Pendências (em ordem)

1. **Achar o código das telas de settings do headset** (prompt volume, mic, playback, other):
   a página `/headset/audio_routine` vem do shell `cdn.mchose.com.cn/customPage/prod`, que não
   estava no cache e o CDN não respondeu desta rede. Opções:
   - abrir no app cada aba de settings do V9 Pro 2 e depois re-extrair o cache
     (ver [HANDOFF](../HANDOFF.md#como-reextrair-o-cache-do-app));
   - capturar USB com Wireshark + USBPcap enquanto mexe em cada setting.
2. Separar, para cada setting, o que é **HID (no headset, portável)** e o que é **DSP do Windows**
   (substituir por PipeWire).
3. Ferramenta Linux **somente leitura** (hidraw) para validar o protocolo no hardware.
4. Só depois: comandos de escrita (Set), começando pelo EQ onboard.

## Decisões

- Não redistribuir código, DLLs ou firmware da MCHOSE no repositório — só documentar o
  protocolo e reimplementar.
- Nenhum comando de escrita/OTA no hardware antes de validar as leituras.
