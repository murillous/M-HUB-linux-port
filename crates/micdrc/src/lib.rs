//! Mic volume leveling of the MCHOSE V9 Pro 2, done the way the THX APO does it. See
//! `docs/03-mapa-de-settings.md` ("Cadeia do mic e o compressor ssDRC").
//!
//! Soft-knee peak compressor that smooths the gain (not the level), with its parameters
//! interpolated from a per-level table, followed by the always-on output limiter. Exposed as a
//! LADSPA plugin for the PipeWire filter-chain (`label = leveling`).

use std::ffi::{c_char, c_int, c_ulong, c_void};
use std::ptr;

/// dB → natural log (the THX kernel works in ln units).
const LN10_20: f64 = std::f64::consts::LN_10 / 20.0;
/// Floor of the peak detector, so silence does not hit ln(0).
const DETECTOR_FLOOR: f64 = 1e-12;
/// Level slider moves 0→100 in this time.
const LEVEL_RAMP_S: f64 = 0.2;
/// On/off crossfade.
const MIX_RAMP_S: f64 = 0.1;
pub const LEVEL_MAX: f64 = 100.0;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct DrcParams {
    pub threshold_db: f64,
    /// Knee width, centred on the threshold.
    pub width_db: f64,
    pub ratio: f64,
    pub pre_gain_db: f64,
    /// Makeup gain.
    pub gain_db: f64,
    pub attack_ms: f64,
    pub decay_ms: f64,
}

const fn drc(threshold_db: f64, width_db: f64, ratio: f64, gain_db: f64, attack_ms: f64, decay_ms: f64) -> DrcParams {
    DrcParams { threshold_db, width_db, ratio, pre_gain_db: 0.0, gain_db, attack_ms, decay_ms }
}

/// `mic_volume_leveling` table of the V9 Pro 2 (`props.dat`), by level 0–100.
pub const LEVELING: [(u32, DrcParams); 6] = [
    (0, drc(-6.0, 4.0, 2.0, 3.0, 5.0, 250.0)),
    (20, drc(-11.0, 5.0, 2.2, 6.0, 5.0, 300.0)),
    (40, drc(-15.5, 6.0, 2.4, 9.0, 6.0, 350.0)),
    (60, drc(-19.5, 7.0, 2.6, 12.0, 8.0, 450.0)),
    (80, drc(-23.5, 8.0, 2.8, 15.0, 10.0, 550.0)),
    (100, drc(-27.0, 9.0, 3.0, 18.0, 10.0, 700.0)),
];

/// Last-resort limiter at the end of the THX mic chain.
pub const LIMITER: DrcParams = drc(-1.0, 0.5, 7.0, 0.0, 0.1, 100.0);

/// Exact table entry, or every field interpolated linearly between the neighbouring levels.
pub fn leveling_for(level: u32) -> DrcParams {
    let level = level.min(LEVEL_MAX as u32);
    let i = LEVELING.iter().position(|(l, _)| *l >= level).unwrap_or(LEVELING.len() - 1);
    let (l1, p1) = LEVELING[i];
    if l1 == level || i == 0 {
        return p1;
    }
    let (l0, p0) = LEVELING[i - 1];
    let t = (level - l0) as f64 / (l1 - l0) as f64;
    let lerp = |a: f64, b: f64| a + (b - a) * t;
    DrcParams {
        threshold_db: lerp(p0.threshold_db, p1.threshold_db),
        width_db: lerp(p0.width_db, p1.width_db),
        ratio: lerp(p0.ratio, p1.ratio),
        pre_gain_db: lerp(p0.pre_gain_db, p1.pre_gain_db),
        gain_db: lerp(p0.gain_db, p1.gain_db),
        attack_ms: lerp(p0.attack_ms, p1.attack_ms),
        decay_ms: lerp(p0.decay_ms, p1.decay_ms),
    }
}

/// One THX DRC band: per-sample peak detector, soft-knee curve and attack/decay gain smoother.
#[derive(Debug, Clone)]
pub struct Drc {
    fs: f64,
    threshold: f64,
    half_width: f64,
    inv_ratio: f64,
    pre_gain: f64,
    makeup: f64,
    attack: f64,
    decay: f64,
    /// Smoothed gain, ln units.
    gain: f64,
}

impl Drc {
    pub fn new(fs: f64, p: DrcParams) -> Self {
        let mut d = Drc { fs, threshold: 0.0, half_width: 0.0, inv_ratio: 1.0, pre_gain: 1.0, makeup: 0.0, attack: 1.0, decay: 1.0, gain: 0.0 };
        d.set(p);
        d
    }

    pub fn set(&mut self, p: DrcParams) {
        let coef = |ms: f64| 1.0 - (-1000.0 / (self.fs * ms)).exp();
        self.threshold = p.threshold_db * LN10_20;
        self.half_width = p.width_db * LN10_20 * 0.5;
        self.inv_ratio = 1.0 / p.ratio;
        self.pre_gain = (p.pre_gain_db * LN10_20).exp();
        self.makeup = p.gain_db * LN10_20;
        self.attack = coef(p.attack_ms);
        self.decay = coef(p.decay_ms);
    }

    /// Static curve: gain (ln units) for a detector level `x` (ln units).
    fn curve(&self, x: f64) -> f64 {
        let (t, h) = (self.threshold, self.half_width);
        let y = if x < t - h {
            x
        } else if x > t + h {
            t + (x - t) * self.inv_ratio
        } else {
            let d = x - t + h;
            x + (self.inv_ratio - 1.0) * d * d / (4.0 * h)
        };
        y - x
    }

    pub fn process(&mut self, input: f64) -> f64 {
        let x = input * self.pre_gain;
        let g = self.curve(x.abs().max(DETECTOR_FLOOR).ln());
        let a = if g < self.gain { self.attack } else { self.decay };
        self.gain += a * (g - self.gain);
        x * (self.gain + self.makeup).exp()
    }
}

/// Leveling (with level ramp and on/off crossfade) followed by the limiter.
#[derive(Debug, Clone)]
pub struct Leveler {
    leveling: Drc,
    limiter: Drc,
    level: f64,
    level_step: f64,
    applied_level: Option<u32>,
    mix: f64,
    mix_step: f64,
}

impl Leveler {
    pub fn new(fs: f64) -> Self {
        Leveler {
            leveling: Drc::new(fs, leveling_for(0)),
            limiter: Drc::new(fs, LIMITER),
            level: 0.0,
            level_step: LEVEL_MAX / (fs * LEVEL_RAMP_S),
            applied_level: None,
            mix: 0.0,
            mix_step: 1.0 / (fs * MIX_RAMP_S),
        }
    }

    /// Starts at the given settings instead of ramping to them.
    pub fn reset(&mut self, level: f64, enabled: bool) {
        self.level = level.clamp(0.0, LEVEL_MAX);
        self.applied_level = None;
        self.mix = if enabled { 1.0 } else { 0.0 };
    }

    /// Like the APO: the level moves once per block and the DRC follows its integer part.
    pub fn run(&mut self, level: f64, enabled: bool, input: &[f32], output: &mut [f32]) {
        let n = input.len().min(output.len());
        let target = level.clamp(0.0, LEVEL_MAX);
        let max_step = self.level_step * n as f64;
        self.level += (target - self.level).clamp(-max_step, max_step);
        let int_level = self.level as u32;
        if self.applied_level != Some(int_level) {
            self.leveling.set(leveling_for(int_level));
            self.applied_level = Some(int_level);
        }
        let mix_target = if enabled { 1.0 } else { 0.0 };
        for (i, o) in input[..n].iter().zip(&mut output[..n]) {
            let dry = *i as f64;
            let wet = self.leveling.process(dry);
            self.mix += (mix_target - self.mix).clamp(-self.mix_step, self.mix_step);
            *o = self.limiter.process(dry + (wet - dry) * self.mix) as f32;
        }
    }
}

// ── LADSPA ─────────────────────────────────────────────────────────────────

const PORT_INPUT: c_int = 1;
const PORT_OUTPUT: c_int = 2;
const PORT_CONTROL: c_int = 4;
const PORT_AUDIO: c_int = 8;
const HINT_BOUNDED_BELOW: c_int = 0x1;
const HINT_BOUNDED_ABOVE: c_int = 0x2;
const HINT_TOGGLED: c_int = 0x4;
const HINT_DEFAULT_LOW: c_int = 0x80;
const HINT_DEFAULT_1: c_int = 0x240;
const PROPERTY_HARD_RT_CAPABLE: c_int = 0x4;

const PORT_IN: c_ulong = 0;
const PORT_OUT: c_ulong = 1;
const PORT_LEVEL: c_ulong = 2;
const PORT_ENABLED: c_ulong = 3;
const PORT_COUNT: usize = 4;

#[repr(C)]
pub struct PortRangeHint {
    hint: c_int,
    lower: f32,
    upper: f32,
}

type Handle = *mut c_void;

#[repr(C)]
pub struct Descriptor {
    unique_id: c_ulong,
    label: *const c_char,
    properties: c_int,
    name: *const c_char,
    maker: *const c_char,
    copyright: *const c_char,
    port_count: c_ulong,
    port_descriptors: *const c_int,
    port_names: *const *const c_char,
    port_range_hints: *const PortRangeHint,
    implementation_data: *mut c_void,
    instantiate: unsafe extern "C" fn(*const Descriptor, c_ulong) -> Handle,
    connect_port: unsafe extern "C" fn(Handle, c_ulong, *mut f32),
    activate: Option<unsafe extern "C" fn(Handle)>,
    run: unsafe extern "C" fn(Handle, c_ulong),
    run_adding: Option<unsafe extern "C" fn(Handle, c_ulong)>,
    set_run_adding_gain: Option<unsafe extern "C" fn(Handle, f32)>,
    deactivate: Option<unsafe extern "C" fn(Handle)>,
    cleanup: unsafe extern "C" fn(Handle),
}

/// The pointers only reference immutable statics.
struct Static<T>(T);
unsafe impl<T> Sync for Static<T> {}

static PORT_DESCRIPTORS: [c_int; PORT_COUNT] =
    [PORT_INPUT | PORT_AUDIO, PORT_OUTPUT | PORT_AUDIO, PORT_INPUT | PORT_CONTROL, PORT_INPUT | PORT_CONTROL];
static PORT_NAMES: Static<[*const c_char; PORT_COUNT]> =
    Static([c"Input".as_ptr(), c"Output".as_ptr(), c"Level".as_ptr(), c"Enabled".as_ptr()]);
static PORT_HINTS: [PortRangeHint; PORT_COUNT] = [
    PortRangeHint { hint: 0, lower: 0.0, upper: 0.0 },
    PortRangeHint { hint: 0, lower: 0.0, upper: 0.0 },
    PortRangeHint { hint: HINT_BOUNDED_BELOW | HINT_BOUNDED_ABOVE | HINT_DEFAULT_LOW, lower: 0.0, upper: LEVEL_MAX as f32 },
    PortRangeHint { hint: HINT_TOGGLED | HINT_DEFAULT_1, lower: 0.0, upper: 1.0 },
];
static DESCRIPTOR: Static<Descriptor> = Static(Descriptor {
    unique_id: 0x4d43_5631,
    label: c"leveling".as_ptr(),
    properties: PROPERTY_HARD_RT_CAPABLE,
    name: c"MCHOSE V9 Pro 2 mic volume leveling".as_ptr(),
    maker: c"mchose-hub-port".as_ptr(),
    copyright: c"GPL-3.0-or-later".as_ptr(),
    port_count: PORT_COUNT as c_ulong,
    port_descriptors: PORT_DESCRIPTORS.as_ptr(),
    port_names: PORT_NAMES.0.as_ptr(),
    port_range_hints: PORT_HINTS.as_ptr(),
    implementation_data: ptr::null_mut(),
    instantiate,
    connect_port,
    activate: Some(activate),
    run,
    run_adding: None,
    set_run_adding_gain: None,
    deactivate: None,
    cleanup,
});

struct Instance {
    dsp: Leveler,
    ports: [*mut f32; PORT_COUNT],
}

/// # Safety
/// LADSPA entry point; called by the host.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ladspa_descriptor(index: c_ulong) -> *const Descriptor {
    if index == 0 { &DESCRIPTOR.0 } else { ptr::null() }
}

unsafe extern "C" fn instantiate(_: *const Descriptor, rate: c_ulong) -> Handle {
    let inst = Instance { dsp: Leveler::new(rate as f64), ports: [ptr::null_mut(); PORT_COUNT] };
    Box::into_raw(Box::new(inst)).cast()
}

unsafe extern "C" fn connect_port(h: Handle, port: c_ulong, data: *mut f32) {
    let inst = unsafe { &mut *h.cast::<Instance>() };
    if let Some(p) = inst.ports.get_mut(port as usize) {
        *p = data;
    }
}

/// Reads a control port, or `default` when the host left it unconnected.
unsafe fn control(p: *mut f32, default: f32) -> f32 {
    if p.is_null() { default } else { unsafe { *p } }
}

unsafe extern "C" fn activate(h: Handle) {
    let inst = unsafe { &mut *h.cast::<Instance>() };
    let level = unsafe { control(inst.ports[PORT_LEVEL as usize], 0.0) };
    let enabled = unsafe { control(inst.ports[PORT_ENABLED as usize], 1.0) } > 0.5;
    inst.dsp.reset(level as f64, enabled);
}

unsafe extern "C" fn run(h: Handle, n: c_ulong) {
    let inst = unsafe { &mut *h.cast::<Instance>() };
    let (inp, out) = (inst.ports[PORT_IN as usize], inst.ports[PORT_OUT as usize]);
    if inp.is_null() || out.is_null() {
        return;
    }
    let level = unsafe { control(inst.ports[PORT_LEVEL as usize], 0.0) };
    let enabled = unsafe { control(inst.ports[PORT_ENABLED as usize], 1.0) } > 0.5;
    // Hosts may run in place (same buffer for both ports): process in small chunks via a copy.
    let mut done = 0usize;
    let n = n as usize;
    let mut buf = [0f32; 256];
    while done < n {
        let len = (n - done).min(buf.len());
        unsafe { ptr::copy_nonoverlapping(inp.add(done), buf.as_mut_ptr(), len) };
        let output = unsafe { std::slice::from_raw_parts_mut(out.add(done), len) };
        inst.dsp.run(level as f64, enabled, &buf[..len], output);
        done += len;
    }
}

unsafe extern "C" fn cleanup(h: Handle) {
    drop(unsafe { Box::from_raw(h.cast::<Instance>()) });
}

#[cfg(test)]
mod tests {
    use super::*;

    const FS: f64 = 48000.0;

    fn db(x: f64) -> f64 {
        20.0 * x.abs().log10()
    }

    /// Output level (dB) for a steady signal of `in_db`, after the gain settles.
    fn settled(p: DrcParams, in_db: f64) -> f64 {
        let mut d = Drc::new(FS, p);
        let x = 10f64.powf(in_db / 20.0);
        let mut y = 0.0;
        for _ in 0..(FS as usize * 5) {
            y = d.process(x);
        }
        db(y)
    }

    #[test]
    fn table_lookup() {
        assert_eq!(leveling_for(40), LEVELING[2].1);
        assert_eq!(leveling_for(250), LEVELING[5].1);
        let p = leveling_for(10);
        assert!((p.threshold_db - -8.5).abs() < 1e-9);
        assert!((p.ratio - 2.1).abs() < 1e-9);
        assert!((p.decay_ms - 275.0).abs() < 1e-9);
    }

    #[test]
    fn static_curve() {
        let p = LEVELING[0].1; // T −6, W 4, R 2, +3 dB
        // Below the knee: only makeup.
        assert!((settled(p, -20.0) - (-20.0 + 3.0)).abs() < 0.01);
        // Above the knee: T + (x − T)/R + makeup.
        assert!((settled(p, 0.0) - (-6.0 + 6.0 / 2.0 + 3.0)).abs() < 0.01);
        // At the threshold the soft knee takes (1/R − 1)·(W/2)²/(2W) = −0.25 dB.
        assert!((settled(p, -6.0) - (-6.0 - 0.25 + 3.0)).abs() < 0.01);
    }

    #[test]
    fn knee_is_continuous() {
        let d = Drc::new(FS, LEVELING[3].1);
        for edge in [d.threshold - d.half_width, d.threshold + d.half_width] {
            let (a, b) = (d.curve(edge - 1e-9), d.curve(edge + 1e-9));
            assert!((a - b).abs() < 1e-6, "{a} vs {b}");
        }
    }

    #[test]
    fn attack_time_constant() {
        let p = DrcParams { attack_ms: 10.0, ..LEVELING[0].1 };
        let mut d = Drc::new(FS, p);
        let target = d.curve(0.0); // 0 dBFS = ln 1
        for _ in 0..(FS * 0.010) as usize {
            d.process(1.0);
        }
        // After one time constant the gain covers 1 − 1/e of the way.
        let covered = d.gain / target;
        assert!((covered - (1.0 - (-1f64).exp())).abs() < 0.01, "{covered}");
    }

    #[test]
    fn limiter_caps_peaks() {
        // 0 dBFS in: −1 + 1/7 dB out (above the knee of 0.5 dB).
        assert!((settled(LIMITER, 0.0) - (-1.0 + 1.0 / 7.0)).abs() < 0.01);
    }

    #[test]
    fn disabled_is_transparent() {
        let mut l = Leveler::new(FS);
        l.reset(50.0, false);
        let input: Vec<f32> = (0..4800).map(|i| 0.1 * (i as f32 * 0.05).sin()).collect();
        let mut output = vec![0f32; input.len()];
        l.run(50.0, false, &input, &mut output);
        for (a, b) in input.iter().zip(&output) {
            assert!((a - b).abs() < 1e-6);
        }
    }

    #[test]
    fn level_ramps() {
        let mut l = Leveler::new(FS);
        l.reset(0.0, true);
        let input = vec![0f32; 480]; // 10 ms
        let mut output = vec![0f32; 480];
        l.run(100.0, true, &input, &mut output);
        assert!((l.level - 5.0).abs() < 1e-9); // 100 per 200 ms
    }

    #[test]
    fn ladspa_roundtrip() {
        unsafe {
            let d = &*ladspa_descriptor(0);
            assert!(ladspa_descriptor(1).is_null());
            assert_eq!(std::ffi::CStr::from_ptr(d.label), c"leveling");
            let h = (d.instantiate)(d, 48000);
            let mut level = 60f32;
            let mut enabled = 1f32;
            let mut buf: Vec<f32> = (0..1000).map(|i| 0.5 * (i as f32 * 0.03).sin()).collect();
            (d.connect_port)(h, PORT_LEVEL, &mut level);
            (d.connect_port)(h, PORT_ENABLED, &mut enabled);
            (d.connect_port)(h, PORT_IN, buf.as_mut_ptr());
            (d.connect_port)(h, PORT_OUT, buf.as_mut_ptr()); // in place
            (d.activate.unwrap())(h);
            (d.run)(h, buf.len() as c_ulong);
            // The limiter is a 7:1 compressor, not a brick wall: only check sanity.
            assert!(buf.iter().all(|x| x.is_finite() && x.abs() < 4.0));
            (d.cleanup)(h);
        }
    }
}
