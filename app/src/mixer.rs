//! `Mixer` QML object: volume and mute of the headset's PipeWire sink and source.
//!
//! Nodes are found with `pw-dump` and driven with `wpctl` (both ship with PipeWire on Fedora).
//! Volumes use wpctl's scale, the same percentages the KDE volume applet shows.
//! Where the tools are missing (Windows) `available` stays false.

#[cxx_qt::bridge]
pub mod qobject {
    #[auto_cxx_name]
    extern "RustQt" {
        #[qobject]
        #[qml_element]
        /// Headset sink or source found in PipeWire.
        #[qproperty(bool, available)]
        /// 0..=100, -1 = unknown / not found.
        #[qproperty(i32, output_volume)]
        #[qproperty(bool, output_muted)]
        #[qproperty(i32, input_volume)]
        #[qproperty(bool, input_muted)]
        type Mixer = super::MixerRust;

        /// Looks the headset nodes up again and reads them (on a background thread).
        #[qinvokable]
        fn refresh(self: Pin<&mut Mixer>);
        /// Re-reads the known nodes, to follow changes made elsewhere (e.g. the KDE applet).
        #[qinvokable]
        fn poll(self: Pin<&mut Mixer>);
        /// `input`: microphone instead of headphones. `percent`: 0..=100.
        #[qinvokable]
        fn set_volume(self: Pin<&mut Mixer>, input: bool, percent: i32);
        #[qinvokable]
        fn toggle_mute(self: Pin<&mut Mixer>, input: bool);
    }

    impl cxx_qt::Threading for Mixer {}
}

use core::pin::Pin;
use std::process::Command;
use std::sync::Mutex;

use cxx_qt::{CxxQtType, Threading};

/// One command at a time, so a set is never overtaken by an older one.
static LOCK: Mutex<()> = Mutex::new(());

/// Part of the ALSA node names of the headset (`alsa_output.usb-bestechnic_MCHOSE_V9_Pro_2-00…`).
const NODE_NAME: &str = "MCHOSE_V9_Pro_2";

pub struct MixerRust {
    available: bool,
    output_volume: i32,
    output_muted: bool,
    input_volume: i32,
    input_muted: bool,
    sink: Option<u32>,
    source: Option<u32>,
    /// Bumped on every set; reads started before it are dropped.
    seq: u64,
    busy: bool,
}

impl Default for MixerRust {
    fn default() -> Self {
        Self {
            available: false,
            output_volume: -1,
            output_muted: false,
            input_volume: -1,
            input_muted: false,
            sink: None,
            source: None,
            seq: 0,
            busy: false,
        }
    }
}

#[derive(Clone, Copy)]
struct Level {
    percent: i32,
    muted: bool,
}

struct Reading {
    sink: Option<u32>,
    source: Option<u32>,
    output: Option<Level>,
    input: Option<Level>,
}

impl qobject::Mixer {
    pub fn refresh(self: Pin<&mut Self>) {
        self.read(true);
    }

    pub fn poll(self: Pin<&mut Self>) {
        if self.rust().sink.is_some() || self.rust().source.is_some() {
            self.read(false);
        }
    }

    pub fn set_volume(mut self: Pin<&mut Self>, input: bool, percent: i32) {
        let Some(id) = self.node(input) else { return };
        let percent = percent.clamp(0, 100);
        if input {
            self.as_mut().set_input_volume(percent);
        } else {
            self.as_mut().set_output_volume(percent);
        }
        self.send(input, vec!["set-volume".into(), id.to_string(), format!("{:.2}", percent as f32 / 100.0)]);
    }

    pub fn toggle_mute(mut self: Pin<&mut Self>, input: bool) {
        let Some(id) = self.node(input) else { return };
        if input {
            let muted = !*self.input_muted();
            self.as_mut().set_input_muted(muted);
        } else {
            let muted = !*self.output_muted();
            self.as_mut().set_output_muted(muted);
        }
        self.send(input, vec!["set-mute".into(), id.to_string(), "toggle".into()]);
    }

    fn node(&self, input: bool) -> Option<u32> {
        if input { self.rust().source } else { self.rust().sink }
    }

    /// Runs `wpctl args` on a worker thread, then reads that node back.
    fn send(mut self: Pin<&mut Self>, input: bool, args: Vec<String>) {
        let seq = self.rust().seq + 1;
        self.as_mut().rust_mut().seq = seq;
        let Some(id) = self.node(input) else { return };
        let qt_thread = self.qt_thread();
        std::thread::spawn(move || {
            let level = {
                let _guard = LOCK.lock().unwrap_or_else(|e| e.into_inner());
                wpctl(&args.iter().map(String::as_str).collect::<Vec<_>>());
                get_volume(id)
            };
            let _ = qt_thread.queue(move |mut obj| {
                if obj.rust().seq != seq {
                    return; // a newer set is on its way
                }
                match level {
                    Some(l) => obj.as_mut().apply_level(input, Some(l)),
                    None => obj.as_mut().refresh(), // node gone (headset unplugged?)
                }
            });
        });
    }

    fn read(mut self: Pin<&mut Self>, lookup: bool) {
        if self.rust().busy {
            return;
        }
        self.as_mut().rust_mut().busy = true;
        let (seq, known) = (self.rust().seq, (self.rust().sink, self.rust().source));
        let qt_thread = self.qt_thread();
        std::thread::spawn(move || {
            let reading = {
                let _guard = LOCK.lock().unwrap_or_else(|e| e.into_inner());
                let (sink, source) = if lookup { find_nodes() } else { known };
                Reading { sink, source, output: sink.and_then(get_volume), input: source.and_then(get_volume) }
            };
            let _ = qt_thread.queue(move |mut obj| {
                obj.as_mut().rust_mut().busy = false;
                if obj.rust().seq != seq {
                    return; // stale: a set happened meanwhile
                }
                let lost = !lookup && (reading.output.is_none() && known.0.is_some()
                    || reading.input.is_none() && known.1.is_some());
                if lost {
                    obj.as_mut().refresh();
                    return;
                }
                {
                    let mut rust = obj.as_mut().rust_mut();
                    rust.sink = reading.sink.filter(|_| reading.output.is_some());
                    rust.source = reading.source.filter(|_| reading.input.is_some());
                }
                obj.as_mut().set_available(reading.output.is_some() || reading.input.is_some());
                obj.as_mut().apply_level(false, reading.output);
                obj.as_mut().apply_level(true, reading.input);
            });
        });
    }

    fn apply_level(mut self: Pin<&mut Self>, input: bool, level: Option<Level>) {
        let (percent, muted) = level.map_or((-1, false), |l| (l.percent, l.muted));
        if input {
            self.as_mut().set_input_volume(percent);
            self.as_mut().set_input_muted(muted);
        } else {
            self.as_mut().set_output_volume(percent);
            self.as_mut().set_output_muted(muted);
        }
    }
}

fn wpctl(args: &[&str]) -> Option<String> {
    let out = Command::new("wpctl").args(args).output().ok()?;
    out.status.success().then(|| String::from_utf8_lossy(&out.stdout).into_owned())
}

/// `wpctl get-volume` prints `Volume: 0.40` or `Volume: 0.40 [MUTED]`.
fn get_volume(id: u32) -> Option<Level> {
    parse_volume(&wpctl(&["get-volume", &id.to_string()])?)
}

fn parse_volume(s: &str) -> Option<Level> {
    let v: f32 = s.trim().strip_prefix("Volume:")?.split_whitespace().next()?.parse().ok()?;
    Some(Level { percent: (v * 100.0).round().clamp(0.0, 100.0) as i32, muted: s.contains("[MUTED]") })
}

/// `(sink, source)` node ids of the headset.
fn find_nodes() -> (Option<u32>, Option<u32>) {
    let Some(out) = Command::new("pw-dump").output().ok().filter(|o| o.status.success()) else {
        return (None, None);
    };
    parse_nodes(&out.stdout)
}

fn parse_nodes(json: &[u8]) -> (Option<u32>, Option<u32>) {
    let Ok(serde_json::Value::Array(objects)) = serde_json::from_slice(json) else { return (None, None) };
    let find = |class: &str| {
        objects.iter().find_map(|o| {
            let props = o.pointer("/info/props")?;
            let name = props.get("node.name")?.as_str()?;
            (props.get("media.class")?.as_str()? == class && name.contains(NODE_NAME))
                .then(|| o.get("id")?.as_u64()?.try_into().ok())?
        })
    };
    (find("Audio/Sink"), find("Audio/Source"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn volume() {
        let l = parse_volume("Volume: 0.40\n").unwrap();
        assert_eq!((l.percent, l.muted), (40, false));
        let l = parse_volume("Volume: 1.00 [MUTED]\n").unwrap();
        assert_eq!((l.percent, l.muted), (100, true));
        assert!(parse_volume("").is_none());
    }

    #[test]
    fn nodes() {
        let json = br#"[
            {"id": 30, "type": "PipeWire:Interface:Node", "info": {"props": {
                "node.name": "alsa_output.pci-0000_00_1f.3.analog-stereo", "media.class": "Audio/Sink"}}},
            {"id": 31, "type": "PipeWire:Interface:Device", "info": {"props": {
                "device.name": "alsa_card.usb-bestechnic_MCHOSE_V9_Pro_2-00"}}},
            {"id": 57, "type": "PipeWire:Interface:Node", "info": {"props": {
                "node.name": "alsa_output.usb-bestechnic_MCHOSE_V9_Pro_2-00.analog-stereo", "media.class": "Audio/Sink"}}},
            {"id": 58, "type": "PipeWire:Interface:Node", "info": {"props": {
                "node.name": "alsa_input.usb-bestechnic_MCHOSE_V9_Pro_2-00.mono-fallback", "media.class": "Audio/Source"}}}
        ]"#;
        assert_eq!(parse_nodes(json), (Some(57), Some(58)));
        assert_eq!(parse_nodes(b"[]"), (None, None));
    }
}
