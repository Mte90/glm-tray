import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // Days threshold: a reset within this many days means the quota is weekly
    readonly property int weeklyQuotaThresholdDays: 8
    readonly property int msPerDay: 1000 * 60 * 60 * 24

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

    // ── Parsed key list from configuration ────────────────────────────────
    readonly property var keyList: {
        try {
            const arr = JSON.parse(Plasmoid.configuration.keysJson || "[]")
            return Array.isArray(arr) ? arr : []
        } catch(e) {
            console.warn("GLM Tray: failed to parse keysJson:", e)
            return []
        }
    }

    // ── Runtime state (arrays, parallel to keyList by index) ──────────────
    property var keyStates: []
    property var nextPollTimes: []

    // Reconcile runtime arrays whenever the key list changes
    onKeyListChanged: {
        const newStates     = []
        const newPollTimes  = []
        for (let i = 0; i < keyList.length; i++) {
            newStates.push(i < keyStates.length
                ? keyStates[i]
                : { status: "idle", tokensPercent: 0, timePercent: 0,
                    timeUsage: 0, timeRemaining: 0, nextResetMs: 0,
                    tokensPeriod: "",
                    level: "", errorMsg: "", lastUpdated: "", warmingUp: false })
            newPollTimes.push(i < nextPollTimes.length ? nextPollTimes[i] : 0)
        }
        keyStates    = newStates
        nextPollTimes = newPollTimes
    }

    // ── Helper: is any key configured and enabled? ────────────────────────
    function hasAnyEnabledKey() {
        for (let i = 0; i < keyList.length; i++) {
            const k = keyList[i]
            if (k.enabled && (k.apiKey || "") !== "") return true
        }
        return false
    }

    // ── Polling timer ─────────────────────────────────────────────────────
    Timer {
        id: pollTimer
        interval: 30000   // check every 30 s whether any slot is due
        repeat: true
        running: true
        onTriggered: {
            const now = Date.now()
            for (let i = 0; i < root.keyList.length; i++) {
                const k = root.keyList[i]
                if (k.enabled && (k.apiKey || "") !== "" &&
                        now >= (root.nextPollTimes[i] || 0)) {
                    root.fetchQuota(i)
                }
            }
        }
    }

    // ── State helpers ─────────────────────────────────────────────────────
    function updateState(index, patch) {
        const ns = keyStates.slice()
        while (ns.length <= index) {
            ns.push({ status: "idle", tokensPercent: 0, timePercent: 0,
                      timeUsage: 0, timeRemaining: 0, nextResetMs: 0,
                      tokensPeriod: "",
                      level: "", errorMsg: "", lastUpdated: "", warmingUp: false })
        }
        ns[index] = Object.assign({}, ns[index], patch)
        keyStates = ns
    }

    function scheduleNextPoll(index, intervalMinutes) {
        const np = nextPollTimes.slice()
        while (np.length <= index) np.push(0)
        np[index] = Date.now() + intervalMinutes * 60 * 1000
        nextPollTimes = np
    }

    // ── API: fetch quota ──────────────────────────────────────────────────
    function fetchQuota(index) {
        const k = keyList[index]
        if (!k || !k.enabled || !(k.apiKey || "")) {
            updateState(index, { status: "disabled" })
            return
        }

        const intervalMinutes = k.pollIntervalMinutes || 30
        const plat = platforms[k.platform || "zai"] || platforms["zai"]
        updateState(index, { status: "loading" })

        const xhr = new XMLHttpRequest()
        xhr.open("GET", plat.quota, true)
        xhr.setRequestHeader("Authorization", "Bearer " + k.apiKey)
        xhr.setRequestHeader("Accept-Language", "en-US")
        xhr.timeout = 15000

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            scheduleNextPoll(index, intervalMinutes)

            if (xhr.status === 200) {
                try {
                    const resp = JSON.parse(xhr.responseText)
                    if (resp.success && resp.data) {
                        processQuotaResponse(index, resp.data)
                        return
                    }
                    updateState(index, {
                        status: "error",
                        errorMsg: resp.msg || i18n("Unexpected response"),
                        lastUpdated: Qt.formatTime(new Date(), "hh:mm")
                    })
                } catch (e) {
                    updateState(index, {
                        status: "error",
                        errorMsg: i18n("Parse error"),
                        lastUpdated: Qt.formatTime(new Date(), "hh:mm")
                    })
                }
            } else {
                updateState(index, {
                    status: "error",
                    errorMsg: "HTTP " + xhr.status,
                    lastUpdated: Qt.formatTime(new Date(), "hh:mm")
                })
            }
        }

        xhr.onerror = function() {
            scheduleNextPoll(index, intervalMinutes)
            updateState(index, {
                status: "error",
                errorMsg: i18n("Network error"),
                lastUpdated: Qt.formatTime(new Date(), "hh:mm")
            })
        }

        xhr.send()
    }

    function processQuotaResponse(index, data) {
        const limits = data.limits || []
        let tokensPercent = 0
        let timePercent   = 0
        let timeUsage     = 0
        let timeRemaining = 0
        let nextResetMs   = 0
        let tokensPeriod  = ""

        for (const limit of limits) {
            if (limit.type === "TOKENS_LIMIT") {
                tokensPercent = limit.percentage    || 0
                nextResetMs   = limit.nextResetTime || 0
                // Capture the quota period if the API provides it
                const raw = (limit.period || limit.granularity || "").toLowerCase()
                if (raw === "week" || raw === "weekly") tokensPeriod = "weekly"
                else if (raw === "month" || raw === "monthly") tokensPeriod = "monthly"
            } else if (limit.type === "TIME_LIMIT") {
                timePercent   = limit.percentage    || 0
                timeUsage     = limit.currentValue  || 0
                timeRemaining = limit.remaining     || 0
                if (!nextResetMs) nextResetMs = limit.nextResetTime || 0
            }
        }

        // Fall back to inferring the period from the reset timestamp when the
        // API doesn't include an explicit period field.
        if (!tokensPeriod && nextResetMs) {
            const daysUntilReset = (nextResetMs - Date.now()) / root.msPerDay
            tokensPeriod = daysUntilReset <= root.weeklyQuotaThresholdDays ? "weekly" : "monthly"
        }

        updateState(index, {
            status:        "ok",
            tokensPercent: tokensPercent,
            timePercent:   timePercent,
            timeUsage:     timeUsage,
            timeRemaining: timeRemaining,
            nextResetMs:   nextResetMs,
            tokensPeriod:  tokensPeriod,
            level:         data.level || "",
            errorMsg:      "",
            lastUpdated:   Qt.formatTime(new Date(), "hh:mm")
        })
    }

    // ── API: warmup ───────────────────────────────────────────────────────
    function warmupSlot(index) {
        const k = keyList[index]
        if (!k || !k.enabled || !(k.apiKey || "")) return
        if ((keyStates[index] || {}).warmingUp) return

        const plat = platforms[k.platform || "zai"] || platforms["zai"]
        updateState(index, { warmingUp: true })

        const xhr = new XMLHttpRequest()
        xhr.open("POST", plat.request, true)
        xhr.setRequestHeader("Authorization", "Bearer " + k.apiKey)
        xhr.setRequestHeader("Accept-Language", "en-US")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 30000

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            updateState(index, { warmingUp: false })
            Qt.callLater(function() { fetchQuota(index) })
        }

        xhr.onerror = function() {
            updateState(index, { warmingUp: false })
        }

        xhr.send(JSON.stringify({
            model: "glm-4-flash",
            messages: [{ role: "user", content: "hi" }],
            max_tokens: 1
        }))
    }

    // ── Refresh all enabled keys ──────────────────────────────────────────
    function refreshAll() {
        for (let i = 0; i < keyList.length; i++) {
            const k = keyList[i]
            if (k.enabled && (k.apiKey || "") !== "") fetchQuota(i)
        }
    }

    // ── Derived overall status for compact icon ───────────────────────────
    readonly property string overallStatus: {
        let hasEnabled = false
        let hasError   = false
        let hasLoading = false
        for (let i = 0; i < keyList.length; i++) {
            const k = keyList[i]
            if (k.enabled && (k.apiKey || "") !== "") {
                hasEnabled = true
                const st = (keyStates[i] || {}).status || "idle"
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
    compactRepresentation: MouseArea {
        id: compactRoot
        hoverEnabled: true

        // Request enough width to show the inline key labels (or the fallback icon).
        // Plasma's panel layout reads Layout.minimumWidth / Layout.preferredWidth
        // (attached properties) to size each slot — implicitWidth alone is ignored.
        // The extra 2 × smallSpacing accounts for the symmetric horizontal margins
        // applied by the RowLayout's anchors.margins below.
        implicitWidth: compactRow.implicitWidth + 2 * Kirigami.Units.smallSpacing
        Layout.minimumWidth:  implicitWidth
        Layout.preferredWidth: implicitWidth

        onClicked: {
            // If nothing is configured, go straight to settings
            if (!root.hasAnyEnabledKey()) {
                Plasmoid.internalAction("configure").trigger()
            } else {
                Plasmoid.expanded = !Plasmoid.expanded
            }
        }

        RowLayout {
            id: compactRow
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            // ── Icon with status dot (shown only when no key is configured) ──
            Item {
                visible: !root.hasAnyEnabledKey()
                readonly property int iconSize: Math.min(compactRoot.height,
                                                         Kirigami.Units.iconSizes.large)
                Layout.preferredWidth:  iconSize
                Layout.preferredHeight: iconSize
                Layout.alignment: Qt.AlignVCenter

                Kirigami.Icon {
                    anchors.fill: parent
                    anchors.margins: Math.round(parent.width * 0.1)
                    source: "network-server"

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
            }

            // ── Per-key inline labels (only when keys are configured) ─────
            ColumnLayout {
                visible: root.hasAnyEnabledKey()
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Repeater {
                    model: root.keyList.length

                    delegate: PlasmaComponents.Label {
                        readonly property var k:  root.keyList[index]  || {}
                        readonly property var st: root.keyStates[index] || {}
                        readonly property bool active: (k.enabled === true)
                                                       && (k.apiKey || "") !== ""
                        visible: active
                        text: {
                            const name   = k.name || i18n("Key %1", index + 1)
                            const period = st.tokensPeriod ? (" " + st.tokensPeriod) : ""
                            if (st.status === "loading")
                                return name + " quota: …"
                            if (st.status === "error")
                                return name + " quota: ⚠"
                            if (st.status === "ok")
                                return name + period + " quota: " + (st.tokensPercent || 0) + "%"
                            return name + " quota: —"
                        }
                    }
                }
            }
        }
    }

    // ── Full representation (popup) ───────────────────────────────────────
    fullRepresentation: FullRepresentation {
        keyListData:   root.keyList
        keyStatesData: root.keyStates
        onWarmupRequested:     function(index) { root.warmupSlot(index) }
        onFetchRequested:      function(index) { root.fetchQuota(index) }
        onRefreshAllRequested: root.refreshAll()
    }
}

