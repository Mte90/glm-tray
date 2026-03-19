# GLM Tray — KDE Plasma Plasmoid

A KDE Plasma 6 panel widget for monitoring and managing Z.ai / BigModel API keys — a native Linux alternative to the Tauri-based desktop app.

## Features

- **Panel icon** with a colour-coded status dot (green / amber / red)
- **Popup** showing quota cards for up to 4 API keys
  - 5-hour tokens-usage progress bar
  - Monthly requests progress bar with used / total counts
  - Countdown to next quota reset
  - Account level badge (pro, free, …)
- **Warm-up button** per key — sends a minimal chat request to activate the 5-hour rolling window
- **Per-key refresh** and **Refresh All**
- **Automatic polling** at a configurable interval per key (default: 30 min)
- **Supports both platforms**: Z.ai (`api.z.ai`) and BigModel (`open.bigmodel.cn`)
- **In-panel configuration** — right-click the widget → Configure

## Requirements

| Requirement | Version |
|-------------|---------|
| KDE Plasma  | 6.0 +   |
| Qt          | 6.x     |
| Kirigami    | 6.x     |

## Installation

```bash
cd plasma
./install.sh
```

To remove:

```bash
cd plasma
./install.sh --remove
```

### Manual installation

```bash
kpackagetool6 --type Plasma/Applet --install plasma/package
# or upgrade an existing installation:
kpackagetool6 --type Plasma/Applet --upgrade plasma/package
```

## Adding to the panel

1. Right-click the KDE panel → **Add Widgets**
2. Search for **GLM Tray**
3. Drag it onto the panel

## Configuration

Right-click the widget → **Configure GLM Tray**

### Keys tab

For each key slot you can configure:

| Field | Description |
|-------|-------------|
| Enabled | Activate this slot |
| Display name | Label shown in the popup |
| API key | Your Z.ai or BigModel API key (stored in `~/.config/plasma-org.kde.plasma.desktop-appletsrc`) |
| Platform | **Z.ai** or **BigModel** |
| Poll interval | How often to refresh quota data (minutes, default: 30) |

## Architecture

```
plasma/
├── install.sh                       # Installation helper
├── README.md                        # This file
└── package/
    ├── metadata.json                # Widget metadata (Plasma 6)
    └── contents/
        ├── config/
        │   ├── main.xml             # KConfigXT schema (all settings)
        │   └── config.qml           # Config dialog page list
        └── ui/
            ├── main.qml             # Root PlasmoidItem — logic + compact icon
            ├── FullRepresentation.qml  # Expanded popup UI
            └── configpages/
                └── KeysConfig.qml   # Per-key configuration form
```

### Data flow

```
Plasmoid.configuration  ←→  KeysConfig page
        │
        ▼
   main.qml (keyConfig() helper)
        │
        ├─ Timer (every 30 s) ──► fetchQuota(slot) ──► Z.ai / BigModel API
        │                                               ▼
        │                                         keyStates[slot] updated
        │                                               ▼
        └─ fullRepresentation: FullRepresentation { keyStatesData: root.keyStates }
```

### API endpoints used

| Action | Method | URL |
|--------|--------|-----|
| Fetch quota | `GET` | `https://api.z.ai/api/monitor/usage/quota/limit` |
| Warm up | `POST` | `https://api.z.ai/api/coding/paas/v4/chat/completions` |

Same paths apply to BigModel using `https://open.bigmodel.cn` as the base.

All requests use `Authorization: Bearer <api_key>` headers.

## Security note

API keys are stored in plain text inside the standard KDE config file:

```
~/.config/plasma-org.kde.plasma.desktop-appletsrc
```

This file is readable only by the current user (mode `0600`) on most distributions.
For additional security, consider using KWallet integration in a future version.

## License

MIT — see the root [LICENSE](../LICENSE) file.
