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

Fonte: chunk `eq-*.js` do shell `cdn.mchose.com.cn/customPage/prod` (baixado em 2026-10-16).
Inteiros de 16 bits são **big-endian**.

**Validado no hardware (Windows, 2026-10-16, `python -m v9pro2`)**: todas as leituras
(cmds 4, 5, 11, 12, 13, 14 e a consulta de versão) responderam como descrito. Exemplo real de
`GET_BATTERY_SLEEP`: `aa 01 01 03 00 01 0b 01 54 5d` → acordado, sem carregar, 84 %. As
respostas vêm com `flags = 1` (checksum ligado), mesmo com o pedido em `flags = 0`.
**Escritas validadas no hardware (Windows, 2026-10-19, `python -m v9pro2 --set`)**: cmds 33, 1
e 26. Os três respondem com ack Notify (`00 04`), mesmo `cmd`, `flags = 1`, payload = valor
gravado; a releitura confirma. Exemplos reais:
`>> aa 01 00 02 00 02 21 0b` → `<< aa 01 01 02 00 04 21 0b 2d` (prompt 11);
`>> aa 01 00 02 00 02 01 00` → `<< aa 01 01 02 00 04 01 00 06` (perfil 0);
`>> aa 01 00 03 00 02 1a 00 2d` → `<< aa 01 01 03 00 04 1a 00 2d 31` (45 min).
Todos os valores foram restaurados depois do teste.
A interface HID é a coleção de vendor `usage_page 0xff07 / usage 0x222`, interface 3, que
declara input e output de 63 bytes nos reports `0x55` e `0x4D`.

| cmd | Nome | cmdType | Payload enviado | Resposta (payload) |
|---|---|---|---|---|
| 1 | SET_EQ_MODE | Set | `[mode]` (0–2 = Game 1/2/3) | ack Notify: `[mode]` — **validado** |
| 4 | GET_EQ_STATE | Request | `[mode, sub]` — ver §4a | ver §4a |
| 5 | GET_EQ_MODE_DESC | Request | `[mode]` | `[mode, nome UTF-8…, 0]` |
| 11 | GET_BATTERY_SLEEP | Request | `[]` | `[sleepState, b]`: `sleepState == 0` → dormindo; `b` bit 7 = carregando, bits 0–6 = % bateria |
| 12 | GET_CURRENT_EQ_MODE | Request | `[]` | `[mode]` |
| 13 | GET_PROMPT_VOLUME | Request | `[]` | `[volume]` |
| 14 | GET_AUTO_SHUTDOWN | Request | `[]` | `[min_hi, min_lo]` — minutos ociosos; `0` = nunca |
| 16 | SET_PEQ_ALL | Set | **[?]** (constante declarada, sem uso) | — |
| 18 | (set PEQ gains) | Set | `[mode, n, (g_hi, g_lo)×n]`, `g = round(gain_dB × 10)` int16, −12…+12 dB | — |
| 24 | (set EQ mode name) | Set | `[mode, nome UTF-8 ≤ 54 bytes]` | — |
| 25 | (restaurar EQ padrão) | Set | `[mode]` | — |
| 26 | SET_AUTO_SHUTDOWN | Set | `[min_hi, min_lo]`; a UI oferece 15, 30, 45 e 0 (nunca) | ack Notify: igual ao cmd 14 — **validado** |
| 27 | FACTORY_RESET | Set | `[target]`: 1 = headset, 2 = dongle, 3 = ambos (a UI usa 3) | — **não usar** |
| 33 | SET_PROMPT_VOLUME | Set | `[volume]`, inteiro **1–16** | ack Notify: `[volume]` — **validado** |

- Requests de leitura são enviados com `check = false`; os Set usam o default do builder
  (`check = false`) **[obs]**.
- Set sem `waitAck` é só `sendReport`; com `waitAck` a UI espera um input report com
  `cmdType = Notify (00 04)` e o mesmo `cmd` **[obs]**. A UI espera ack em
  `SET_AUTO_SHUTDOWN`; nos demais manda sem esperar.
- `GET_BATTERY_SLEEP` (11) e a notificação `BatterySleep` (34) usam o mesmo parser **[obs]**.

### 4a. `GET_EQ_STATE` — sub-comandos **[obs]**

Payload `[mode, sub]`. A resposta começa com `[mode, sub, …]`:

| sub | Conteúdo da resposta (a partir do byte 2) |
|---|---|
| 255 ALL_POINTS | `totalGain` int16, `n`, byte de pacote (`total<<4 | atual`), depois `n` × 7 bytes: `fc` u16 Hz, `gain` int16 ×10, `q` u8 ×10, `type` u8, `enable` u8 |
| 254 ALL_FC | `n`, [byte de pacote], `n` × u16 |
| 253 ALL_GAIN | `n`, [byte de pacote], `n` × int16 ×10 |
| 252 ALL_Q | `n`, [byte de pacote], `n` × u8 ×10 |
| 251 ALL_TYPE | `n`, [byte de pacote], `n` × u8 |
| 250 ALL_ENABLE | `n`, [byte de pacote], `n` × u8 (1 = ligado) |
| 249 TOTAL_GAIN | `totalGain` int16 |
| 0–49 | um ponto: `totalGain` int16, `n`, byte de pacote, `fc`, `gain`, `q`, `type`, `enable` |

O "byte de pacote" só existe se a resposta tiver tamanho ≥ `4 + n × largura`; senão os dados
começam no byte 3 e há um único pacote **[obs]**.

**No hardware**, `ALL_POINTS` com 10 pontos chega em **2 pacotes** de 5 pontos cada, com o
byte 5 = `0x59` e `0x5A` **[obs]**. O parser da UI (`total = b>>4`, `atual = b&15`) não casa com
esses valores; leitura mais coerente **[inf]**: bits 7–4 = pontos neste pacote, 3–2 = total de
pacotes, 1–0 = pacote atual (1-based). Os pacotes podem chegar atrasados, misturados com a
resposta do pedido seguinte: casar por `[mode, sub]` e juntar até completar os `n` pontos.
Valores observados: `type = 0` em todos os pontos, `totalGain = 0`, fc 45/100/250/400/1k/2k/4k/
6k/8k/12k Hz.

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
- Resposta: payload `[0x80, d0, d1, d2, d3]` (o target vem no byte `cmd`). Se os 4 bytes forem
  dígitos ASCII a versão é a string; senão é o hex dos 4 bytes, **últimos 4 dígitos** **[obs]**.
  No hardware: dongle `00 00 00 33` → `"0033"`, headset `00 00 00 31` → `"0031"`.
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
   GET_CURRENT_EQ_MODE, GET_EQ_MODE_DESC, GET_EQ_STATE, GET_BATTERY_SLEEP, GET_PROMPT_VOLUME,
   GET_AUTO_SHUTDOWN e a consulta de versão; validar contra este doc.
2. No Windows: Wireshark + USBPcap enquanto troca o perfil de EQ no app → confirmar bytes.
3. Para OTA (fora do escopo por ora): o shell do CDN já foi obtido (ver
   [03](03-mapa-de-settings.md)); a tela `otherSetting` chama `electronAPI.otaDevice`, então o
   transporte fica no processo Electron; (b) analisar `G9OTA.dll` no Ghidra para ver o transporte.
