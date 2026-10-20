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

#### Como o THX implementa os efeitos de microfone (sessão 6) **[obs]**

Arquivos do driver THX no DriverStore (`thx_mchose_v9pro2_apo4.inf_*` e `thx_mchose_v9pro2_svc.inf_*`):
`thx_mchose_v9pro2_apo4.dll` (APO), `…_apo4_rs.dll` (Rust), `…_apo4_nr_model.dat`,
`…_props.dat` (zip com as definições dos efeitos). Nada disso vai para o repositório.

- **AI NR = DeepFilterNet3**, projeto open source (MIT/Apache-2.0, Rikorose/DeepFilterNet).
  O `nr_model.dat` é o `DeepFilterNet3_onnx.tar.gz` oficial (gzip de `enc.onnx`,
  `erb_dec.onnx`, `df_dec.onnx` + `config.ini`: 48 kHz, FFT 960, hop 480 = 10 ms,
  `df_lookahead = 2`). O `_rs.dll` é a `libDF` (C API `df_create`, `df_process_frame`,
  `df_set_atten_lim`, `df_set_post_filter_beta`) com `tract-onnx 0.21.4`.
- Parâmetros (disassembly do APO, `capstone`; o REA não tinha backend de disassembly
  disponível no Windows): `df_create(modelo, atten_lim 0, NULL)`, depois
  `df_set_post_filter_beta(0,04)` e `df_set_atten_lim(nível × atenuação máxima)`. O preset
  `mic_presets/default` usa nível 0,65 e atenuação máxima 60 dB → **39 dB**. A UI só liga ou
  desliga (`setAINREnable`); o liga/desliga vira um ganho de mistura 0/1 no APO.
- `props.dat` → `thx_property_definitions.mic*.json` (valores usados no port):
  - Nivelamento (`mic_volume_leveling_*`): compressor ssDRC com tabela por nível 0–100:
    nível 0 → ratio 2, threshold −6 dB, knee 4, ganho +3 dB, ataque 5 ms, release 250 ms;
    20 → 2,2/−11/5/+6/5/300; 40 → 2,4/−15,5/6/+9/6/350; 60 → 2,6/−19,5/7/+12/8/450;
    80 → 2,8/−23,5/8/+15/10/550; 100 → 3/−27/9/+18/10/700.
  - Clareza vocal (`mic_voice_clarity_*`): EQ de 10 bandas (31 Hz…16 kHz) com ganho
    `nível × máximo`; máximos −12, −12, −11, 0, +7, +8, +8, 0, +3, +6 dB.
  - Limitador final do mic (sempre ligado): ratio 7, threshold −1 dB, ataque 0,1 ms,
    release 100 ms.
  - Existe `mic_sidetone_enabled/level` no runtime, mas a UI do V9 Pro 2 não usa; o "Mic
    Listen" é `MicListen.dll` ("Ouvir este dispositivo").

Port no Linux (`app/src/micfx.rs`): NR = plugin LADSPA oficial do DeepFilterNet (v0.5.6, modelo
de baixa latência do mesmo projeto, ~20 ms) num `filter-chain` com fonte virtual
`mchose_v9_mic_nr` que vira a fonte padrão; monitoramento = `module-loopback` para o fone, do
mic cru com `node.latency = 64/48000` ou, com NR ligado, da fonte com NR com `512/48000`. Cada um roda como `pipewire -c` destacado.

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
