pragma Singleton
import QtQuick
import MchoseV9

// UI translations. Reading `i18n.language` inside tr() makes every binding that calls it
// re-evaluate when the language changes. Switch with `Lang.i18n.language = "pt_BR"`.
QtObject {
    readonly property I18n i18n: I18n {}

    function tr(key) { return i18n.language, i18n.tr(key) }
}
