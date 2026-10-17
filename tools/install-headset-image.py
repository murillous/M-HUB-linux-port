"""Installs the V9 Pro 2 product photo used by the MCHOSE HUB into the app data dir.

The image belongs to MCHOSE and is not in this repository. The app shows it when present
(see app/qml/HeadsetImage.qml) and falls back to its own drawing otherwise.

    python tools/install-headset-image.py            # download from the MCHOSE CDN
    python tools/install-headset-image.py file.png   # copy a file you already have
                                                     # (e.g. from a Windows install of this app)
"""

import os
import shutil
import sys
import urllib.request
from pathlib import Path

URL = "https://cdn.mchose.com.cn/configCenter/static/images/v9pro2Black_78b78392b873.png"
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"


def data_dir() -> Path:
    """Same place as Qt's StandardPaths.AppDataLocation for org "mchose-hub-port", app "mchose-v9"."""
    if sys.platform == "win32":
        base = Path(os.environ["APPDATA"])
    else:
        base = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")
    return base / "mchose-hub-port" / "mchose-v9"


def main() -> int:
    if len(sys.argv) > 1:
        data = Path(sys.argv[1]).read_bytes()
    else:
        print(f"Downloading {URL}")
        with urllib.request.urlopen(URL, timeout=30) as resp:
            data = resp.read()
    if not data.startswith(PNG_MAGIC):
        print("Not a PNG file, nothing installed.", file=sys.stderr)
        return 1
    target = data_dir() / "headset.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_suffix(".tmp")
    tmp.write_bytes(data)
    shutil.move(tmp, target)
    print(f"Installed {target} ({len(data)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
