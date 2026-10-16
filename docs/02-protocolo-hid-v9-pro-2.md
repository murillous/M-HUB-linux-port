# Protocolo HID — MCHOSE V9 Pro 2 (passo 1)

Fontes analisadas (estática, nada executado):
- SPA `https://www.mchose.com.cn/` baixado em 2026-10-16 (Vue/Vite).
- Versão mais completa do mesmo SPA recuperada do cache HTTP do Electron
  (`%APPDATA%\MCHOSEHUB\Cache\Cache_Data`, corpos brotli): chunk `theme-IdBKOUK0.js`
  (strings ofuscadas, chave `mchose_secret_2024`, mas a lógica de protocolo está em claro) e o
  chunk com o serviço `device:service:audio:*`.

Legenda: **[obs]** lido no código · **[inf]** inferência · **[?]** desconhecido.

## 1. Arquitetura confirmada

- A UI conversa com os periféricos **direto por WebHID** (`navigator.hid`, `device.sendReport`,
  evento `inputreport`) **[obs]**. O Electron só concede a permissão de dispositivo.
- Consequência para o port: o protocolo é reimplementável no Linux via `hidraw`
  (ex.: `node-hid`, `hidapi`, Python `hid`) **[inf]**.

## 2. Identificação do dispositivo

| | VID | PID | Observação |
|---|---|---|---|
| V9 Pro 2 com fio | `0x3837` (14391) | `0x6010` (24592) | **[obs]** |
| V9 Pro 2 sem fio (dongle) | `0x3837` | `0x6011` (24593) | **[obs]** — é o que está conectado no PC do usuário |

ProductKey usado pela UI: `"MCHOSE V9 PRO 2$$$14391$$$24593"` **[obs]**.
Também usa o mesmo serviço de EQ: `MCHOSE R9` (PID 24595) **[obs]**.

## 3. Formato do pacote (output report)

- **Report ID: `0x55` (85)** **[obs]** (`V9pro2ReportId = 85`).
- Tamanho do report data: **63 bytes**, zero-padded **[obs]**.

| Offset | Campo | Valor |
|---|---|---|
| 0 | start | `0xAA` (170) |
| 1 | version | `0x01` |
| 2 | flags | `1` se checksum habilitado, senão `0` |
| 3 | length | `len(payload) + 1` (inclui o byte `cmd`) |
| 4–5 | cmdType | 2 bytes (tabela abaixo) |
| 6 | cmd | comando |
| 7… | payload | bytes do comando |
| 7+len(payload) | checksum | XOR de `flags ^ length ^ cmdType[0] ^ cmdType[1] ^ cmd ^ payload…` se `flags=1`, senão `0` |

`cmdType` **[obs]**:

| Nome | Bytes |
|---|---|
| Request | `00 01` |
| Response | `00 01` |
| Set | `00 02` |
| UpImg / UpImgResponse | `00 03` |
| Notify | `00 04` |
| OtaRequest | `00 06` |

Respostas chegam como input report com o mesmo report ID; a UI casa a resposta comparando os
bytes a partir do offset 4 com `[...cmdType, cmd]` e timeout de 3 s **[obs]**.
Payload da resposta = `bytes[7 .. 7 + length - 1)` **[obs]**.

## 4. Comandos de EQ / configuração (`EQ_HID_CMD`) **[obs]**

| cmd | Nome | cmdType | Payload |
|---|---|---|---|
| 1 | SET_EQ_MODE | Set | `[mode]` (0–2 = Game 1/2/3) |
| 4 | GET_EQ_STATE | Request | — |
| 5 | GET_EQ_MODE_DESC | Request | `[mode]` → resposta `[mode, nome UTF-8…, 0]` |
| 11 | GET_BATTERY_SLEEP | Request | **[?]** |
| 12 | GET_CURRENT_EQ_MODE | Request | `[]` → `[mode]` |
| 13 | GET_PROMPT_VOLUME | Request | **[?]** |
| 14 | GET_AUTO_SHUTDOWN | Request | **[?]** |
| 16 | SET_PEQ_ALL | Set | **[?]** (constante declarada) |
| 18 | (set PEQ gains) | Set | `[mode, n, (g_hi, g_lo)×n]`, `g = round(gain_dB × 10)` int16 big-endian, gain em −12…+12 dB |
| 24 | (set EQ mode name) | Set | `[mode, nome UTF-8 ≤ 54 bytes]` |
| 26 | SET_AUTO_SHUTDOWN | Set | **[?]** |
| 27 | FACTORY_RESET | Set | **[?]** — não usar sem necessidade |
| 33 | SET_PROMPT_VOLUME | Set | **[?]** |

Requests de leitura são enviados com `check = false`; os Set usam o default do builder
(`check = false`) **[obs]**.

## 5. Notificações do dispositivo (cmdType `00 04`) **[obs]**

Tabela compartilhada entre produtos (muitas são de teclados com tela). Relevantes para headset:
`EqMode = 1` (payload `[mode]`), `VoiceBroadcast = 2`, `BatterySleep = 34`.

## 6. Dois "EQs" diferentes

1. **EQ onboard (no headset)** — HID, comandos acima, 3 perfis "Game 1/2/3" com nome editável.
   **Portável.** **[obs]**
2. **EQ de 10 bandas do PC + efeitos** (`setEQ_Slider`, `setEnable_EQ_GFX`, Xear, Virtual Bass…)
   — vão para `audioRuntimeSet` → processo Electron → `osConfLib.dll` / THX
   (`V9_PRO_2_THX_PRODUCT_ID = "mchose_v9pro2"`) **[obs]**. É DSP no Windows **[inf]**.
   **No Linux: substituir por PipeWire `filter-chain` / EasyEffects.**

## 7. Firmware / OTA

### 7a. Consulta de versão — via HID **[obs]**
- Pacote: `cmdType = OtaRequest (00 06)`, `cmd = target` (`0` = headset, `1` = dongle),
  `payload = [0x80]` (QUERY), `check = false`, report ID `0x55`.
- Resposta: payload `[target?, 0x80, d0, d1, d2, d3]`; se os 4 bytes forem dígitos ASCII a versão
  é a string (ex. `"0012"`), senão hex dos bytes **[obs]**.
- Para PID `0x6011` a UI consulta dongle (target 1) e headset (target 0, com 1 retry após 1,5 s)
  **[obs]**.

### 7b. Gravação do firmware — **[?] ainda não localizada**
- O manifesto de versões é `https://cdn.mchose.com.cn/OTA/PC/prod/otaFile/otaConfigApp_prod.json`
  **[obs]** (CDN inacessível desta rede no momento da análise).
- A tela de upgrade de headset fica no shell externo (`cdn.mchose.com.cn/customPage/prod`,
  rota `/headset/audio_routine?isGoUpgradePage`) **[obs]**, que não estava no cache.
- Candidato forte: `G9OTA.dll` via IPC `otaDevice` — o worker tem modos `headset`/`dongle` e
  callbacks `on_need_reconnect`, o que casa com `DEVICE=0 / DONGLE=1` da UI **[inf]**.
- Alternativa: chunk lazy da UI usando `OtaRequest` com outros sub-comandos além de `0x80` **[inf]**.

## 8. Próximos passos

1. Ferramenta Linux **somente leitura** (sem Set): abrir `hidraw` do `3837:6011`, mandar
   GET_CURRENT_EQ_MODE, GET_EQ_MODE_DESC e a consulta de versão; validar contra este doc.
2. No Windows: Wireshark + USBPcap enquanto troca o perfil de EQ no app → confirmar bytes.
3. Para OTA: (a) obter o shell do CDN por outra rede/VPN ou extrair do cache após abrir a tela
   de upgrade no app; (b) analisar `G9OTA.dll` no Ghidra para ver o transporte.
