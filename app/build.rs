use cxx_qt_build::{CxxQtBuilder, QmlFile, QmlModule};

fn main() {
    println!("cargo::rerun-if-changed=i18n");
    let qml = [
        "Main", "Sidebar", "CommonPage", "EffectsPage", "OtherPage", "EqEditor", "EqChart",
        "Sparkline", "PresetCard", "SoundModeRow", "EffectCard", "PageTitle", "ModeTag", "Card",
        "McSlider", "McSwitch", "McButton", "McMenu", "McMenuItem", "Icon", "HeadsetArt",
    ]
    .map(|name| QmlFile::from(format!("qml/{name}.qml")));
    let singletons = ["Theme", "Lang"].map(|name| QmlFile::from(format!("qml/{name}.qml")).singleton(true));
    let module = QmlModule::new("MchoseV9")
        .qml_files(qml)
        .qml_files(singletons)
        .qml_file("qml/eqpath.js");
    CxxQtBuilder::new_qml_module(module)
        .files(["src/headset.rs", "src/i18n.rs"])
        .build();
}
