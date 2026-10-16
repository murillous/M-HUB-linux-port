# Análise inicial do MCHOSE HUB (Windows)

Alvo: `C:\Program Files\MCHOSE HUB\` — `resources/app.asar`
(sha256 `bdbc014c3d7a4a3fecb72a6c244f58755da69ae881d2b5f43d5058e27341ab71`).
Análise estática; nada do app foi executado.

Legenda: **[obs]** observado nos arquivos · **[inf]** inferência · **[?]** desconhecido.

## 1. Arquitetura

| Camada | O que é | Portabilidade |
|---|---|---|
| Shell Electron | `out/main/index.js` → carrega `index.jsc` (bytecode V8, ~900 KB) | Código fonte não legível; só strings **[obs]** |
| Preload | `out/preload/index.js` (JS legível) expõe `window.electronAPI` com ~220 métodos via IPC **[obs]** | Contrato de API reaproveitável |
| UI | **Site remoto** carregado na janela: produção `https://www.mchose.com.cn/` (+ `tray.html`), ambientes de teste em IPs internos e `drivertest.maicong.cn` **[obs]** | A UI não está no instalador **[obs]** |
| Nativo (via `koffi` FFI) | `libs/osConfLib.dll`, `libs/DLL/*.dll`, `libs/THX/*` **[obs]** | Windows-only |
| Node nativo | `usb` (libusb), `audify`, `win-audio`, `koffi` **[obs]** | `usb`/`audify` existem p/ Linux; `win-audio` não |

- O main process registra `setDevicePermissionHandler` **[obs]**, e o preload **não** expõe
  nenhuma função de enviar/receber dados para periféricos **[obs]**. **[inf]** A UI remota
  conversa com teclados/mouses/headsets diretamente por **WebHID** (`navigator.hid`) no Chromium.
  Isso precisa ser confirmado analisando o JS do site remoto.
- Análise REA (Evidence `ev_2f50d03d…`): 234 canais IPC literais no preload, apenas 8 handlers
  visíveis no main — os demais estão dentro do bytecode **[obs]**.

## 2. Dispositivo do usuário

`MCHOSE V9 Pro 2` — `VID_3837&PID_6011` **[obs]**
- `MI_00`: áudio USB, driver **Microsoft inbox** (`wdma_usb.inf` / `usbaudio`) **[obs]** → no Linux,
  `snd-usb-audio` padrão **[inf]**.
- `MI_03`: HID com coleções consumer control, headset e **vendor-defined (COL03)** **[obs]** →
  canal provável de configuração/OTA **[inf]**, acessível no Linux via `hidraw`.

## 3. Atualização de firmware (OTA)

Três caminhos distintos:

### 3a. K20 PRO — SDK JieLi "UFW" (`K20ProOTA.dll`, `workerUpgrade-C_6lLcOQ`) **[obs]**
- Funções: `JL_loadUfwData`, `JL_getUfwCrc`, `JL_getUfwPidVid`, `JL_upgradeDevice(ByPath)`,
  `JL_addPcModeName`, `JL_queryDevicePidVid`… ; strings `\\.\physicaldrive`, `BR28UBOOT1.00`.
- **[inf]** Chip JieLi família BR28. O dispositivo entra em "PC mode" e aparece como **disco USB
  (mass storage)**; a DLL grava o `.ufw` por comandos SCSI no disco físico. No Linux isso vira
  `/dev/sdX` + `SG_IO` — portável, mas o protocolo SCSI da JieLi precisa ser decompilado
  (Ghidra) ou capturado (USBPcap).

### 3b. Headset/dongle sem fio — `G9OTA.dll` (`workerUpgrade-CqmYWMC5`, `workerGetDevice-DRORZm5u`) **[obs]**
- API: `CreateExecutorHandle`, `runAllTask`, `ota_update_client`, `ota_update_dongle`,
  `ota_update_dongle_single_post`, `read_online_device`; callbacks `on_progress`,
  `on_need_reconnect`, `on_finish_ota`… ; dongle `vid_3837&pid_6089`.
- Modos `headset` e `dongle` **[obs]**. Transporte interno da DLL **[?]** (provável HID).

### 3c. Demais dispositivos (incluindo, provavelmente, o V9 Pro 2) **[?]**
- Nada no app local liga `PID_6011` a uma DLL de OTA. **[inf]** OTA feito pela UI remota via
  WebHID, com o binário obtido de `getFirmwareBinData` / CDN.

## 4. "Portar o driver"

- **Não há driver de kernel proprietário para o V9 Pro 2**: áudio usa o driver da Microsoft **[obs]**.
- O que é Windows-only são os **efeitos de software** expostos no preload (EQ, Xear Surround,
  Virtual Bass, Voice Clarity, AI Noise Reduction, Magic Voice, Adaptive Volume) via
  `osConfLib.dll` (`PropertyControl`, `ConfLibInitWithGUID`) e THX **[obs]**. Os sufixos
  `_LFX`/`_GFX` são nomenclatura de **APO** do Windows **[inf]** — DSP no PC, não no headset.
  No Linux o equivalente seria PipeWire `filter-chain` / EasyEffects.
- `MicListen`, `WindowMonitor`, `smtc_monitor`, `wyy` = integrações de SO (ouvir microfone,
  app em foco, mídia tocando, NetEase Music) **[obs pelos exports]**.

## 5. Próximos passos

1. Baixar e analisar o JS da UI remota (`www.mchose.com.cn`) com REA → achar o código WebHID
   (report IDs, comandos, fluxo de OTA do V9 Pro 2).
2. Capturar tráfego USB com Wireshark + USBPcap enquanto altera configurações no app → validar
   comandos HID.
3. Dump do HID report descriptor do `MI_03` (Linux: `/sys/class/hidraw/*/device/report_descriptor`).
4. Protótipo Linux: regra udev para `hidraw` + script que envia um comando inofensivo (ex.: ler
   versão de firmware). **OTA só depois** de entender o protocolo inteiro — risco de brick.
