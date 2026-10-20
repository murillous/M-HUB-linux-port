//! `MicFx` QML object: microphone effects that run in PipeWire (Linux).
//!
//! - Noise reduction: the MCHOSE HUB runs DeepFilterNet3 inside the THX APO. Here the official
//!   DeepFilterNet LADSPA plugin runs in a filter-chain whose virtual source becomes the default mic.
//! - Monitoring: a loopback from the headset mic to the headset output that asks for a tiny quantum.
//!
//! Each effect is a detached `pipewire -c <conf>` process, so it keeps running after the window is
//! closed. Config, pid and log files live in `$XDG_RUNTIME_DIR/mchose-v9/`.

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
        /// PipeWire tools present and the headset mic found.
        #[qproperty(bool, available)]
        /// DeepFilterNet LADSPA plugin found (see tools/install-deepfilter.py).
        #[qproperty(bool, nr_installed)]
        #[qproperty(bool, noise_reduction)]
        #[qproperty(bool, monitoring)]
        #[qproperty(bool, busy)]
        /// "" when ok, else the effect that failed to start: "nr" or "monitor" (see `error_detail`).
        #[qproperty(QString, error)]
        #[qproperty(QString, error_detail)]
        type MicFx = super::MicFxRust;

        /// Checks tools, plugin and which effects are running (on a background thread).
        #[qinvokable]
        fn refresh(self: Pin<&mut MicFx>);
        #[qinvokable]
        fn enable_noise_reduction(self: Pin<&mut MicFx>, on: bool);
        #[qinvokable]
        fn enable_monitoring(self: Pin<&mut MicFx>, on: bool);
    }

    impl cxx_qt::Threading for MicFx {}
}

use core::pin::Pin;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::sync::Mutex;
use std::time::Duration;

use cxx_qt::Threading;
use cxx_qt_lib::QString;

use crate::mixer::{find_node_id, find_nodes, wpctl, Node};

/// Virtual source with the denoised mic.
const NR_NODE: &str = "mchose_v9_mic_nr";
/// Playback side of the monitoring loopback.
const MONITOR_NODE: &str = "mchose_v9_mic_monitor";
/// Same values as the THX APO: `df_set_atten_lim(level 0.65 × max attenuation 60 dB)` and
/// `df_set_post_filter_beta(0.04)` [obs].
const NR_ATTEN_LIM_DB: f32 = 39.0;
const NR_POST_FILTER_BETA: f32 = 0.04;
/// Quantum asked for while monitoring the raw mic: 64 samples at 48 kHz = 1.3 ms per graph cycle.
const MONITOR_LATENCY: &str = "64/48000";
/// Monitoring through noise reduction: DeepFilterNet works on 10 ms frames (480 samples), so each
/// cycle must leave time for a whole frame or it xruns. Adds ~20 ms to the plugin's own ~20 ms.
const MONITOR_LATENCY_NR: &str = "512/48000";
const PLUGIN_FILE: &str = "libdeep_filter_ladspa.so";

/// Processes started by this run of the app, kept only to reap them once they exit.
static CHILDREN: Mutex<Vec<Child>> = Mutex::new(Vec::new());

#[derive(Default)]
pub struct MicFxRust {
    available: bool,
    nr_installed: bool,
    noise_reduction: bool,
    monitoring: bool,
    busy: bool,
    error: QString,
    error_detail: QString,
}

#[derive(Clone, Copy, PartialEq)]
enum Fx {
    NoiseReduction,
    Monitoring,
}

impl Fx {
    fn file(self) -> &'static str {
        match self {
            Fx::NoiseReduction => "nr",
            Fx::Monitoring => "monitor",
        }
    }

    fn node(self) -> &'static str {
        match self {
            Fx::NoiseReduction => NR_NODE,
            Fx::Monitoring => MONITOR_NODE,
        }
    }
}

struct Status {
    available: bool,
    nr_installed: bool,
    noise_reduction: bool,
    monitoring: bool,
}

impl qobject::MicFx {
    pub fn refresh(self: Pin<&mut Self>) {
        self.run(|| Ok(()));
    }

    pub fn enable_noise_reduction(self: Pin<&mut Self>, on: bool) {
        self.run(move || if on { start_noise_reduction() } else { stop_noise_reduction() });
    }

    pub fn enable_monitoring(self: Pin<&mut Self>, on: bool) {
        self.run(move || if on { start_monitoring() } else { stop(Fx::Monitoring) });
    }

    /// Runs `action` on a worker thread, then publishes the error (if any) and the new status.
    fn run(mut self: Pin<&mut Self>, action: impl FnOnce() -> Result<(), (Fx, String)> + Send + 'static) {
        if *self.busy() {
            return;
        }
        self.as_mut().set_busy(true);
        let qt_thread = self.qt_thread();
        std::thread::spawn(move || {
            let result = action();
            let status = status();
            let _ = qt_thread.queue(move |mut obj| {
                let (error, detail) = match result {
                    Ok(()) => (String::new(), String::new()),
                    Err((fx, detail)) => (fx.file().to_owned(), detail),
                };
                obj.as_mut().set_error(QString::from(error.as_str()));
                obj.as_mut().set_error_detail(QString::from(detail.as_str()));
                obj.as_mut().set_available(status.available);
                obj.as_mut().set_nr_installed(status.nr_installed);
                obj.as_mut().set_noise_reduction(status.noise_reduction);
                obj.as_mut().set_monitoring(status.monitoring);
                obj.as_mut().set_busy(false);
            });
        });
    }
}

fn status() -> Status {
    let tools = run_dir().is_some() && Command::new("pipewire").arg("--version").output().is_ok_and(|o| o.status.success());
    Status {
        available: tools && find_nodes().1.is_some(),
        nr_installed: plugin_path().is_some(),
        noise_reduction: running(Fx::NoiseReduction),
        monitoring: running(Fx::Monitoring),
    }
}

fn start_noise_reduction() -> Result<(), (Fx, String)> {
    let fx = Fx::NoiseReduction;
    let plugin = plugin_path().ok_or((fx, format!("{PLUGIN_FILE} not found")))?;
    let source = find_nodes().1.ok_or((fx, "headset microphone not found".into()))?;
    let id = start(fx, &nr_conf(&plugin, &source.name))?;
    // Apps that use the default mic get the denoised one, like the APO on Windows.
    wpctl(&["set-default", &id.to_string()]);
    follow_noise_reduction()
}

fn stop_noise_reduction() -> Result<(), (Fx, String)> {
    if let Some(Node { id, .. }) = find_nodes().1 {
        wpctl(&["set-default", &id.to_string()]);
    }
    stop(Fx::NoiseReduction)?;
    follow_noise_reduction()
}

/// Monitoring plays what the denoised source sends while noise reduction is on, so restart it
/// whenever noise reduction changes.
fn follow_noise_reduction() -> Result<(), (Fx, String)> {
    if running(Fx::Monitoring) { start_monitoring() } else { Ok(()) }
}

fn start_monitoring() -> Result<(), (Fx, String)> {
    let fx = Fx::Monitoring;
    let (Some(sink), Some(source)) = find_nodes() else {
        return Err((fx, "headset not found in PipeWire".into()));
    };
    let conf = if running(Fx::NoiseReduction) {
        monitor_conf(NR_NODE, &sink.name, MONITOR_LATENCY_NR)
    } else {
        monitor_conf(&source.name, &sink.name, MONITOR_LATENCY)
    };
    start(fx, &conf).map(|_| ())
}

// ── processes ──────────────────────────────────────────────────────────────

fn run_dir() -> Option<PathBuf> {
    if !cfg!(unix) {
        return None;
    }
    Some(PathBuf::from(std::env::var_os("XDG_RUNTIME_DIR")?).join("mchose-v9"))
}

fn paths(fx: Fx) -> Option<(PathBuf, PathBuf, PathBuf)> {
    let dir = run_dir()?;
    let name = fx.file();
    Some((dir.join(format!("{name}.conf")), dir.join(format!("{name}.pid")), dir.join(format!("{name}.log"))))
}

/// Pid of the effect's process, if it is still ours and alive.
fn pid(fx: Fx) -> Option<u32> {
    let (conf, pid_file, _) = paths(fx)?;
    let pid: u32 = std::fs::read_to_string(pid_file).ok()?.trim().parse().ok()?;
    let cmdline = std::fs::read(format!("/proc/{pid}/cmdline")).ok()?;
    let conf = conf.to_string_lossy();
    cmdline.split(|&b| b == 0).any(|arg| arg == conf.as_bytes()).then_some(pid)
}

fn running(fx: Fx) -> bool {
    pid(fx).is_some()
}

/// (Re)starts the effect's process with `conf` and waits for its node; returns the node id.
fn start(fx: Fx, conf: &str) -> Result<u32, (Fx, String)> {
    let err = |e: String| (fx, e);
    let (conf_path, pid_file, log_path) = paths(fx).ok_or_else(|| err("XDG_RUNTIME_DIR not set".into()))?;
    stop(fx)?;
    std::fs::create_dir_all(conf_path.parent().unwrap_or(Path::new("/"))).map_err(|e| err(e.to_string()))?;
    std::fs::write(&conf_path, conf).map_err(|e| err(e.to_string()))?;
    let log = std::fs::File::create(&log_path).map_err(|e| err(e.to_string()))?;
    let mut cmd = Command::new("pipewire");
    cmd.arg("-c").arg(&conf_path).stdin(Stdio::null()).stdout(Stdio::null()).stderr(log);
    #[cfg(unix)]
    {
        // Own process group: not killed with the app (e.g. Ctrl+C in the terminal).
        use std::os::unix::process::CommandExt;
        cmd.process_group(0);
    }
    let child = cmd.spawn().map_err(|e| err(format!("pipewire: {e}")))?;
    std::fs::write(&pid_file, child.id().to_string()).map_err(|e| err(e.to_string()))?;
    CHILDREN.lock().unwrap_or_else(|e| e.into_inner()).push(child);
    for _ in 0..30 {
        std::thread::sleep(Duration::from_millis(100));
        if !running(fx) {
            break;
        }
        if let Some(id) = find_node_id(fx.node()) {
            return Ok(id);
        }
    }
    let _ = stop(fx);
    Err(err(log_tail(&log_path)))
}

fn stop(fx: Fx) -> Result<(), (Fx, String)> {
    if let Some(pid) = pid(fx) {
        let killed = Command::new("kill").arg(pid.to_string()).status().is_ok_and(|s| s.success());
        if !killed {
            return Err((fx, format!("could not stop process {pid}")));
        }
    }
    if let Some((_, pid_file, _)) = paths(fx) {
        let _ = std::fs::remove_file(pid_file);
    }
    CHILDREN.lock().unwrap_or_else(|e| e.into_inner()).retain_mut(|c| matches!(c.try_wait(), Ok(None)));
    Ok(())
}

fn log_tail(path: &Path) -> String {
    let log = std::fs::read_to_string(path).unwrap_or_default();
    let lines: Vec<&str> = log.lines().filter(|l| !l.trim().is_empty()).collect();
    let tail = lines[lines.len().saturating_sub(3)..].join("\n");
    if tail.is_empty() { format!("pipewire exited, see {}", path.display()) } else { tail }
}

/// `$LADSPA_PATH` first, then the usual places (the install script uses ~/.local/lib/ladspa).
fn plugin_path() -> Option<PathBuf> {
    let mut dirs: Vec<PathBuf> = std::env::var_os("LADSPA_PATH")
        .map(|p| std::env::split_paths(&p).collect())
        .unwrap_or_default();
    if let Some(home) = std::env::var_os("HOME").map(PathBuf::from) {
        dirs.push(home.join(".local/lib/ladspa"));
        dirs.push(home.join(".ladspa"));
    }
    dirs.extend(["/usr/local/lib/ladspa", "/usr/lib64/ladspa", "/usr/lib/ladspa"].map(PathBuf::from));
    dirs.into_iter().map(|d| d.join(PLUGIN_FILE)).find(|p| p.is_file())
}

// ── configs ────────────────────────────────────────────────────────────────

/// SPA-JSON string literal.
fn quote(s: &str) -> String {
    format!("\"{}\"", s.replace('\\', "\\\\").replace('"', "\\\""))
}

/// Client-only PipeWire config that loads `module` (like /usr/share/pipewire/filter-chain.conf).
fn client_conf(module: &str, args: &str) -> String {
    format!(
        r#"# Generated by mchose-v9; rewritten each time the effect is turned on.
context.properties = {{
    log.level = 2
}}
context.spa-libs = {{
    audio.convert.* = audioconvert/libspa-audioconvert
    support.*       = support/libspa-support
}}
context.modules = [
    {{ name = libpipewire-module-rt
        args = {{ nice.level = -11 }}
        flags = [ ifexists nofail ]
    }}
    {{ name = libpipewire-module-protocol-native }}
    {{ name = libpipewire-module-client-node }}
    {{ name = libpipewire-module-adapter }}
    {{ name = {module}
        args = {{
{args}
        }}
    }}
]
"#
    )
}

fn nr_conf(plugin: &Path, source: &str) -> String {
    let args = format!(
        r#"            node.description = "MCHOSE V9 Pro 2 Microphone (AI noise reduction)"
            media.name = "MCHOSE V9 Pro 2 Microphone (AI noise reduction)"
            filter.graph = {{
                nodes = [
                    {{
                        type = ladspa
                        name = deepfilter
                        plugin = {plugin}
                        label = deep_filter_mono
                        control = {{
                            "Attenuation Limit (dB)" = {NR_ATTEN_LIM_DB}
                            "Post Filter Beta" = {NR_POST_FILTER_BETA}
                        }}
                    }}
                ]
            }}
            audio.rate = 48000
            audio.position = [ MONO ]
            capture.props = {{
                node.name = "{NR_NODE}.capture"
                target.object = {source}
                node.dont-fallback = true
                node.passive = true
            }}
            playback.props = {{
                node.name = "{NR_NODE}"
                media.class = Audio/Source
            }}"#,
        plugin = quote(&plugin.to_string_lossy()),
        source = quote(source),
    );
    client_conf("libpipewire-module-filter-chain", &args)
}

/// Mic (raw or denoised) straight to the headset. Both streams ask for `latency`, so the whole
/// graph runs with that quantum while monitoring is on.
fn monitor_conf(source: &str, sink: &str, latency: &str) -> String {
    let args = format!(
        r#"            node.description = "MCHOSE V9 Pro 2 Microphone monitoring"
            audio.position = [ MONO ]
            capture.props = {{
                node.name = "{MONITOR_NODE}.capture"
                target.object = {source}
                node.dont-fallback = true
                node.latency = {latency}
            }}
            playback.props = {{
                node.name = "{MONITOR_NODE}"
                node.description = "Microphone monitoring"
                target.object = {sink}
                node.dont-fallback = true
                node.latency = {latency}
            }}"#,
        source = quote(source),
        sink = quote(sink),
    );
    client_conf("libpipewire-module-loopback", &args)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn quoting() {
        assert_eq!(quote(r#"a"b\c"#), r#""a\"b\\c""#);
    }

    #[test]
    fn nr_config() {
        let conf = nr_conf(Path::new("/home/u/.local/lib/ladspa/libdeep_filter_ladspa.so"), "alsa_input.usb-x");
        assert!(conf.contains(r#"plugin = "/home/u/.local/lib/ladspa/libdeep_filter_ladspa.so""#));
        assert!(conf.contains(r#""Attenuation Limit (dB)" = 39"#));
        assert!(conf.contains(r#""Post Filter Beta" = 0.04"#));
        assert!(conf.contains(r#"target.object = "alsa_input.usb-x""#));
        assert!(conf.contains("name = libpipewire-module-filter-chain"));
        assert_eq!(conf.matches('{').count(), conf.matches('}').count());
    }

    #[test]
    fn monitor_config() {
        let conf = monitor_conf("alsa_input.usb-x", "alsa_output.usb-x", MONITOR_LATENCY);
        assert!(conf.contains(r#"target.object = "alsa_output.usb-x""#));
        assert_eq!(conf.matches("node.latency = 64/48000").count(), 2);
        let conf = monitor_conf(NR_NODE, "alsa_output.usb-x", MONITOR_LATENCY_NR);
        assert!(conf.contains(r#"target.object = "mchose_v9_mic_nr""#));
        assert_eq!(conf.matches("node.latency = 512/48000").count(), 2);
        assert!(conf.contains("name = libpipewire-module-loopback"));
        assert_eq!(conf.matches('{').count(), conf.matches('}').count());
    }
}
