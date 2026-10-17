//! Read-only access to the headset over HID. Only GET requests are sent.

use std::time::{Duration, Instant};

use hidapi::{HidApi, HidDevice};
use v9pro2_protocol::{self as p, BatterySleep, CmdType, EqState};

const TIMEOUT: Duration = Duration::from_secs(3);

#[derive(Debug, Default, Clone)]
pub struct Snapshot {
    pub product: String,
    /// USB cable (PID 0x6010) instead of the 2.4G dongle.
    pub wired: bool,
    pub battery: Option<BatterySleep>,
    pub prompt_volume: Option<u8>,
    pub auto_shutdown_min: Option<u16>,
    pub eq_mode: Option<u8>,
    /// Custom name per EQ mode (empty if none).
    pub eq_names: Vec<String>,
    pub eq_states: Vec<Option<EqState>>,
    pub firmware_dongle: Option<String>,
    pub firmware_headset: Option<String>,
}

#[derive(Debug)]
pub enum Error {
    NotFound,
    Hid(String),
}

impl From<hidapi::HidError> for Error {
    fn from(e: hidapi::HidError) -> Self {
        Error::Hid(e.to_string())
    }
}

fn open() -> Result<(HidDevice, String, bool), Error> {
    let api = HidApi::new()?;
    for info in api.device_list() {
        if info.vendor_id() != p::VID || !p::PIDS.contains(&info.product_id()) {
            continue;
        }
        let Ok(dev) = info.open_device(&api) else { continue };
        let mut desc = [0u8; 4096];
        if let Ok(n) = dev.get_report_descriptor(&mut desc) {
            if p::has_output_report(&desc[..n], p::REPORT_ID) {
                let product = info.product_string().unwrap_or("MCHOSE V9 Pro 2").to_owned();
                return Ok((dev, product, info.product_id() == 0x6010));
            }
        }
    }
    Err(Error::NotFound)
}

/// Sends one read request and collects matching response payloads until `complete`.
fn transact(
    dev: &HidDevice,
    cmd_type: CmdType,
    cmd: u8,
    payload: &[u8],
    matches: impl Fn(&[u8]) -> bool,
    complete: impl Fn(&[Vec<u8>]) -> bool,
) -> Result<Vec<Vec<u8>>, Error> {
    // Read-only guard: never send Set / OTA commands other than the version query.
    let allowed = cmd_type == p::REQUEST || (cmd_type == p::OTA_REQUEST && payload == [p::OTA_QUERY]);
    assert!(allowed, "command not allowed: this build is read-only");

    let mut buf = [0u8; 64];
    while dev.read_timeout(&mut buf, 0)? > 0 {} // drop late responses

    let mut out = [0u8; p::REPORT_LEN + 1];
    out[0] = p::REPORT_ID;
    out[1..].copy_from_slice(&p::build(cmd_type, cmd, payload, false));
    dev.write(&out)?;

    let mut packets = Vec::new();
    let deadline = Instant::now() + TIMEOUT;
    while Instant::now() < deadline {
        let n = dev.read_timeout(&mut buf, 200)?;
        if n == 0 {
            continue;
        }
        let data = if buf[0] == p::REPORT_ID { &buf[1..n] } else { &buf[..n] };
        if let Some(pkt) = p::parse(data) {
            if pkt.cmd_type == cmd_type && pkt.cmd == cmd && matches(&pkt.payload) {
                packets.push(pkt.payload);
                if complete(&packets) {
                    break;
                }
            }
        }
    }
    Ok(packets)
}

fn read_one(dev: &HidDevice, cmd_type: CmdType, cmd: u8, payload: &[u8]) -> Result<Option<Vec<u8>>, Error> {
    let first = payload.first().copied();
    let matches = |p: &[u8]| cmd_type != p::REQUEST || first.is_none() || p.first() == first.as_ref();
    Ok(transact(dev, cmd_type, cmd, payload, matches, |ps| !ps.is_empty())?.pop())
}

pub fn read_snapshot() -> Result<Snapshot, Error> {
    let (dev, product, wired) = open()?;
    let get = |cmd| read_one(&dev, p::REQUEST, cmd, &[]);
    let mut s = Snapshot {
        product,
        wired,
        battery: get(p::GET_BATTERY_SLEEP)?.and_then(|r| p::decode_battery_sleep(&r)),
        prompt_volume: get(p::GET_PROMPT_VOLUME)?.and_then(|r| p::decode_prompt_volume(&r)),
        auto_shutdown_min: get(p::GET_AUTO_SHUTDOWN)?.and_then(|r| p::decode_auto_shutdown(&r)),
        eq_mode: get(p::GET_CURRENT_EQ_MODE)?.and_then(|r| p::decode_current_eq_mode(&r)),
        ..Default::default()
    };
    for mode in 0..p::EQ_MODE_COUNT {
        let desc = read_one(&dev, p::REQUEST, p::GET_EQ_MODE_DESC, &[mode])?
            .and_then(|r| p::decode_eq_mode_desc(&r));
        s.eq_names.push(desc.map(|d| d.name).unwrap_or_default());

        let packets = transact(
            &dev,
            p::REQUEST,
            p::GET_EQ_STATE,
            &[mode, p::EQ_ALL_POINTS],
            |r| r.len() >= 2 && r[0] == mode && r[1] == p::EQ_ALL_POINTS,
            p::eq_points_complete,
        )?;
        s.eq_states.push(p::decode_eq_all_points(&packets));
    }
    let version = |target| -> Result<Option<String>, Error> {
        Ok(read_one(&dev, p::OTA_REQUEST, target, &[p::OTA_QUERY])?.and_then(|r| p::decode_version(&r)))
    };
    s.firmware_dongle = version(p::OTA_DONGLE)?;
    s.firmware_headset = version(p::OTA_HEADSET)?;
    Ok(s)
}
