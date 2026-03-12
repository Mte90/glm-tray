import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ── Platform URL definitions ──────────────────────────────────────────
    readonly property var platforms: ({
        "zai": {
            label: "Z.ai",
            quota: "https://api.z.ai/api/monitor/usage/quota/limit",
            request: "https://api.z.ai/api/coding/paas/v4/chat/completions"
        },
        "bigmodel": {
            label: "BigModel",
            quota: "https://open.bigmodel.cn/api/monitor/usage/quota/limit",
            request: "https://open.bigmodel.cn/api/coding/paas/v4/chat/completions"
        }
    })

    // ── Config accessor (reads from Plasmoid.configuration) ───────────────
    function keyConfig(slot) {
        const prefix = "key" + slot
        const apiKey = Plasmoid.configuration[prefix + "ApiKey"] || ""
        return {
            slot: slot,
            enabled: (Plasmoid.configuration[prefix + "Enabled"] === true) && apiKey !== "",
            name: Plasmoid.configuration[prefix + "Name"] || ("Key " + slot),
            apiKey: apiKey,
            platform: Plasmoid.configuration[prefix + "Platform"] || "zai",
            pollIntervalMinutes: Plasmoid.configuration[prefix + "PollIntervalMinutes"]
                                 || Plasmoid.configuration.defaultPollIntervalMinutes
                                 || 30
        }
    }

    // ── Runtime state (keyed by slot number 1–4) ──────────────────────────
    property var keyStates: ({
        1: { slot: 1, status: "idle", tokensPercent: 0, timePercent: 0,
             timeUsage: 0, timeRemaining: 0, nextResetMs: 0, level: "",
             errorMsg: "", lastUpdated: "", warmingUp: false },
        2: { slot: 2, status: "idle", tokensPercent: 0, timePercent: 0,
             timeUsage: 0, timeRemaining: 0, nextResetMs: 0, level: "",
             errorMsg: "", lastUpdated: "", warmingUp: false },
        3: { slot: 3, status: "idle", tokensPercent: 0, timePercent: 0,
             timeUsage: 0, timeRemaining: 0, nextResetMs: 0, level: "",
             errorMsg: "", lastUpdated: "", warmingUp: false },
        4: { slot: 4, status: "idle", tokensPercent: 0, timePercent: 0,
             timeUsage: 0, timeRemaining: 0, nextResetMs: 0, level: "",
             errorMsg: "", lastUpdated: "", warmingUp: false }
    })

    // Next scheduled poll time per slot (ms epoch)
    property var nextPollTimes: ({ 1: 0, 2: 0, 3: 0, 4: 0 })

    // ── Polling timer ─────────────────────────────────────────────────────
    Timer {
        id: pollTimer
        interval: 30000   // check every 30 s whether any slot is due
        repeat: true
        running: true
        onTriggered: {
            const now = Date.now()
            for (let slot = 1; slot <= 4; slot++) {
                const cfg = root.keyConfig(slot)
                if (cfg.enabled && now >= root.nextPollTimes[slot]) {
                    root.fetchQuota(slot)
                }
            }
        }
    }

    // ── State helpers ─────────────────────────────────────────────────────
    function updateState(slot, patch) {
        const ns = Object.assign({}, keyStates)
        ns[slot] = Object.assign({}, ns[slot], patch)
        keyStates = ns
    }

    function scheduleNextPoll(slot, intervalMinutes) {
        const np = Object.assign({}, nextPollTimes)
        np[slot] = Date.now() + intervalMinutes * 60 * 1000
        nextPollTimes = np
    }

    // ── API: fetch quota ──────────────────────────────────────────────────
    function fetchQuota(slot) {
        const cfg = keyConfig(slot)
        if (!cfg.enabled) {
            updateState(slot, { status: "disabled" })
            return
        }

        const plat = platforms[cfg.platform] || platforms["zai"]
        updateState(slot, { status: "loading" })

        const xhr = new XMLHttpRequest()
        xhr.open("GET", plat.quota, true)
        xhr.setRequestHeader("Authorization", "Bearer " + cfg.apiKey)
        xhr.setRequestHeader("Accept-Language", "en-US")
        xhr.timeout = 15000

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            scheduleNextPoll(slot, cfg.pollIntervalMinutes)

            if (xhr.status === 200) {
                try {
                    const resp = JSON.parse(xhr.responseText)
                    if (resp.success && resp.data) {
                        processQuotaResponse(slot, resp.data)
                        return
                    }
                    updateState(slot, {
                        status: "error",
                        errorMsg: resp.msg || i18n("Unexpected response"),
                        lastUpdated: Qt.formatTime(new Date(), "hh:mm")
                    })
                } catch (e) {
                    updateState(slot, {
                        status: "error",
                        errorMsg: i18n("Parse error"),
                        lastUpdated: Qt.formatTime(new Date(), "hh:mm")
                    })
                }
            } else {
                updateState(slot, {
                    status: "error",
                    errorMsg: "HTTP " + xhr.status,
                    lastUpdated: Qt.formatTime(new Date(), "hh:mm")
                })
            }
        }

        xhr.onerror = function() {
            scheduleNextPoll(slot, cfg.pollIntervalMinutes)
            updateState(slot, {
                status: "error",
                errorMsg: i18n("Network error"),
                lastUpdated: Qt.formatTime(new Date(), "hh:mm")
            })
        }

        xhr.send()
    }

    function processQuotaResponse(slot, data) {
        const limits = data.limits || []
        let tokensPercent = 0
        let timePercent   = 0
        let timeUsage     = 0
        let timeRemaining = 0
        let nextResetMs   = 0

        for (const limit of limits) {
            if (limit.type === "TOKENS_LIMIT") {
                tokensPercent = limit.percentage    || 0
                nextResetMs   = limit.nextResetTime || 0
            } else if (limit.type === "TIME_LIMIT") {
                timePercent   = limit.percentage    || 0
                timeUsage     = limit.currentValue  || 0
                timeRemaining = limit.remaining     || 0
                if (!nextResetMs) nextResetMs = limit.nextResetTime || 0
            }
        }

        updateState(slot, {
            status: "ok",
            tokensPercent: tokensPercent,
            timePercent:   timePercent,
            timeUsage:     timeUsage,
            timeRemaining: timeRemaining,
            nextResetMs:   nextResetMs,
            level:         data.level || "",
            errorMsg:      "",
            lastUpdated:   Qt.formatTime(new Date(), "hh:mm")
        })
    }

    // ── API: warmup ───────────────────────────────────────────────────────
    function warmupSlot(slot) {
        const cfg = keyConfig(slot)
        if (!cfg.enabled || keyStates[slot].warmingUp) return

        const plat = platforms[cfg.platform] || platforms["zai"]
        updateState(slot, { warmingUp: true })

        const xhr = new XMLHttpRequest()
        xhr.open("POST", plat.request, true)
        xhr.setRequestHeader("Authorization", "Bearer " + cfg.apiKey)
        xhr.setRequestHeader("Accept-Language", "en-US")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 30000

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            updateState(slot, { warmingUp: false })
            Qt.callLater(function() { fetchQuota(slot) })
        }

        xhr.onerror = function() {
            updateState(slot, { warmingUp: false })
        }

        xhr.send(JSON.stringify({
            model: "glm-4-flash",
            messages: [{ role: "user", content: "hi" }],
            max_tokens: 1
        }))
    }

    // ── Refresh all enabled keys ──────────────────────────────────────────
    function refreshAll() {
        for (let slot = 1; slot <= 4; slot++) {
            const cfg = keyConfig(slot)
            if (cfg.enabled) fetchQuota(slot)
        }
    }

    // ── Derived overall status for compact icon ───────────────────────────
    readonly property string overallStatus: {
        let hasEnabled = false
        let hasError   = false
        let hasLoading = false
        for (let i = 1; i <= 4; i++) {
            const cfg = keyConfig(i)
            if (cfg.enabled) {
                hasEnabled = true
                const st = keyStates[i].status
                if (st === "error")   hasError   = true
                if (st === "loading") hasLoading = true
            }
        }
        if (!hasEnabled) return "idle"
        if (hasError)    return "error"
        if (hasLoading)  return "loading"
        return "ok"
    }

    // ── Start-up: fetch all configured keys ───────────────────────────────
    Component.onCompleted: Qt.callLater(refreshAll)

    // ── Compact representation (panel icon) ───────────────────────────────
    compactRepresentation: Item {
        id: compactRoot

        Kirigami.Icon {
            anchors.fill: parent
            anchors.margins: Math.round(Math.min(parent.width, parent.height) * 0.1)
            source: "network-server"

            // Status indicator dot
            Rectangle {
                width:  Math.round(parent.width  * 0.35)
                height: width
                radius: width / 2
                anchors.right:        parent.right
                anchors.bottom:       parent.bottom
                anchors.rightMargin:  -2
                anchors.bottomMargin: -2
                visible: root.overallStatus !== "idle"
                color: root.overallStatus === "ok"      ? "#22c55e"
                     : root.overallStatus === "error"   ? "#ef4444"
                     : root.overallStatus === "loading" ? "#f59e0b"
                     : "transparent"
                border.color: Qt.rgba(0, 0, 0, 0.4)
                border.width: 1
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: Plasmoid.expanded = !Plasmoid.expanded

            Controls.ToolTip {
                text: {
                    const lines = ["GLM Tray"]
                    for (let i = 1; i <= 4; i++) {
                        const cfg = root.keyConfig(i)
                        if (cfg.enabled) {
                            const st = root.keyStates[i]
                            lines.push(cfg.name + ": " + st.tokensPercent + "% tokens"
                                       + (st.status === "error" ? " ⚠" : ""))
                        }
                    }
                    return lines.length > 1 ? lines.join("\n")
                                            : i18n("GLM Tray — no keys configured")
                }
                visible: parent.containsMouse
                delay: 600
            }
        }
    }

    // ── Full representation (popup) ───────────────────────────────────────
    fullRepresentation: FullRepresentation {
        keyStatesData: root.keyStates
        onWarmupRequested: function(slot) { root.warmupSlot(slot) }
        onFetchRequested:  function(slot) { root.fetchQuota(slot) }
        onRefreshAllRequested: root.refreshAll()
    }
}
