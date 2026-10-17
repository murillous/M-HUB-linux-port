# Fedora (alvo principal)

Testado até aqui só no Windows; os passos abaixo são para o Fedora 43 e ainda não foram
validados nele.

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

## Leitura das configurações (somente leitura)

```bash
python3 -m v9pro2          # resumo
python3 -m v9pro2 --raw    # com os bytes enviados/recebidos
```

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
