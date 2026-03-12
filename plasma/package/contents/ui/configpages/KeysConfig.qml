import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// Keys configuration page — 4 key slots in a scrollable form.
// Values are written directly to Plasmoid.configuration so changes
// take effect immediately (no Apply button required for these fields).

Kirigami.ScrollablePage {
    id: keysPage

    leftPadding:   0
    rightPadding:  0
    topPadding:    Kirigami.Units.smallSpacing
    bottomPadding: Kirigami.Units.smallSpacing

    ColumnLayout {
        spacing: 0

        Repeater {
            model: 4

            delegate: ColumnLayout {
                readonly property int slotNum: index + 1
                readonly property string pfx: "key" + slotNum

                Layout.fillWidth: true
                spacing: 0

                // ── Section separator ─────────────────────────────────────
                Kirigami.ListSectionHeader {
                    label: i18n("Key %1", slotNum)
                    Layout.fillWidth: true
                }

                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin:  Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing

                    // Enabled toggle
                    Controls.CheckBox {
                        Kirigami.FormData.label: i18n("Enabled:")
                        checked: Plasmoid.configuration[pfx + "Enabled"] || false
                        onToggled: Plasmoid.configuration[pfx + "Enabled"] = checked
                    }

                    // Display name
                    Controls.TextField {
                        Kirigami.FormData.label: i18n("Display name:")
                        Layout.fillWidth: true
                        text: Plasmoid.configuration[pfx + "Name"] || ""
                        placeholderText: i18n("Key %1", slotNum)
                        onEditingFinished: Plasmoid.configuration[pfx + "Name"] = text
                    }

                    // API key (password field)
                    Controls.TextField {
                        Kirigami.FormData.label: i18n("API key:")
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        text: Plasmoid.configuration[pfx + "ApiKey"] || ""
                        placeholderText: i18n("Paste your API key here")
                        onEditingFinished: Plasmoid.configuration[pfx + "ApiKey"] = text

                        // Toggle visibility button
                        rightInset: showBtn.width
                        rightPadding: showBtn.width + 4

                        PlasmaComponents.ToolButton {
                            id: showBtn
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            icon.name: parent.echoMode === TextInput.Password
                                       ? "password-show-on" : "password-show-off"
                            onClicked: parent.echoMode = parent.echoMode === TextInput.Password
                                       ? TextInput.Normal : TextInput.Password
                        }
                    }

                    // Platform selector
                    Controls.ComboBox {
                        id: platformCombo
                        Kirigami.FormData.label: i18n("Platform:")
                        model: [
                            { text: "Z.ai",     value: "zai"      },
                            { text: "BigModel",  value: "bigmodel" }
                        ]
                        textRole:  "text"
                        valueRole: "value"

                        Component.onCompleted: {
                            const saved = Plasmoid.configuration[pfx + "Platform"] || "zai"
                            for (let i = 0; i < model.length; i++) {
                                if (model[i].value === saved) { currentIndex = i; break }
                            }
                        }

                        onActivated: {
                            Plasmoid.configuration[pfx + "Platform"] = currentValue
                        }
                    }

                    // Poll interval
                    RowLayout {
                        Kirigami.FormData.label: i18n("Poll interval:")
                        spacing: Kirigami.Units.smallSpacing

                        Controls.SpinBox {
                            id: pollSpinBox
                            from: 1
                            to: 1440
                            value: Plasmoid.configuration[pfx + "PollIntervalMinutes"]
                                   || Plasmoid.configuration.defaultPollIntervalMinutes
                                   || 30
                            onValueModified: {
                                Plasmoid.configuration[pfx + "PollIntervalMinutes"] = value
                            }
                        }

                        PlasmaComponents.Label {
                            text: i18n("minutes")
                        }
                    }
                }
            }
        }
    }
}
