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

## Onde paramos (2026-10-16)

- Protocolo HID do EQ onboard e da consulta de versão extraído (não testado no hardware).
- **Próximo passo:** encontrar o código/pacotes das telas de settings do V9 Pro 2
  (notificação sonora, mic, playback, other). Ver pendência 1 em `docs/PROGRESSO.md`.

## Ambiente

- Windows 11, app instalado em `C:\Program Files\MCHOSE HUB\`.
- Dados do app: `%APPDATA%\MCHOSEHUB\` (cache HTTP em `Cache\Cache_Data`).
- REA disponível como MCP `rea` (`npx rea-agents@6.5.0`). Útil:
  `analyze_javascript_application` no `resources\app.asar`.
- Wireshark (+ USBPcap) e Ghidra disponíveis no Windows; Linux para testes ainda a definir
  (WSL não serve bem para HID/USB).
- `cdn.mchose.com.cn` não respondeu desta rede em 2026-10-16; `www.mchose.com.cn` responde.

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
