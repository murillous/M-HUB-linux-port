# Mapa das telas de settings do V9 Pro 2

Fonte: shell `https://cdn.mchose.com.cn/customPage/prod/index.html` e seus chunks `assets/*.js`,
baixados em 2026-10-16 com `tools/re/crawl.py` (o CDN voltou a responder; a raiz
`customPage/prod/` dá 404, é preciso pedir o `index.html`).

Legenda: **[obs]** lido no código · **[inf]** inferência · **[?]** desconhecido.

## 1. Configuração do produto **[obs]**

```
"MCHOSE V9 PRO 2": { wiredKey: "wireless", audioRuntimeType: THX,
  THXConfig: { productId: "mchose_v9pro2", hwid: "VID_3837&PID_6011&MI_00" },
  isNewLayout: true }
```

- `isNewLayout: true` → a UI usa o protocolo HID novo (report `0x55`, doc
  [02](02-protocolo-hid-v9-pro-2.md)) para notificação sonora, auto-desligamento e reset.
- `audioRuntimeType: THX` → **todos os efeitos de áudio de playback e de microfone desta tela
  rodam no runtime THX do Windows** (serviço `thx_mchose_v9pro2_svc.exe`, chamado via IPC
  `audioRuntimeSet/Get`). Não ficam no headset. Ou seja: mesmo sem usar o "THX Spatial", os
  efeitos dependem do THX no Windows **[obs]**.

## 2. Menu do headset (new layout) **[obs]**

| Menu | Rota | Chunk |
|---|---|---|
| Common Params | `/headset/audio_routine` | `index-*.js` (componente `routineCommonParams`) |
| Speaker Settings (playback) | `/headset/audio_speaker` | `index-*.js` (`brightened`, `lowFrequency`, `smartVolume`, `vocalsClarity`) |
| Mic Settings | `/headset/audio_mic` | `index-*.js` (`micLeveling`, `micClarity`, `micNoiseReduction`, `micListen`) |
| THX Surround | `/headset/audio_surround_thx` | fora do escopo |
| Other Settings | `/headset/otherSetting` | `index-*.js` |

## 3. Cada setting: onde roda e como portar

Mecanismos:
- **HID** — comando no headset, doc 02. Portável via `hidraw`.
- **Win-mixer** — volume/mudo do endpoint do Windows (`setVolumeScalarControl`,
  `setMuteControl`). No Linux: controle do `snd-usb-audio` (ALSA/PipeWire).
- **THX-DSP** — efeito do runtime THX no Windows. No Linux: reimplementar com PipeWire
  `filter-chain` / EasyEffects.
- **Win-listen** — "Ouvir este dispositivo" do Windows (`electronAPI.setMicListenStatus`).
  No Linux: loopback do PipeWire (`pw-loopback`).

### Common Params

| Setting | Chave na UI | Mecanismo |
|---|---|---|
| Volume do headset + mudo | `setVolumeScalarControl` / `setMuteControl` (`"speaker"`) | Win-mixer **[obs]** |
| Volume da notificação sonora | `SET_PROMPT_VOLUME` (33), 1–16 | **HID** **[obs]** |
| Volume do microfone + mudo | `setVolumeScalarControl` / `setMuteControl` (mic) | Win-mixer **[obs]** |
| Magic Voice (voz modificada) | `setEnable_MAGICVOICE`, `setMagicVoice_Selection` | THX-DSP **[obs]** |
| EQ onboard (Game 1/2/3) | cmds 1, 4, 5, 12, 18, 24, 25 | **HID** **[obs]** |

### Speaker Settings (playback)

| Setting | Chaves | Mecanismo |
|---|---|---|
| Brilho (Audio Brilliant) | `setEnable_AUDIOBRILLIANT_LFX`, `setAUDIOBRILLIANT_LEVEL` | THX-DSP **[obs]** |
| Graves (Virtual Bass) | `setEnable_VIRTUALBASS_LFX`, `setVIRTUALBASS_Level`, `setVIRTUALBASS_CutOffFrequency` | THX-DSP **[obs]** |
| Volume inteligente (Adaptive Volume) | `setEnable_ADAPTIVEVOLUME_GFX`, `setADAPTIVEVOLUME_LEVEL`, `setADAPTIVEVOLUME_MODE` | THX-DSP **[obs]** |
| Clareza de voz | `setEnable_VOICECLARITY_LFX`, `setVOICECLARITY_LEVEL`, `setVOICECLARITY_NOISESUPP_LEVEL` | THX-DSP **[obs]** |

### Mic Settings

| Setting | Chaves | Mecanismo |
|---|---|---|
| Nivelamento do mic | `setEnable_MICVOLUMELEVELING`, `setMICVOLUMELEVELING_LEVEL` (0–100) | THX-DSP **[obs]** |
| Clareza vocal do mic | `setMicVoiceClarityEnabled`, `setMicVoiceClarityLevel` (0–100) | THX-DSP **[obs]** |
| Redução de ruído (AI NR) | `setAINREnable` | THX-DSP **[obs]** |
| Ouvir o microfone (sidetone por software) | `electronAPI.setMicListenStatus` | Win-listen **[obs]** |

### Other Settings

| Setting | Comando | Mecanismo |
|---|---|---|
| Auto-desligamento | `GET/SET_AUTO_SHUTDOWN` (14/26), minutos u16: 15/30/45/0 = nunca | **HID** **[obs]** |
| Restaurar padrões | `FACTORY_RESET` (27) target 3 + vários `audioRuntimeSet` para zerar os efeitos | **HID** + THX-DSP **[obs]** — não usar |
| Versão de firmware | `OtaRequest` `0x80` | **HID** **[obs]** |
| Atualizar firmware | `electronAPI.otaDevice` (processo Electron) | fora do escopo |
| Bateria / dormindo | `GET_BATTERY_SLEEP` (11) + notify 34 (mostrado no cabeçalho) | **HID** **[obs]** |

## 4. Conclusão para o port

- **No headset (HID), tudo que importa já tem payload conhecido:** EQ onboard, volume da
  notificação sonora, auto-desligamento, bateria e versão.
- **Volume** do fone e do mic é o mixer padrão do USB Audio → no Linux já funciona pelo
  ALSA/PipeWire, sem código próprio **[inf]**.
- **Efeitos de playback e de microfone** são do THX no Windows → no Linux, presets de
  PipeWire `filter-chain`/EasyEffects que aproximem cada efeito (não é o mesmo algoritmo) **[inf]**.
- Não há sidetone por hardware na UI do V9 Pro 2; "Mic Listen" é loopback por software **[obs]**.
