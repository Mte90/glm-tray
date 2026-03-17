import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

PlasmaExtras.Representation {
    id: fullRep

    // ── Properties injected from main.qml ─────────────────────────────────
    property var keyListData:   []
    property var keyStatesData: []

    signal warmupRequested(int index)
    signal fetchRequested(int index)
    signal refreshAllRequested()

    // ── Helpers ───────────────────────────────────────────────────────────
    function platformLabel(platform) {
        return platform === "bigmodel" ? "BigModel" : "Z.ai"
    }

    function formatResetTime(ms) {
        if (!ms) return "—"
        const diff = ms - Date.now()
        if (diff <= 0) return i18n("Reset due")
        const h = Math.floor(diff / 3600000)
        const m = Math.floor((diff % 3600000) / 60000)
        return h > 0 ? i18n("%1h %2m", h, m) : i18n("%1m", m)
    }

    function statusDotColor(status) {
        switch (status) {
            case "ok":      return Kirigami.Theme.positiveTextColor
            case "error":   return Kirigami.Theme.negativeTextColor
            case "loading": return Kirigami.Theme.neutralTextColor
            default:        return Kirigami.Theme.disabledTextColor
        }
    }

    // ── Header ────────────────────────────────────────────────────────────
    header: PlasmaExtras.PlasmoidHeading {
        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "network-server"
                Layout.preferredWidth:  Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }

            PlasmaExtras.Heading {
                text: "GLM Tray"
                level: 3
                Layout.fillWidth: true
            }

            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                Controls.ToolTip.text: i18n("Refresh all")
                Controls.ToolTip.visible: hovered
                onClicked: fullRep.refreshAllRequested()
            }

            PlasmaComponents.ToolButton {
                icon.name: "settings-configure"
                Controls.ToolTip.text: i18n("Configure")
                Controls.ToolTip.visible: hovered
                onClicked: Plasmoid.internalAction("configure").trigger()
            }
        }
    }

    // ── Content ───────────────────────────────────────────────────────────
    contentItem: Controls.ScrollView {
        id: scrollArea
        contentWidth: availableWidth

        ColumnLayout {
            id: mainColumn
            width: scrollArea.availableWidth
            spacing: Kirigami.Units.smallSpacing

            // ── Key cards ─────────────────────────────────────────────────
            Repeater {
                model: fullRep.keyListData.length

                delegate: PlasmaComponents.Frame {
                    readonly property var cfg:       fullRep.keyListData[index]  || {}
                    readonly property var state:     fullRep.keyStatesData[index] || {}
                    readonly property bool isEnabled: (cfg.enabled === true)
                                                      && (cfg.apiKey || "") !== ""

                    Layout.fillWidth: true
                    visible: isEnabled
                    // collapse height when hidden so the layout stays tidy
                    Layout.topMargin:    visible ? Kirigami.Units.smallSpacing / 2 : 0
                    Layout.bottomMargin: visible ? Kirigami.Units.smallSpacing / 2 : 0

                    ColumnLayout {
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        anchors.margins: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

                        // ── Card header row ───────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            // Status dot
                            Rectangle {
                                width:  10
                                height: 10
                                radius: 5
                                color:  fullRep.statusDotColor(state.status || "idle")
                                border.color: Qt.rgba(0, 0, 0, 0.2)
                                border.width: 1
                            }

                            // Key name
                            PlasmaComponents.Label {
                                text: cfg.name || i18n("Key %1", index + 1)
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            // Platform badge
                            PlasmaComponents.Label {
                                text: fullRep.platformLabel(cfg.platform || "zai")
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                color: Kirigami.Theme.disabledTextColor
                            }

                            // Level badge (pro, free, …)
                            PlasmaComponents.Label {
                                text: (state.level || "").toUpperCase()
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                font.bold: true
                                color: Kirigami.Theme.neutralTextColor
                                visible: (state.level || "") !== ""
                            }
                        }

                        // ── Error message ─────────────────────────────────
                        PlasmaComponents.Label {
                            text: state.errorMsg || ""
                            color: Kirigami.Theme.negativeTextColor
                            visible: (state.status === "error") && (state.errorMsg || "") !== ""
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        }

                        // ── Loading indicator ─────────────────────────────
                        PlasmaComponents.BusyIndicator {
                            visible: state.status === "loading"
                            Layout.alignment: Qt.AlignHCenter
                            implicitHeight: Kirigami.Units.iconSizes.medium
                            implicitWidth:  Kirigami.Units.iconSizes.medium
                        }

                        // ── Quota details (only when ok) ──────────────────
                        ColumnLayout {
                            visible: state.status === "ok"
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing / 2

                            // Tokens (5h window) bar
                            RowLayout {
                                Layout.fillWidth: true

                                PlasmaComponents.Label {
                                    text: i18n("Tokens (5h):")
                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                    opacity: 0.75
                                    Layout.preferredWidth: 100
                                }

                                PlasmaComponents.ProgressBar {
                                    value: (state.tokensPercent || 0) / 100
                                    Layout.fillWidth: true
                                }

                                PlasmaComponents.Label {
                                    text: (state.tokensPercent || 0) + "%"
                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                    Layout.preferredWidth: 38
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            // Requests (monthly) bar
                            RowLayout {
                                Layout.fillWidth: true
                                visible: (state.timeUsage || 0) + (state.timeRemaining || 0) > 0

                                PlasmaComponents.Label {
                                    text: i18n("Requests:")
                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                    opacity: 0.75
                                    Layout.preferredWidth: 100
                                }

                                PlasmaComponents.ProgressBar {
                                    value: (state.timePercent || 0) / 100
                                    Layout.fillWidth: true
                                }

                                PlasmaComponents.Label {
                                    readonly property int total: (state.timeUsage || 0)
                                                                + (state.timeRemaining || 0)
                                    text: (state.timeUsage || 0) + " / " + total
                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                    Layout.preferredWidth: 60
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            // Reset countdown + last updated
                            RowLayout {
                                Layout.fillWidth: true

                                Kirigami.Icon {
                                    source: "clock"
                                    implicitWidth:  Kirigami.Units.iconSizes.tiny
                                    implicitHeight: Kirigami.Units.iconSizes.tiny
                                    opacity: 0.6
                                }

                                PlasmaComponents.Label {
                                    text: i18n("Resets in: %1",
                                               fullRep.formatResetTime(state.nextResetMs || 0))
                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                    opacity: 0.85
                                    Layout.fillWidth: true
                                }

                                PlasmaComponents.Label {
                                    text: state.lastUpdated
                                          ? i18n("Updated: %1", state.lastUpdated) : ""
                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                    opacity: 0.5
                                    visible: (state.lastUpdated || "") !== ""
                                }
                            }
                        }

                        // ── Action buttons ────────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            PlasmaComponents.Button {
                                text: state.warmingUp
                                      ? i18n("Warming up…")
                                      : i18n("Warm Up")
                                icon.name: state.warmingUp
                                           ? "process-working"
                                           : "media-playback-start"
                                enabled: !state.warmingUp
                                         && state.status !== "loading"
                                Layout.fillWidth: true
                                onClicked: fullRep.warmupRequested(index)
                            }

                            PlasmaComponents.Button {
                                text: i18n("Refresh")
                                icon.name: "view-refresh"
                                enabled: state.status !== "loading"
                                         && !state.warmingUp
                                Layout.fillWidth: true
                                onClicked: fullRep.fetchRequested(index)
                            }
                        }
                    }
                }
            }

            // ── Empty state ───────────────────────────────────────────────
            PlasmaExtras.PlaceholderMessage {
                visible: !fullRep.keyListData.some(function(k) {
                    return k.enabled && (k.apiKey || "") !== ""
                })
                Layout.fillWidth: true
                Layout.topMargin:    Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.largeSpacing
                iconName: "network-server"
                text: i18n("No API keys configured")
                explanation: i18n("Click the settings button above to add your Z.ai or BigModel API keys.")
            }

            Item { Layout.fillHeight: true }
        }
    }
}

