#!/usr/bin/env bash
# Install the Sub-Etha System Monitor for the current user.
#
#   ./install.sh               launcher in ~/.local/bin, menu entry, icon
#   ./install.sh --uninstall   remove them again (keeps ~/.config/subetha-monitor.json)
set -euo pipefail
cd "$(dirname "$0")"
APP_DIR="$(pwd)"

BIN_DIR="$HOME/.local/bin"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
DESKTOP="$DATA/applications/subetha-monitor.desktop"
ICON="$DATA/icons/hicolor/256x256/apps/subetha-monitor.png"

refresh() {
    update-desktop-database -q "$DATA/applications" 2>/dev/null || true
    gtk-update-icon-cache -q -t "$DATA/icons/hicolor" 2>/dev/null || true
    kbuildsycoca6 >/dev/null 2>&1 || true
}

case "${1:-}" in
    -u|--uninstall)
        rm -f "$BIN_DIR/subetha-monitor" "$DESKTOP" "$ICON"
        refresh
        echo "Removed subetha-monitor"
        exit 0 ;;
    -h|--help) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    "") ;;
    *) echo "Unknown option: $1 (try --help)" >&2; exit 2 ;;
esac

# The first Python that has PySide6 and psutil: a pyenv or venv python3 on
# PATH often lacks the distribution's Qt bindings, so the system one is tried
# too.
PYTHON=""
for py in python3 /usr/bin/python3 /usr/local/bin/python3; do
    if command -v "$py" >/dev/null && "$py" -c "import PySide6.QtQuick, psutil" 2>/dev/null; then
        PYTHON="$(command -v "$py")"
        break
    fi
done
if [ -z "$PYTHON" ]; then
    echo "No python3 with PySide6 and psutil found. Install them, e.g." >&2
    echo "  Arch:   sudo pacman -S pyside6 python-psutil" >&2
    echo "  Fedora: sudo dnf install python3-pyside6 python3-psutil" >&2
    echo "  Debian: sudo apt install python3-pyside6.qtquick python3-psutil  (or: pip install -r requirements.txt)" >&2
    exit 1
fi

mkdir -p "$BIN_DIR" "$(dirname "$DESKTOP")" "$(dirname "$ICON")"
cat > "$BIN_DIR/subetha-monitor" <<LAUNCHER
#!/bin/sh
exec "$PYTHON" "$APP_DIR/main.py" "\$@"
LAUNCHER
chmod +x "$BIN_DIR/subetha-monitor"

# Absolute paths in the entry: a session's launcher may not have ~/.local/bin on PATH.
sed -e "s|^Exec=subetha-monitor|Exec=$BIN_DIR/subetha-monitor|" \
    -e "s|^TryExec=subetha-monitor|TryExec=$BIN_DIR/subetha-monitor|" \
    subetha-monitor.desktop > "$DESKTOP"
cp subetha-monitor.png "$ICON"
refresh

echo "Installed subetha-monitor ($PYTHON)"
echo "  launcher: $BIN_DIR/subetha-monitor"
echo "  menu:     $DESKTOP"
