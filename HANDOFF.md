# HANDOFF — como retomar

Ao iniciar uma sessão nova, o usuário manda: **"vamos continuar de onde paramos"**.

## Checklist para o Claude ao retomar

1. Ler `CLAUDE.md` (escopo e regras) e `docs/PROGRESSO.md` (status e pendências).
2. Ler os docs técnicos que a pendência atual exigir (`docs/01-…`, `docs/02-…`).
3. Rodar `git log --oneline -10` para ver o que mudou desde a última sessão.
4. Resumir para o usuário em 3–5 linhas: onde paramos e qual é o próximo passo proposto.
   Perguntar só se houver decisão que dependa dele (ex.: abrir telas no app, conectar o headset).
5. Ao final da sessão: atualizar `docs/PROGRESSO.md` (status/pendências) e, se mudar o fluxo,
   este arquivo. Commitar com mensagem em português, sem linha de coautoria.

## Onde paramos (2026-10-21, sessão 8)

- Cadeia do mic do THX e compressor ssDRC descompilados (doc 03). Nivelamento feito como plugin
  LADSPA próprio em `crates/micdrc` (testado no Windows, ainda não rodou no Fedora).
- Próximo passo: integrar no `micfx.rs` (um filter-chain clareza → NR → nivelamento, controles
  ao vivo) e ligar os cartões `micLevel`/`micClarity`. Ver `docs/PROGRESSO.md`.
- Testes: `cargo test --workspace` (e `python -m unittest discover -s tests -t .`).
- CLI no hardware: `python -m v9pro2 [--set prompt-volume|eq-mode|auto-shutdown N | eq-gains M:G1,…,G10 | eq-name M:NOME]` (precisa de
  `hidapi` num venv do scratchpad).
- App: `cargo run -p mchose-v9` (Windows precisa de `C:\Qt\6.10.3\msvc2022_64\bin` no PATH;
  `QT_FORCE_STDERR_LOGGING=1` para ver os logs do QML). `-- --shot <pasta>` salva prints de
  todas as telas.

## Ambiente

- Windows 11, app instalado em `C:\Program Files\MCHOSE HUB\`.
- Dados do app: `%APPDATA%\MCHOSEHUB\` (cache HTTP em `Cache\Cache_Data`).
- REA disponível como MCP `rea` (`npx rea-agents@6.5.0`). Útil:
  `analyze_javascript_application` no `resources\app.asar`.
- Wireshark (+ USBPcap) e Ghidra disponíveis no Windows; Linux para testes ainda a definir
  (WSL não serve bem para HID/USB).
- `cdn.mchose.com.cn` respondeu na sessão 2 (2026-10-16). Pedir o arquivo exato: a raiz
  `customPage/prod/` dá 404, `customPage/prod/index.html` dá 200.

## Material extraído (não está no repo)

Fica no scratchpad da sessão e se perde entre sessões. Para recriar:

### Extrair o app.asar

```bash
npx -y @electron/asar@3.2.17 extract "C:/Program Files/MCHOSE HUB/resources/app.asar" <dir>
python -I tools/re/strings.py <dir>/out/main/index.jsc > index.strings.txt   # main é bytecode V8
```

### Como reextrair o cache do app

O cache usa formato blockfile; com o app aberto, `data_*` ficam bloqueados, mas os corpos
grandes (`f_*`) podem ser lidos. Dica: abra no app as telas que quer analisar antes de extrair.

```bash
python -I tools/re/fscan.py "$APPDATA/MCHOSEHUB/Cache/Cache_Data" <dir>/cache-f   # copia f_*, descomprime gzip
node tools/re/unbr.js <dir>/cache-f <dir>/cache-br                                  # descomprime brotli → *.txt
grep -l -F "V9 PRO 2" <dir>/cache-br/*.txt                                           # localizar chunks relevantes
npx -y prettier@3.3.3 --parser babel --no-color <chunk>.js > <chunk>.pretty.js       # formatar para leitura
```

Pontos de referência encontrados (nomes mudam a cada build da MCHOSE):
- chunk com `createLogger("device:service:audio:eq")` → serviço de EQ do headset;
- chunk `theme-*.js` (strings ofuscadas) → `buildReportData`, `CmdType`, consulta de versão
  (procure `OtaRequest`, `V9 Pro 2 ensureHidDeviceOpen`).
- `node tools/re/extract-fns.js <bundle> <out.js> <nomes…>` extrai funções por nome.

### Driver THX do V9 Pro 2 (efeitos de mic/playback)

Fica em `C:\Windows\System32\DriverStore\FileRepository\thx_mchose_v9pro2_apo4.inf_*`
(APO, `_rs.dll` = libDF, `_nr_model.dat` = tar.gz do DeepFilterNet3) e `thx_mchose_v9pro2_svc.inf_*`
(`_props.dat` é um zip com as definições e presets). O REA usa o Ghidra 12.1.4
em `C:\Users\muril\tools\ghidra_12.1.4_PUBLIC`, mas **não aguenta o APO**: a análise passa dos
330 s de limite e reinicia a cada chamada. Usar direto
`support\analyzeHeadless.bat <proj> apo -import <dll> -postScript <Script.java> <args>` (sem
limite) e depois `-process <dll> -noanalysis` para novos scripts. Os scripts da sessão 8 (vtables
pelo RTTI, descompilar por endereço, achar deslocamentos) ficaram no scratchpad; recriar se preciso. Alternativa: `pefile` + `capstone` num
venv do scratchpad (`pip install pefile==2024.8.26 capstone==5.0.3`).

### Baixar o shell das telas do headset (customPage)

```bash
curl -sSL https://cdn.mchose.com.cn/customPage/prod/index.html -o <dir>/index.html
python -I tools/re/crawl.py https://cdn.mchose.com.cn/customPage/prod <dir>
```

Pontos de referência: `eq-*.js` (comandos HID 0x55), `crc32-*.js` (builder do pacote e parser
de bateria), rotas em `main-*.js` (`audio_routine`, `audio_speaker`, `audio_mic`,
`otherSetting`).

### Baixar o SPA atual

```bash
curl -sSL https://www.mchose.com.cn/ -o <dir>/index.html
python -I tools/re/crawl.py https://www.mchose.com.cn <dir>   # baixa /assets/*.js referenciados
```

## Scripts em `tools/re/`

| Script | Função |
|---|---|
| `strings.py` | strings ASCII/UTF-16 de um binário (ex.: `.jsc`, `.dll`) |
| `fscan.py` | copia corpos `f_*` do cache do Chromium, descomprime gzip |
| `unbr.js` | descomprime brotli dos corpos copiados |
| `extract-fns.js` | extrai definições de funções/consts por nome de um bundle minificado |
| `crawl.py` | baixa os chunks JS de `/assets/` de um site Vite |
| `cdp.mjs` | cliente CDP mínimo para o MCHOSE HUB aberto com `--remote-debugging-port=9333`: `eval`, `shot`, `move` |
| `styles.js` | rodar com `cdp.mjs eval`: estilos computados + posição por classe CSS |
