use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    println!("cargo::rerun-if-changed=i18n");
    CxxQtBuilder::new_qml_module(QmlModule::new("MchoseV9").qml_files(["qml/Main.qml", "qml/Card.qml", "qml/EqCurve.qml"]))
        .files(["src/headset.rs", "src/i18n.rs"])
        .build();
}
