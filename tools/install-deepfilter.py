"""Installs the DeepFilterNet LADSPA plugin used by "Microphone noise reduction" (Linux).

The MCHOSE HUB (THX runtime) runs DeepFilterNet3 for its AI noise reduction; this is the official
LADSPA build of the same project (MIT/Apache-2.0). It is not in this repository: this script
downloads the release from GitHub, checks its SHA-256 and copies it where the app looks for it.

    python3 tools/install-deepfilter.py            # download v0.5.6 from GitHub
    python3 tools/install-deepfilter.py file.so    # copy a file you already have
"""

import hashlib
import os
import shutil
import sys
import urllib.request
from pathlib import Path

URL = (
    "https://github.com/Rikorose/DeepFilterNet/releases/download/v0.5.6/"
    "libdeep_filter_ladspa-0.5.6-x86_64-unknown-linux-gnu.so"
)
SHA256 = "2ca3205c2911d389604a826a240e745597d50252b5cab81c8248252b335e2236"
TARGET = Path.home() / ".local" / "lib" / "ladspa" / "libdeep_filter_ladspa.so"


def main() -> int:
    if len(sys.argv) > 1:
        data = Path(sys.argv[1]).read_bytes()
    else:
        print(f"Downloading {URL} (~50 MB)")
        with urllib.request.urlopen(URL, timeout=120) as resp:
            data = resp.read()
        digest = hashlib.sha256(data).hexdigest()
        if digest != SHA256:
            print(f"SHA-256 mismatch ({digest}), nothing installed.", file=sys.stderr)
            return 1
    if not data.startswith(b"\x7fELF"):
        print("Not a Linux shared library, nothing installed.", file=sys.stderr)
        return 1
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    tmp = TARGET.with_suffix(".tmp")
    tmp.write_bytes(data)
    os.chmod(tmp, 0o755)
    shutil.move(tmp, TARGET)
    print(f"Installed {TARGET} ({len(data)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
