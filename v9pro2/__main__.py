"""Read-only dump of MCHOSE V9 Pro 2 settings.

Uso: python -m v9pro2 [--raw]

Não envia nenhum comando de escrita: só os pacotes listados em READS.
"""

import argparse
import sys
import time

from . import protocol as P

try:
    if sys.platform.startswith("linux"):
        import hidraw as hid  # backend hidraw: não desanexa o driver do kernel
    else:
        import hid
except ImportError:
    sys.exit("hidapi module not found: pip install hidapi (Fedora: dnf install python3-hidapi)")

TIMEOUT_S = 3.0

def _one(decode):
    return lambda packets: decode(packets[0])


def _mode_is(mode, sub=None):
    return lambda p: len(p) >= 2 and p[0] == mode and (sub is None or p[1] == sub)


# (rótulo, cmdType, cmd, payload, decoder, filtro da resposta, resposta completa?) — só leituras.
READS = [
    ("battery_sleep", P.REQUEST, P.GET_BATTERY_SLEEP, [], _one(P.decode_battery_sleep), None, None),
    ("prompt_volume", P.REQUEST, P.GET_PROMPT_VOLUME, [], _one(P.decode_prompt_volume), None, None),
    ("auto_shutdown", P.REQUEST, P.GET_AUTO_SHUTDOWN, [], _one(P.decode_auto_shutdown), None, None),
    ("current_eq_mode", P.REQUEST, P.GET_CURRENT_EQ_MODE, [], _one(P.decode_current_eq_mode), None, None),
    *[(f"eq_mode_desc[{m}]", P.REQUEST, P.GET_EQ_MODE_DESC, [m], _one(P.decode_eq_mode_desc),
       _mode_is(m), None) for m in range(3)],
    *[(f"eq_state[{m}]", P.REQUEST, P.GET_EQ_STATE, [m, P.EQ_ALL_POINTS], P.decode_eq_all_points,
       _mode_is(m, P.EQ_ALL_POINTS), P.eq_points_complete) for m in range(3)],
    ("version_dongle", P.OTA_REQUEST, P.OTA_DONGLE, [P.OTA_QUERY], _one(P.decode_version), None, None),
    ("version_headset", P.OTA_REQUEST, P.OTA_HEADSET, [P.OTA_QUERY], _one(P.decode_version), None, None),
]
ALLOWED_CMD_TYPES = {P.REQUEST, P.OTA_REQUEST}


def find_device():
    for info in hid.enumerate(P.VID, 0):
        if info["product_id"] not in P.PIDS:
            continue
        dev = hid.device()
        try:
            dev.open_path(info["path"])
            if P.has_output_report(dev.get_report_descriptor()):
                return dev, info
        except (OSError, IOError):
            pass
        dev.close()
    return None, None


def _drain(dev):
    while dev.read(64, 1):  # timeout 0 no hidapi = bloqueante
        pass


def transact(dev, cmd_type, cmd, payload, match=None, complete=None, raw=False):
    """Envia uma leitura e devolve a lista de payloads de resposta (vazia se timeout)."""
    if cmd_type not in ALLOWED_CMD_TYPES or (cmd_type == P.OTA_REQUEST and payload != [P.OTA_QUERY]):
        raise RuntimeError("command not allowed: this tool is read-only")
    complete = complete or bool
    out = P.build(cmd_type, cmd, payload)
    _drain(dev)
    if raw:
        print("  >>", out[:12].hex(" "))
    dev.write(bytes([P.REPORT_ID]) + out)
    packets = []
    deadline = time.monotonic() + TIMEOUT_S
    while time.monotonic() < deadline:
        data = dev.read(64, 200)
        if not data:
            continue
        data = bytes(data)
        if data[0] == P.REPORT_ID:
            data = data[1:]
        pkt = P.parse(data)
        if raw:
            print("  <<", data[:24].hex(" "), "" if pkt else "(invalid)")
        if pkt and pkt[0] == cmd_type and pkt[1] == cmd and (match is None or match(pkt[2])):
            packets.append(pkt[2])
            if complete(packets):
                break
    return packets


def main():
    ap = argparse.ArgumentParser(prog="v9pro2", description=__doc__.splitlines()[0])
    ap.add_argument("--raw", action="store_true", help="show raw sent/received bytes")
    args = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    dev, info = find_device()
    if dev is None:
        sys.exit("V9 Pro 2 not found (or no hidraw permission; see linux/README.md)")
    print(f"{info['product_string']}  {P.VID:04x}:{info['product_id']:04x}")
    try:
        for label, cmd_type, cmd, payload, decode, match, complete in READS:
            if args.raw:
                print(f"[{label}]")
            packets = transact(dev, cmd_type, cmd, payload, match, complete, args.raw)
            if not packets:
                print(f"{label}: no response")
                continue
            decoded = decode(packets)
            line = f"{label}: {decoded if decoded is not None else 'not decoded'}"
            if decoded is None or args.raw:
                line += "  payload=" + " | ".join(p.hex(" ") for p in packets)
            print(line)
    finally:
        dev.close()


if __name__ == "__main__":
    main()
