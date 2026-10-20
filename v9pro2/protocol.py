"""Protocolo HID do MCHOSE V9 Pro 2 (report 0x55). Ver docs/02-protocolo-hid-v9-pro-2.md.

Só monta e interpreta pacotes; não fala com o dispositivo.
"""

VID = 0x3837
PIDS = (0x6011, 0x6010)  # dongle sem fio, com fio

REPORT_ID = 0x55
REPORT_LEN = 63
START, VERSION = 0xAA, 0x01

REQUEST = (0, 1)
SET = (0, 2)
NOTIFY = (0, 4)
OTA_REQUEST = (0, 6)

GET_EQ_STATE = 4
GET_EQ_MODE_DESC = 5
GET_BATTERY_SLEEP = 11
GET_CURRENT_EQ_MODE = 12
GET_PROMPT_VOLUME = 13
GET_AUTO_SHUTDOWN = 14

SET_EQ_MODE = 1
SET_AUTO_SHUTDOWN = 26
SET_PROMPT_VOLUME = 33
SET_EQ_GAINS = 18
SET_EQ_NAME = 24

OTA_QUERY = 0x80
OTA_HEADSET, OTA_DONGLE = 0, 1

EQ_ALL_POINTS = 255
EQ_MODE_NAMES = ("Game 1", "Game 2", "Game 3")
PROMPT_VOLUME_MAX = 16
EQ_GAIN_MIN_DB, EQ_GAIN_MAX_DB = -12, 12
EQ_BANDS = 10
EQ_NAME_MAX = 54  # bytes UTF-8, como na UI oficial
AUTO_SHUTDOWN_CHOICES = (15, 30, 45, 0)  # minutos oferecidos pela UI; 0 = nunca


def _checksum(flags, length, cmd_type, cmd, payload):
    c = flags ^ length ^ cmd_type[0] ^ cmd_type[1] ^ cmd
    for b in payload:
        c ^= b
    return c


def build(cmd_type, cmd, payload=(), check=False):
    """Report data de 63 bytes (sem o report ID)."""
    payload = list(payload)
    flags = 1 if check else 0
    length = len(payload) + 1
    if 7 + len(payload) >= REPORT_LEN:
        raise ValueError("payload grande demais")
    data = bytearray(REPORT_LEN)
    data[0:7] = bytes([START, VERSION, flags, length, *cmd_type, cmd])
    data[7:7 + len(payload)] = bytes(payload)
    data[7 + len(payload)] = _checksum(flags, length, cmd_type, cmd, payload) if check else 0
    return bytes(data)


def parse(data):
    """Report data (sem report ID) -> (cmd_type, cmd, payload) ou None se inválido."""
    if len(data) < 8 or data[0] != START:
        return None
    flags, length = data[2], data[3]
    if length < 1 or 7 + length - 1 >= len(data):
        return None
    cmd_type, cmd = (data[4], data[5]), data[6]
    payload = bytes(data[7:7 + length - 1])
    if flags == 1 and data[7 + len(payload)] != _checksum(flags, length, cmd_type, cmd, payload):
        return None
    return cmd_type, cmd, payload


def has_output_report(descriptor, report_id=REPORT_ID):
    """True se o descritor HID declara um output report com esse ID."""
    i, current = 0, None
    d = bytes(descriptor)
    while i < len(d):
        prefix = d[i]
        if prefix == 0xFE:  # long item
            i += 3 + (d[i + 1] if i + 1 < len(d) else 0)
            continue
        size = (0, 1, 2, 4)[prefix & 3]
        value = int.from_bytes(d[i + 1:i + 1 + size], "little")
        tag = prefix & 0xFC
        if tag == 0x84:  # Report ID
            current = value
        elif tag == 0x90 and current == report_id:  # Output
            return True
        i += 1 + size
    return False


def _i16(hi, lo):
    v = (hi << 8) | lo
    return v - 0x10000 if v & 0x8000 else v


def decode_battery_sleep(p):
    if len(p) < 2:
        return None
    return {"asleep": p[0] == 0, "sleep_state": p[0],
            "charging": bool(p[1] >> 7), "percent": p[1] & 0x7F}


def decode_prompt_volume(p):
    return {"volume": p[0]} if p else None


def decode_auto_shutdown(p):
    if len(p) < 2:
        return None
    minutes = (p[0] << 8) | p[1]
    return {"minutes": minutes, "never": minutes == 0}


def encode_set_eq_mode(mode):
    if mode not in range(len(EQ_MODE_NAMES)):
        raise ValueError("mode deve ser 0-2")
    return [mode]


def encode_set_prompt_volume(volume):
    if not 1 <= volume <= PROMPT_VOLUME_MAX:
        raise ValueError(f"volume deve ser 1-{PROMPT_VOLUME_MAX}")
    return [volume]


def encode_set_auto_shutdown(minutes):
    if minutes not in AUTO_SHUTDOWN_CHOICES:
        raise ValueError(f"minutos deve ser um de {AUTO_SHUTDOWN_CHOICES}")
    return [minutes >> 8, minutes & 0xFF]


def encode_set_eq_gains(mode, gains_db):
    """[mode, n, (g_hi, g_lo)×n], g = round(dB × 10) int16 big-endian."""
    encode_set_eq_mode(mode)
    if len(gains_db) != EQ_BANDS:
        raise ValueError(f"esperados {EQ_BANDS} ganhos")
    out = [mode, len(gains_db)]
    for g in gains_db:
        if not EQ_GAIN_MIN_DB <= g <= EQ_GAIN_MAX_DB:
            raise ValueError(f"ganho fora de {EQ_GAIN_MIN_DB}..{EQ_GAIN_MAX_DB} dB")
        out += list(round(g * 10).to_bytes(2, "big", signed=True))
    return out


def decode_current_eq_mode(p):
    return {"mode": p[0]} if p else None


def encode_set_eq_name(mode, name):
    """[mode, nome UTF-8], sem terminador; 1 a EQ_NAME_MAX bytes."""
    encode_set_eq_mode(mode)
    raw = name.strip().encode("utf-8")
    if not 1 <= len(raw) <= EQ_NAME_MAX or 0 in raw:
        raise ValueError(f"nome deve ter 1-{EQ_NAME_MAX} bytes UTF-8")
    return [mode, *raw]


def decode_eq_mode_desc(p):
    if not p:
        return None
    raw = p[1:]
    if 0 in raw:
        raw = raw[:raw.index(0)]
    name = raw.decode("utf-8", "replace").strip()
    mode = p[0]
    default = EQ_MODE_NAMES[mode] if mode < len(EQ_MODE_NAMES) else f"Mode {mode}"
    return {"mode": mode, "name": name or default}


def eq_points_complete(packets):
    """True quando os pacotes de ALL_POINTS já trazem todos os pontos anunciados."""
    return bool(packets) and sum(_eq_packet_points(p)[1] for p in packets) >= packets[0][4]


def _eq_packet_points(p):
    """(índice do pacote, pontos neste pacote) a partir do byte 5.

    Observado no hardware: 10 pontos chegam em 2 pacotes com byte 5 = 0x59 e 0x5A.
    Leitura [inf]: bits 7-4 = pontos no pacote, 3-2 = total de pacotes, 1-0 = pacote atual.
    """
    n = min(p[5] >> 4, (len(p) - 6) // 7)
    return p[5] & 3, n


def decode_eq_all_points(packets):
    """Respostas de GET_EQ_STATE com sub = ALL_POINTS (255), em um ou mais pacotes."""
    packets = [p for p in packets if len(p) >= 6 and p[1] == EQ_ALL_POINTS]
    if not packets:
        return None
    points = []
    for p in sorted(packets, key=lambda p: _eq_packet_points(p)[0]):
        for k in range(_eq_packet_points(p)[1]):
            off = 6 + 7 * k
            points.append({
                "fc": (p[off] << 8) | p[off + 1],
                "gain_db": _i16(p[off + 2], p[off + 3]) / 10,
                "q": p[off + 4] / 10,
                "type": p[off + 5],
                "enable": p[off + 6] == 1,
            })
    first = packets[0]
    return {"mode": first[0], "total_gain": _i16(first[2], first[3]),
            "point_count": first[4], "points": points}


def decode_version(p):
    """Resposta de OtaRequest/QUERY (target vai no cmd): [0x80, d0, d1, d2, d3].

    Igual à UI: ASCII se os 4 bytes forem dígitos, senão hex com os 4 últimos dígitos.
    """
    if len(p) < 5 or p[0] != OTA_QUERY:
        return None
    d = bytes(p[1:5])
    if all(0x30 <= b <= 0x39 for b in d):
        return {"version": d.decode("ascii")}
    return {"version": d.hex()[-4:]}
