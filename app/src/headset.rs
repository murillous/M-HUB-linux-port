//! `Headset` QML object: exposes the headset state read over HID.

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
    }

    impl cxx_qt::Threading for Headset {}
}

use core::pin::Pin;

use cxx_qt::Threading;
use cxx_qt_lib::QString;

use crate::device::{self, Snapshot};

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
        this.as_mut().set_eq_json(QString::from(&eq_json(&s)));
        this.as_mut().set_firmware_dongle(QString::from(s.firmware_dongle.as_deref().unwrap_or("")));
        this.as_mut().set_firmware_headset(QString::from(s.firmware_headset.as_deref().unwrap_or("")));
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

fn eq_json(s: &Snapshot) -> String {
    let modes: Vec<String> = s
        .eq_names
        .iter()
        .zip(&s.eq_states)
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
