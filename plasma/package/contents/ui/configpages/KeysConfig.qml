import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// Keys configuration page — dynamically add/remove key slots.
// Values are written directly to Plasmoid.configuration so changes
// take effect immediately (no Apply button required for these fields).

Kirigami.ScrollablePage {
    id: keysPage

    leftPadding:   0
    rightPadding:  0
    topPadding:    Kirigami.Units.smallSpacing
    bottomPadding: Kirigami.Units.largeSpacing

    // ── Local model populated once from config ────────────────────────────
    ListModel { id: keysModel }

    Component.onCompleted: {
        try {
            const arr = JSON.parse(Plasmoid.configuration.keysJson || "[]")
            const list = Array.isArray(arr) ? arr : []
            for (const k of list) {
                keysModel.append({
                    enabled:             k.enabled             === true,
                    name:                k.name                || "",
                    apiKey:              k.apiKey              || "",
                    platform:            k.platform            || "zai",
                    pollIntervalMinutes: k.pollIntervalMinutes || 30
                })
            }
        } catch(e) {
            console.warn("GLM Tray: failed to parse keysJson:", e)
        }
    }

    function saveKeys() {
        const arr = []
        for (let i = 0; i < keysModel.count; i++) {
            const e = keysModel.get(i)
            arr.push({
                enabled:             e.enabled,
                name:                e.name,
                apiKey:              e.apiKey,
                platform:            e.platform,
                pollIntervalMinutes: e.pollIntervalMinutes
            })
        }
        Plasmoid.configuration.keysJson = JSON.stringify(arr)
    }

    // ── Layout ────────────────────────────────────────────────────────────
    ColumnLayout {
        spacing: 0

        // ── Key cards ─────────────────────────────────────────────────────
        Repeater {
            model: keysModel

            delegate: ColumnLayout {
                id: keyDelegate
                readonly property int slotIndex: index

                Layout.fillWidth: true
                spacing: 0

                // ── Section separator (except before the first card) ──────
                Kirigami.Separator {
                    visible: keyDelegate.slotIndex > 0
                    Layout.fillWidth: true
                }

                // ── Section header row ────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        text: i18n("Key %1", keyDelegate.slotIndex + 1)
                        font.bold: true
                        Layout.fillWidth: true
                        leftPadding: Kirigami.Units.largeSpacing
                    }

                    PlasmaComponents.ToolButton {
                        icon.name: "list-remove"
                        Controls.ToolTip.text: i18n("Remove this key")
                        Controls.ToolTip.visible: hovered
                        onClicked: {
                            keysModel.remove(keyDelegate.slotIndex)
                            keysPage.saveKeys()
                        }
                    }
                }

                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin:  Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing

                    // Enabled toggle
                    Controls.CheckBox {
                        Kirigami.FormData.label: i18n("Enabled:")
                        checked: model.enabled || false
                        onToggled: {
                            keysModel.setProperty(keyDelegate.slotIndex, "enabled", checked)
                            keysPage.saveKeys()
                        }
                    }

                    // Display name
                    Controls.TextField {
                        Kirigami.FormData.label: i18n("Display name:")
                        Layout.fillWidth: true
                        text: model.name || ""
                        placeholderText: i18n("Key %1", keyDelegate.slotIndex + 1)
                        onEditingFinished: {
                            keysModel.setProperty(keyDelegate.slotIndex, "name", text)
                            keysPage.saveKeys()
                        }
                    }

                    // API key (password field)
                    Controls.TextField {
                        id: apiKeyField
                        Kirigami.FormData.label: i18n("API key:")
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        text: model.apiKey || ""
                        placeholderText: i18n("Paste your API key here")
                        onEditingFinished: {
                            keysModel.setProperty(keyDelegate.slotIndex, "apiKey", text)
                            keysPage.saveKeys()
                        }

                        // Toggle visibility button
                        rightInset: showBtn.width
                        rightPadding: showBtn.width + 4

                        PlasmaComponents.ToolButton {
                            id: showBtn
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            icon.name: apiKeyField.echoMode === TextInput.Password
                                       ? "password-show-on" : "password-show-off"
                            onClicked: apiKeyField.echoMode =
                                apiKeyField.echoMode === TextInput.Password
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
                            const saved = keysModel.get(keyDelegate.slotIndex).platform || "zai"
                            for (let i = 0; i < platformCombo.model.length; i++) {
                                if (platformCombo.model[i].value === saved) {
                                    currentIndex = i
                                    break
                                }
                            }
                        }

                        onActivated: {
                            keysModel.setProperty(keyDelegate.slotIndex, "platform", currentValue)
                            keysPage.saveKeys()
                        }
                    }

                    // Poll interval
                    RowLayout {
                        Kirigami.FormData.label: i18n("Poll interval:")
                        spacing: Kirigami.Units.smallSpacing

                        Controls.SpinBox {
                            from: 1
                            to: 1440
                            value: model.pollIntervalMinutes || 30
                            onValueModified: {
                                keysModel.setProperty(keyDelegate.slotIndex,
                                                      "pollIntervalMinutes", value)
                                keysPage.saveKeys()
                            }
                        }

                        PlasmaComponents.Label {
                            text: i18n("minutes")
                        }
                    }
                }
            }
        }

        // ── Add key button ────────────────────────────────────────────────
        PlasmaComponents.Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.largeSpacing
            text: i18n("Add Key")
            icon.name: "list-add"
            onClicked: {
                keysModel.append({
                    enabled:             false,
                    name:                "",
                    apiKey:              "",
                    platform:            "zai",
                    pollIntervalMinutes: Plasmoid.configuration.defaultPollIntervalMinutes || 30
                })
                keysPage.saveKeys()
            }
        }
    }
}

