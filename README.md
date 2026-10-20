# M-HUB-linux-port

Port para Linux das configurações do headset **MCHOSE V9 Pro 2** que hoje só existem no
MCHOSE HUB (Windows).

## Escopo

O port cobre apenas estas configurações:

- EQ
- Volume
- Notificação sonora (prompts de voz / volume do aviso)
- Microfone
- Playback settings
- Microphone settings
- Other settings (ex.: desligamento automático)

**Fora do escopo:** THX (Audio Player, instalador, serviços), integrações de música/letras,
login, telas de teclado/mouse e qualquer outro produto MCHOSE.

## Requisitos

Plataforma alvo: **Fedora 43** (KDE Plasma). O app também compila no Windows, usado só para
validar o protocolo.

| O quê | Para quê | Fedora |
|---|---|---|
| Rust ≥ 1.85 (edition 2024) | compilar o app | `rust cargo` (ou rustup) |
| Compilador C/C++ | CXX-Qt e `hidapi` | `gcc-c++` |
| Qt 6 (Core, Gui, Qml, Quick, Quick Controls, Shapes) | interface | `qt6-qtbase-devel qt6-qtdeclarative-devel` |
| libudev + pkg-config | backend `hidraw` do `hidapi` | `systemd-devel pkgconf-pkg-config` |
| PipeWire + WirePlumber (`pw-dump`, `wpctl`) | sliders de volume e microfone | `pipewire-utils wireplumber` (já vêm no Fedora) |
| Python 3 (opcional) | ferramenta de leitura `v9pro2` e testes | já vem no Fedora |

O headset usa o driver padrão `snd-usb-audio` (áudio) e `usbhid`/`hidraw` (configurações):
nenhum driver extra.

## Setup (Fedora)

> Ainda não validado no Fedora; testado até aqui só no Windows.

1. Instalar as dependências:

   ```bash
   sudo dnf install rust cargo gcc-c++ qt6-qtbase-devel qt6-qtdeclarative-devel \
       systemd-devel pkgconf-pkg-config
   ```

2. Dar acesso ao hidraw do headset para o usuário logado (sem root):

   ```bash
   sudo cp linux/70-mchose-v9pro2.rules /etc/udev/rules.d/
   sudo udevadm control --reload && sudo udevadm trigger
   ```

   Depois desconecte e reconecte o dongle (ou o cabo).

3. Corrigir a curva de volume (o firmware anuncia uma faixa em dB errada e o volume chega ao
   máximo com 15-20% do controle). O PipeWire passa a controlar o volume em software:

   ```bash
   mkdir -p ~/.config/wireplumber/wireplumber.conf.d
   cp linux/51-mchose-v9pro2.conf ~/.config/wireplumber/wireplumber.conf.d/
   systemctl --user restart wireplumber
   amixer -c "$(awk '/USB-Audio - MCHOSE V9 Pro 2/ {print $1}' /proc/asound/cards)" sset PCM 100%
   ```

   O último comando deixa o volume do próprio headset em 100% (0 dB); se depois de
   reconectar ele voltar baixo, rode-o de novo.

4. Compilar e rodar:

   ```bash
   cargo run --release -p mchose-v9
   ```

   O CXX-Qt acha o Qt pelo `qmake6`. Se tiver mais de um Qt instalado, aponte o certo com
   `QMAKE=/caminho/para/qmake6`. Para ver os logs do QML: `QT_FORCE_STDERR_LOGGING=1`.

5. Opcional: fonte MiSans e foto do headset, ver [linux/README.md](linux/README.md#visual-do-app-opcional).

Testes: `cargo test --workspace` e `python3 -m unittest discover -s tests -t .`.
A ferramenta Python de leitura (`python3 -m v9pro2`) está em [linux/README.md](linux/README.md).

## Documentação

- [Progresso](docs/PROGRESSO.md) — status atual e próximos passos
- [Handoff](HANDOFF.md) — como retomar numa nova sessão
- [01 — Análise inicial do app](docs/01-analise-inicial.md)
- [02 — Protocolo HID do V9 Pro 2](docs/02-protocolo-hid-v9-pro-2.md)
- [04 — Referência visual da UI](docs/04-referencia-visual.md)
