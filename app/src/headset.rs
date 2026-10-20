//! `Headset` QML object: exposes the headset state read over HID and writes the onboard settings.

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    #[auto_cxx_name]
    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(bool, busy)]
        #[qproperty(bool, connected)]
        /// "" when ok; "not_found" or "hid" (see `error_detail`).
        #[qproperty(QString, error)]
        #[qproperty(QString, error_detail)]
        #[qproperty(QString, product)]
        #[qproperty(bool, wired)]
        /// -1 = unknown.
        #[qproperty(i32, battery_percent)]
        #[qproperty(bool, charging)]
        #[qproperty(bool, asleep)]
        /// 1..=16, -1 = unknown.
        #[qproperty(i32, prompt_volume)]
        #[qproperty(i32, prompt_volume_max)]
        /// Minutes, 0 = never, -1 = unknown.
        #[qproperty(i32, auto_shutdown_min)]
        /// 0..=2, -1 = unknown.
        #[qproperty(i32, eq_mode)]
        /// JSON: `[{"name": str, "points": [{"fc", "gain", "q", "type", "enable"}]}]`.
        #[qproperty(QString, eq_json)]
        #[qproperty(QString, firmware_dongle)]
        #[qproperty(QString, firmware_headset)]
        type Headset = super::HeadsetRust;

        /// Reads everything from the headset on a background thread.
        #[qinvokable]
        fn refresh(self: Pin<&mut Headset>);

        /// 1..=16.
        #[qinvokable]
        fn set_prompt_volume_on_device(self: Pin<&mut Headset>, volume: i32);
        /// 0..=2.
        #[qinvokable]
        fn set_eq_mode_on_device(self: Pin<&mut Headset>, mode: i32);
        /// 15, 30, 45 or 0 (never).
        #[qinvokable]
        fn set_auto_shutdown_on_device(self: Pin<&mut Headset>, minutes: i32);
        /// `gains`: the 10 band gains in dB, comma separated (−12…+12, 0.1 steps).
        #[qinvokable]
        fn set_eq_gains_on_device(self: Pin<&mut Headset>, mode: i32, gains: &QString);
        /// Trimmed and cut to 54 UTF-8 bytes; empty names are ignored.
        #[qinvokable]
        fn set_eq_name_on_device(self: Pin<&mut Headset>, mode: i32, name: &QString);
    }

    impl cxx_qt::Threading for Headset {}
}

use core::pin::Pin;

use cxx_qt::{CxxQtType, Threading};
use cxx_qt_lib::QString;

use v9pro2_protocol::{self as protocol, EqState, Write};

use crate::device::{self, Snapshot, Written};

pub struct HeadsetRust {
    busy: bool,
    connected: bool,
    error: QString,
    error_detail: QString,
    product: QString,
    wired: bool,
    battery_percent: i32,
    charging: bool,
    asleep: bool,
    prompt_volume: i32,
    prompt_volume_max: i32,
    auto_shutdown_min: i32,
    eq_mode: i32,
    eq_json: QString,
    firmware_dongle: QString,
    firmware_headset: QString,
    /// Source of `eq_json`, kept to patch one mode after an EQ write.
    eq_names: Vec<String>,
    eq_states: Vec<Option<EqState>>,
    /// Bumped on every EQ write; only the newest read-back is applied.
    eq_write_seq: u64,
}

impl Default for HeadsetRust {
    fn default() -> Self {
        Self {
            busy: false,
            connected: false,
            error: QString::default(),
            error_detail: QString::default(),
            product: QString::default(),
            wired: false,
            battery_percent: -1,
            charging: false,
            asleep: false,
            prompt_volume: -1,
            prompt_volume_max: v9pro2_protocol::PROMPT_VOLUME_MAX as i32,
            auto_shutdown_min: -1,
            eq_mode: -1,
            eq_json: QString::from("[]"),
            firmware_dongle: QString::default(),
            firmware_headset: QString::default(),
            eq_names: Vec::new(),
            eq_states: Vec::new(),
            eq_write_seq: 0,
        }
    }
}

impl qobject::Headset {
    pub fn refresh(mut self: Pin<&mut Self>) {
        if *self.busy() {
            return;
        }
        self.as_mut().set_busy(true);
        let qt_thread = self.qt_thread();
        std::thread::spawn(move || {
            let result = device::read_snapshot();
            let _ = qt_thread.queue(move |mut obj| {
                obj.as_mut().apply(result);
                obj.as_mut().set_busy(false);
            });
        });
    }

    pub fn set_prompt_volume_on_device(mut self: Pin<&mut Self>, volume: i32) {
        let Ok(v) = u8::try_from(volume) else { return };
        self.as_mut().set_prompt_volume(volume);
        self.write(Write::PromptVolume(v));
    }

    pub fn set_eq_mode_on_device(mut self: Pin<&mut Self>, mode: i32) {
        let Ok(m) = u8::try_from(mode) else { return };
        self.as_mut().set_eq_mode(mode);
        self.write(Write::EqMode(m));
    }

    pub fn set_auto_shutdown_on_device(mut self: Pin<&mut Self>, minutes: i32) {
        let Ok(m) = u16::try_from(minutes) else { return };
        self.as_mut().set_auto_shutdown_min(minutes);
        self.write(Write::AutoShutdown(m));
    }

    pub fn set_eq_gains_on_device(mut self: Pin<&mut Self>, mode: i32, gains: &QString) {
        let tenths: Vec<i16> = String::from(gains)
            .split(',')
            .filter_map(|g| g.trim().parse::<f32>().ok())
            .map(|db| (db.clamp(-12.0, 12.0) * 10.0).round() as i16)
            .collect();
        let (Ok(mode), Ok(tenths)) = (u8::try_from(mode), <[i16; protocol::EQ_BANDS]>::try_from(tenths)) else {
            return;
        };
        let seq = self.rust().eq_write_seq + 1;
        self.as_mut().rust_mut().eq_write_seq = seq;
        let qt_thread = self.qt_thread();
        std::thread::spawn(move || {
            let result = device::write(Write::EqGains { mode, tenths });
            let _ = qt_thread.queue(move |mut obj| {
                if obj.rust().eq_write_seq != seq {
                    return; // a newer write is on its way
                }
                match result {
                    Ok(Written::Eq(Some(state))) => obj.as_mut().apply_eq_state(mode, state),
                    _ => obj.as_mut().refresh(),
                }
            });
        });
    }

    pub fn set_eq_name_on_device(mut self: Pin<&mut Self>, mode: i32, name: &QString) {
        let name = protocol::eq_name(&String::from(name));
        let Ok(mode) = u8::try_from(mode) else { return };
        if name.is_empty() || mode >= protocol::EQ_MODE_COUNT {
            return;
        }
        self.as_mut().apply_eq_name(mode, name.clone()); // shown right away, confirmed below
        let qt_thread = self.qt_thread();
        std::thread::spawn(move || {
            let result = device::write(Write::EqName { mode, name });
            let _ = qt_thread.queue(move |mut obj| match result {
                Ok(Written::Name(Some(name))) => obj.as_mut().apply_eq_name(mode, name),
                _ => obj.as_mut().refresh(),
            });
        });
    }

    /// Sends `w` on a worker thread; the ack sets the property, a failure re-reads everything.
    fn write(self: Pin<&mut Self>, w: Write) {
        let qt_thread = self.qt_thread();
        std::thread::spawn(move || {
            let result = device::write(w.clone());
            let _ = qt_thread.queue(move |mut obj| match result {
                Ok(Written::Ack(Some(ack))) => obj.as_mut().apply_ack(&w, &ack),
                _ => obj.as_mut().refresh(),
            });
        });
    }

    fn apply_eq_state(mut self: Pin<&mut Self>, mode: u8, state: EqState) {
        let json = {
            let mut rust = self.as_mut().rust_mut();
            let Some(slot) = rust.eq_states.get_mut(mode as usize) else { return };
            *slot = Some(state);
            eq_json(&rust.eq_names, &rust.eq_states)
        };
        self.as_mut().set_eq_json(QString::from(&json));
    }

    fn apply_eq_name(mut self: Pin<&mut Self>, mode: u8, name: String) {
        let json = {
            let mut rust = self.as_mut().rust_mut();
            let Some(slot) = rust.eq_names.get_mut(mode as usize) else { return };
            *slot = name;
            eq_json(&rust.eq_names, &rust.eq_states)
        };
        self.as_mut().set_eq_json(QString::from(&json));
    }

    fn apply_ack(mut self: Pin<&mut Self>, w: &Write, ack: &[u8]) {
        match w {
            Write::PromptVolume(_) => {
                if let Some(v) = protocol::decode_prompt_volume(ack) {
                    self.as_mut().set_prompt_volume(v.into());
                }
            }
            Write::EqMode(_) => {
                if let Some(m) = protocol::decode_current_eq_mode(ack) {
                    self.as_mut().set_eq_mode(m.into());
                }
            }
            Write::AutoShutdown(_) => {
                if let Some(m) = protocol::decode_auto_shutdown(ack) {
                    self.as_mut().set_auto_shutdown_min(m.into());
                }
            }
            Write::EqGains { .. } | Write::EqName { .. } => {}
        }
    }

    fn apply(mut self: Pin<&mut Self>, result: Result<Snapshot, device::Error>) {
        let s = match result {
            Ok(s) => s,
            Err(e) => {
                let (code, detail) = match e {
                    device::Error::NotFound => ("not_found", String::new()),
                    device::Error::Hid(d) => ("hid", d),
                };
                self.as_mut().set_connected(false);
                self.as_mut().set_error(QString::from(code));
                self.as_mut().set_error_detail(QString::from(&detail));
                return;
            }
        };
        let opt = |v: Option<i32>| v.unwrap_or(-1);
        let mut this = self.as_mut();
        this.as_mut().set_connected(true);
        this.as_mut().set_error(QString::default());
        this.as_mut().set_error_detail(QString::default());
        this.as_mut().set_product(QString::from(&s.product));
        this.as_mut().set_wired(s.wired);
        this.as_mut().set_battery_percent(opt(s.battery.as_ref().map(|b| b.percent as i32)));
        this.as_mut().set_charging(s.battery.as_ref().is_some_and(|b| b.charging));
        this.as_mut().set_asleep(s.battery.as_ref().is_some_and(|b| b.asleep));
        this.as_mut().set_prompt_volume(opt(s.prompt_volume.map(i32::from)));
        this.as_mut().set_auto_shutdown_min(opt(s.auto_shutdown_min.map(i32::from)));
        this.as_mut().set_eq_mode(opt(s.eq_mode.map(i32::from)));
        this.as_mut().set_eq_json(QString::from(&eq_json(&s.eq_names, &s.eq_states)));
        this.as_mut().set_firmware_dongle(QString::from(s.firmware_dongle.as_deref().unwrap_or("")));
        this.as_mut().set_firmware_headset(QString::from(s.firmware_headset.as_deref().unwrap_or("")));
        let mut rust = this.as_mut().rust_mut();
        rust.eq_names = s.eq_names;
        rust.eq_states = s.eq_states;
    }
}

fn json_str(s: &str) -> String {
    let mut out = String::from("\"");
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

fn eq_json(names: &[String], states: &[Option<EqState>]) -> String {
    let modes: Vec<String> = names
        .iter()
        .zip(states)
        .map(|(name, state)| {
            let points: Vec<String> = state
                .iter()
                .flat_map(|st| &st.points)
                .map(|p| {
                    format!(
                        r#"{{"fc":{},"gain":{},"q":{},"type":{},"enable":{}}}"#,
                        p.fc, p.gain_db, p.q, p.filter_type, p.enable
                    )
                })
                .collect();
            format!(r#"{{"name":{},"points":[{}]}}"#, json_str(name), points.join(","))
        })
        .collect();
    format!("[{}]", modes.join(","))
}
