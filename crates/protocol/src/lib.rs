//! HID protocol of the MCHOSE V9 Pro 2 (report 0x55). See `docs/02-protocolo-hid-v9-pro-2.md`.
//!
//! Pure packet building/decoding; no device I/O here.

pub const VID: u16 = 0x3837;
/// Wireless dongle, wired.
pub const PIDS: [u16; 2] = [0x6011, 0x6010];

pub const REPORT_ID: u8 = 0x55;
pub const REPORT_LEN: usize = 63;
const START: u8 = 0xAA;
const VERSION: u8 = 0x01;

pub type CmdType = [u8; 2];
pub const REQUEST: CmdType = [0, 1];
pub const SET: CmdType = [0, 2];
pub const NOTIFY: CmdType = [0, 4];
pub const OTA_REQUEST: CmdType = [0, 6];

pub const GET_EQ_STATE: u8 = 4;
pub const GET_EQ_MODE_DESC: u8 = 5;
pub const GET_BATTERY_SLEEP: u8 = 11;
pub const GET_CURRENT_EQ_MODE: u8 = 12;
pub const GET_PROMPT_VOLUME: u8 = 13;
pub const GET_AUTO_SHUTDOWN: u8 = 14;

pub const OTA_QUERY: u8 = 0x80;
pub const OTA_HEADSET: u8 = 0;
pub const OTA_DONGLE: u8 = 1;

pub const EQ_ALL_POINTS: u8 = 255;
pub const EQ_MODE_COUNT: u8 = 3;
pub const PROMPT_VOLUME_MAX: u8 = 16;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Packet {
    pub cmd_type: CmdType,
    pub cmd: u8,
    pub payload: Vec<u8>,
}

fn checksum(flags: u8, length: u8, cmd_type: CmdType, cmd: u8, payload: &[u8]) -> u8 {
    payload
        .iter()
        .fold(flags ^ length ^ cmd_type[0] ^ cmd_type[1] ^ cmd, |c, b| c ^ b)
}

/// 63-byte report data (without the report ID).
pub fn build(cmd_type: CmdType, cmd: u8, payload: &[u8], check: bool) -> [u8; REPORT_LEN] {
    assert!(7 + payload.len() < REPORT_LEN, "payload too large");
    let flags = check as u8;
    let length = payload.len() as u8 + 1;
    let mut data = [0u8; REPORT_LEN];
    data[..7].copy_from_slice(&[START, VERSION, flags, length, cmd_type[0], cmd_type[1], cmd]);
    data[7..7 + payload.len()].copy_from_slice(payload);
    if check {
        data[7 + payload.len()] = checksum(flags, length, cmd_type, cmd, payload);
    }
    data
}

/// Report data (without report ID) -> packet, or `None` if malformed / bad checksum.
pub fn parse(data: &[u8]) -> Option<Packet> {
    if data.len() < 8 || data[0] != START {
        return None;
    }
    let (flags, length) = (data[2], data[3]);
    let end = 7 + (length as usize).checked_sub(1)?;
    if end >= data.len() {
        return None;
    }
    let cmd_type = [data[4], data[5]];
    let cmd = data[6];
    let payload = &data[7..end];
    if flags == 1 && data[end] != checksum(flags, length, cmd_type, cmd, payload) {
        return None;
    }
    Some(Packet { cmd_type, cmd, payload: payload.to_vec() })
}

/// True if the HID report descriptor declares an output report with `report_id`.
pub fn has_output_report(descriptor: &[u8], report_id: u8) -> bool {
    let (mut i, mut current) = (0, None);
    while i < descriptor.len() {
        let prefix = descriptor[i];
        if prefix == 0xFE {
            // long item
            i += 3 + *descriptor.get(i + 1).unwrap_or(&0) as usize;
            continue;
        }
        let size = [0, 1, 2, 4][(prefix & 3) as usize];
        let value = descriptor[i + 1..]
            .iter()
            .take(size)
            .enumerate()
            .fold(0u32, |v, (k, b)| v | (*b as u32) << (8 * k));
        match prefix & 0xFC {
            0x84 => current = Some(value),
            0x90 if current == Some(report_id as u32) => return true,
            _ => {}
        }
        i += 1 + size;
    }
    false
}

fn i16_be(hi: u8, lo: u8) -> i16 {
    i16::from_be_bytes([hi, lo])
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BatterySleep {
    pub asleep: bool,
    pub charging: bool,
    pub percent: u8,
}

pub fn decode_battery_sleep(p: &[u8]) -> Option<BatterySleep> {
    let [state, b, ..] = *p else { return None };
    Some(BatterySleep { asleep: state == 0, charging: b >> 7 == 1, percent: b & 0x7F })
}

pub fn decode_prompt_volume(p: &[u8]) -> Option<u8> {
    p.first().copied()
}

/// Idle minutes before auto shutdown; `0` = never.
pub fn decode_auto_shutdown(p: &[u8]) -> Option<u16> {
    let [hi, lo, ..] = *p else { return None };
    Some(u16::from_be_bytes([hi, lo]))
}

pub fn decode_current_eq_mode(p: &[u8]) -> Option<u8> {
    p.first().copied()
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EqModeDesc {
    pub mode: u8,
    /// Empty if the headset has no custom name.
    pub name: String,
}

pub fn decode_eq_mode_desc(p: &[u8]) -> Option<EqModeDesc> {
    let (&mode, rest) = p.split_first()?;
    let raw = rest.split(|&b| b == 0).next().unwrap_or(&[]);
    Some(EqModeDesc { mode, name: String::from_utf8_lossy(raw).trim().to_owned() })
}

#[derive(Debug, Clone, PartialEq)]
pub struct EqPoint {
    pub fc: u16,
    pub gain_db: f32,
    pub q: f32,
    pub filter_type: u8,
    pub enable: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub struct EqState {
    pub mode: u8,
    pub total_gain: i16,
    pub point_count: u8,
    pub points: Vec<EqPoint>,
}

/// (packet index, points in this packet) from byte 5.
///
/// Seen on hardware: 10 points arrive in 2 packets with byte 5 = 0x59 and 0x5A.
/// Reading [inf]: bits 7-4 = points in packet, 3-2 = total packets, 1-0 = current packet.
fn eq_packet_points(p: &[u8]) -> (u8, usize) {
    let n = ((p[5] >> 4) as usize).min((p.len() - 6) / 7);
    (p[5] & 3, n)
}

fn is_all_points(p: &[u8]) -> bool {
    p.len() >= 6 && p[1] == EQ_ALL_POINTS
}

/// True once the ALL_POINTS packets carry every announced point.
pub fn eq_points_complete(packets: &[Vec<u8>]) -> bool {
    let packets: Vec<_> = packets.iter().filter(|p| is_all_points(p)).collect();
    !packets.is_empty()
        && packets.iter().map(|p| eq_packet_points(p).1).sum::<usize>() >= packets[0][4] as usize
}

/// GET_EQ_STATE responses with sub = ALL_POINTS (255), one or more packets.
pub fn decode_eq_all_points(packets: &[Vec<u8>]) -> Option<EqState> {
    let mut packets: Vec<&Vec<u8>> = packets.iter().filter(|p| is_all_points(p)).collect();
    let first = *packets.first()?;
    packets.sort_by_key(|p| eq_packet_points(p).0);
    let points = packets
        .iter()
        .flat_map(|p| {
            (0..eq_packet_points(p).1).map(move |k| {
                let o = 6 + 7 * k;
                EqPoint {
                    fc: u16::from_be_bytes([p[o], p[o + 1]]),
                    gain_db: i16_be(p[o + 2], p[o + 3]) as f32 / 10.0,
                    q: p[o + 4] as f32 / 10.0,
                    filter_type: p[o + 5],
                    enable: p[o + 6] == 1,
                }
            })
        })
        .collect();
    Some(EqState {
        mode: first[0],
        total_gain: i16_be(first[2], first[3]),
        point_count: first[4],
        points,
    })
}

/// OtaRequest/QUERY response (target travels in `cmd`): `[0x80, d0, d1, d2, d3]`.
///
/// Same rule as the vendor UI: ASCII if all 4 bytes are digits, else the last 4 hex digits.
pub fn decode_version(p: &[u8]) -> Option<String> {
    let [OTA_QUERY, d @ ..] = p else { return None };
    let d = d.get(..4)?;
    if d.iter().all(u8::is_ascii_digit) {
        return Some(String::from_utf8_lossy(d).into_owned());
    }
    let hex: String = d.iter().map(|b| format!("{b:02x}")).collect();
    Some(hex[hex.len() - 4..].to_owned())
}

#[cfg(test)]
mod tests {
    //! Bytes captured from a real V9 Pro 2 (Windows, 2026-10-16).
    use super::*;

    fn h(s: &str) -> Vec<u8> {
        s.split_whitespace().map(|b| u8::from_str_radix(b, 16).unwrap()).collect()
    }

    #[test]
    fn build_request() {
        let out = build(REQUEST, GET_BATTERY_SLEEP, &[], false);
        assert_eq!(out[..8], h("aa 01 00 01 00 01 0b 00")[..]);
    }

    #[test]
    fn build_ota_query() {
        let out = build(OTA_REQUEST, OTA_DONGLE, &[OTA_QUERY], false);
        assert_eq!(out[..8], h("aa 01 00 02 00 06 01 80")[..]);
    }

    #[test]
    fn parse_checks_checksum() {
        let mut good = h("aa 01 01 03 00 01 0b 01 54 5d");
        good.resize(REPORT_LEN, 0);
        let pkt = parse(&good).unwrap();
        assert_eq!((pkt.cmd_type, pkt.cmd, pkt.payload), (REQUEST, 11, h("01 54")));
        good[9] ^= 1;
        assert!(parse(&good).is_none());
    }

    #[test]
    fn battery() {
        let b = decode_battery_sleep(&h("01 54")).unwrap();
        assert_eq!(b, BatterySleep { asleep: false, charging: false, percent: 84 });
    }

    #[test]
    fn auto_shutdown() {
        assert_eq!(decode_auto_shutdown(&h("00 1e")), Some(30));
    }

    #[test]
    fn eq_mode_desc_utf8() {
        let p = h("02 e5 ae 98 e6 96 b9 e9 a2 84 e8 ae be 2d e9 9f b3 e4 b9 90 00");
        assert_eq!(decode_eq_mode_desc(&p).unwrap().name, "官方预设-音乐");
    }

    #[test]
    fn eq_all_points_two_packets() {
        let p1 = h("00 ff 00 00 0a 59 00 2d 00 14 08 00 01 00 64 00 23 07 00 01 00 fa ff dd 08 00 01 \
                    01 90 00 37 0c 00 01 03 e8 00 0f 0b 00 01");
        let p2 = h("00 ff 00 00 0a 5a 07 d0 00 1e 07 00 01 0f a0 00 14 07 00 01 17 70 00 19 08 00 01 \
                    1f 40 00 0a 0a 00 01 2e e0 ff f6 09 00 01");
        assert!(!eq_points_complete(&[p1.clone()]));
        assert!(eq_points_complete(&[p2.clone(), p1.clone()]));
        let eq = decode_eq_all_points(&[p2, p1]).unwrap();
        let fcs: Vec<u16> = eq.points.iter().map(|p| p.fc).collect();
        assert_eq!(fcs, [45, 100, 250, 400, 1000, 2000, 4000, 6000, 8000, 12000]);
        assert_eq!(eq.points[2].gain_db, -3.5);
        assert_eq!(
            eq.points[9],
            EqPoint { fc: 12000, gain_db: -1.0, q: 0.9, filter_type: 0, enable: true }
        );
    }

    #[test]
    fn version() {
        assert_eq!(decode_version(&h("80 00 00 00 33")).as_deref(), Some("0033"));
    }

    #[test]
    fn descriptor_has_report_55() {
        let desc = h("06 07 ff 0a 22 02 a1 01 85 55 09 02 15 00 25 ff 75 08 95 3f 81 02 \
                      85 55 09 01 15 00 25 ff 75 08 95 3f 91 02 c0");
        assert!(has_output_report(&desc, REPORT_ID));
        assert!(!has_output_report(&h("05 0c 09 01 a1 01 85 01 09 00 91 02 c0"), REPORT_ID));
    }
}
