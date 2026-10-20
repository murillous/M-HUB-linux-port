# Fedora (alvo principal)

O app (UI + leitura HID) já foi testado pelo usuário no Fedora 44 (2026-10-19). As escritas
foram validadas no Windows.

## Permissão no hidraw

```bash
sudo cp linux/70-mchose-v9pro2.rules /etc/udev/rules.d/
sudo udevadm control --reload && sudo udevadm trigger
# desconecte e reconecte o dongle
```

## Dependência

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install hidapi==0.14.0.post4
```

No Linux a ferramenta usa o módulo `hidraw` do pacote `hidapi` (backend do kernel), não o
módulo `hid` (backend libusb), para não desanexar o driver `usbhid` do headset.

## Leitura e escrita pela linha de comando

```bash
python3 -m v9pro2          # resumo (só leituras)
python3 -m v9pro2 --raw    # com os bytes enviados/recebidos
python3 -m v9pro2 --set prompt-volume 10   # 1–16
python3 -m v9pro2 --set eq-mode 1          # 0–2
python3 -m v9pro2 --set auto-shutdown 30   # 15, 30, 45 ou 0 (nunca)
python3 -m v9pro2 --set eq-gains 2:2,3.5,-3.5,5.5,1.5,3,2,2.5,1,-1   # perfil:10 ganhos em dB
```

`--set` envia um único comando de uma lista fechada e relê o valor; nunca reset nem OTA.

## Visual do app (opcional)

- Fonte **MiSans** (gratuita, da Xiaomi): instale em `~/.local/share/fonts` para o visual ficar
  igual ao MCHOSE HUB; sem ela o app usa a fonte do sistema.
- Foto do headset (é da MCHOSE, não fica no repositório):

  ```bash
  python3 tools/install-headset-image.py              # baixa do CDN da MCHOSE
  python3 tools/install-headset-image.py headset.png  # ou copia um arquivo que você já tem
  ```

  O CDN às vezes não responde; nesse caso copie o `headset.png` de
  `%APPDATA%\mchose-hub-port\mchose-v9\` do Windows. Sem a imagem, o app mostra um desenho próprio.
