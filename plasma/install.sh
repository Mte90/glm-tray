#!/usr/bin/env bash
# install.sh — install the GLM Tray plasmoid into the current user's KDE Plasma session.
#
# Usage:
#   ./install.sh           — install (or re-install / upgrade) the plasmoid
#   ./install.sh --remove  — uninstall the plasmoid

set -euo pipefail

PLASMOID_ID="com.github.mte90.glm_tray"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="${SCRIPT_DIR}/package"

if [[ "${1:-}" == "--remove" ]]; then
    echo "Removing plasmoid '${PLASMOID_ID}'…"
    kpackagetool6 --remove "${PLASMOID_ID}" 2>/dev/null \
        || plasmapkg2 --remove "${PLASMOID_ID}" 2>/dev/null \
        || { echo "Error: could not remove plasmoid (neither plasmapkg2 nor kpackagetool6 found)"; exit 1; }
    echo "Done. You may need to restart Plasma: kquitapp6 plasmashell && kstart plasmashell"
    exit 0
fi

echo "Installing plasmoid from '${PACKAGE_DIR}'…"

# Try kpackagetool6 (Plasma 6) first, fall back to plasmapkg2 (Plasma 5)
if command -v kpackagetool6 &>/dev/null; then
    kpackagetool6 --type Plasma/Applet --install "${PACKAGE_DIR}"
elif command -v plasmapkg2 &>/dev/null; then
    plasmapkg2 --type Plasma/Applet --install "${PACKAGE_DIR}"
else
    echo "Error: neither kpackagetool6 nor plasmapkg2 found."
    echo "Please install the plasma-framework or plasma6-framework package."
    exit 1
fi

echo ""
echo "✓ GLM Tray plasmoid installed."
echo ""
echo "To add it to your panel:"
echo "  1. Right-click the panel → 'Add Widgets'"
echo "  2. Search for 'GLM Tray'"
echo "  3. Drag it onto the panel"
echo ""
echo "To reload without restarting Plasma (Plasma 6):"
echo "  kquitapp6 plasmashell && kstart plasmashell"
