//! UI translations. English is the default; catalogs live in `app/i18n/*.lang`.
//!
//! QML reads `language` inside each binding (see `Main.qml` `tr()`), so changing it
//! retranslates the whole UI at runtime.

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
        /// Catalog code: "en" or "pt_BR".
        #[qproperty(QString, language)]
        type I18n = super::I18nRust;

        /// Translated text for `key` in the current language (falls back to English, then the key).
        #[qinvokable]
        fn tr(self: &I18n, key: &QString) -> QString;
    }
}

use cxx_qt_lib::QString;

const CATALOGS: &[(&str, &str)] = &[
    ("en", include_str!("../i18n/en.lang")),
    ("pt_BR", include_str!("../i18n/pt_BR.lang")),
];

fn lookup(catalog: &str, key: &str) -> Option<String> {
    catalog.lines().find_map(|line| {
        let line = line.trim();
        if line.starts_with('#') {
            return None;
        }
        let (k, v) = line.split_once('=')?;
        (k.trim() == key).then(|| v.trim().to_owned())
    })
}

pub fn translate(language: &str, key: &str) -> String {
    let catalog = |code: &str| CATALOGS.iter().find(|(c, _)| *c == code).map(|(_, text)| *text);
    catalog(language)
        .and_then(|c| lookup(c, key))
        .or_else(|| lookup(catalog("en").unwrap(), key))
        .unwrap_or_else(|| key.to_owned())
}

pub struct I18nRust {
    language: QString,
}

impl Default for I18nRust {
    fn default() -> Self {
        Self { language: QString::from("en") }
    }
}

impl qobject::I18n {
    pub fn tr(&self, key: &QString) -> QString {
        QString::from(&translate(&self.language().to_string(), &key.to_string()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn keys(catalog: &str) -> Vec<&str> {
        catalog
            .lines()
            .filter(|l| !l.trim().is_empty() && !l.trim_start().starts_with('#'))
            .filter_map(|l| l.split_once('=').map(|(k, _)| k.trim()))
            .collect()
    }

    #[test]
    fn catalogs_have_same_keys() {
        let mut en = keys(CATALOGS[0].1);
        let mut pt = keys(CATALOGS[1].1);
        en.sort();
        pt.sort();
        assert_eq!(en, pt);
    }

    #[test]
    fn fallback() {
        assert_eq!(translate("pt_BR", "battery.title"), "Bateria");
        assert_eq!(translate("xx", "battery.title"), "Battery");
        assert_eq!(translate("en", "no.such.key"), "no.such.key");
    }
}
