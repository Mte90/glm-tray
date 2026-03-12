import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// General / global settings configuration page.
// Uses the cfg_ prefix convention so the Plasma config dialog's
// Apply / Cancel buttons work correctly.

Kirigami.FormLayout {
    id: generalPage

    // cfg_ properties are auto-synced by the Plasma config system
    property int cfg_defaultPollIntervalMinutes: 30

    // Default poll interval
    RowLayout {
        Kirigami.FormData.label: i18n("Default poll interval:")
        spacing: Kirigami.Units.smallSpacing

        Controls.SpinBox {
            id: defaultPollSpinBox
            from: 1
            to: 1440
            value: cfg_defaultPollIntervalMinutes
            onValueModified: cfg_defaultPollIntervalMinutes = value
        }

        PlasmaComponents.Label {
            text: i18n("minutes")
        }
    }

    // Info label
    PlasmaComponents.Label {
        Kirigami.FormData.isSection: false
        text: i18n("This value is used as the fallback when a key's individual\n"
                 + "poll interval is not set. Valid range: 1 – 1440 minutes.")
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        opacity: 0.7
        wrapMode: Text.WordWrap
    }
}
