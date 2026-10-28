"""The theme the monitor shares with the Sub-Etha Guide widget.

Community skins live under ${XDG_DATA_HOME:-~/.local/share}/subetha/themes/<id>/
(installed by the widget's Theme Store); `installed` lists each one's raw
skin.json for the QML side, which parses it with qml/components/skins.js,
the widget's own parser.

The choice both apps follow is ${XDG_CONFIG_HOME:-~/.config}/subetha/theme_state.json:

    {"activeThemeId": "h2g2" | <skin id>, "variant": "dark" | "light" | "auto",
     "syncThemeAcrossApps": true}

"h2g2" is the Guide's own palette, and "auto" leaves each app to resolve day
and night its own way. The file is mirrored into Settings.skin and
Settings.theme: a change to either is written to the file (by rename), and a
change in the file, the widget's or a hand edit, lands in them within a few
milliseconds through a QFileSystemWatcher on the folder. At start-up the
file wins; without one, the monitor's own choice starts it. With
syncThemeAcrossApps off the monitor neither writes the theme nor follows it.
"""

import json
import os
import re
import sys

from PySide6.QtCore import QFileSystemWatcher, QObject, QTimer, Property, Signal, Slot

BUILTIN = "h2g2"
VARIANTS = ("dark", "light", "auto")
ID_RE = re.compile(r"^[a-z0-9._-]{1,64}$")
MAX_SKIN_BYTES = 256 * 1024
STATE_DIR = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "subetha")
STATE = os.path.join(STATE_DIR, "theme_state.json")
THEMES = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"), "subetha", "themes")


def valid_id(theme_id):
    return isinstance(theme_id, str) and bool(ID_RE.match(theme_id)) and not theme_id.startswith(".")


def list_skins():
    """[{id, dir, json}] for every installed skin with a readable skin.json."""
    out = []
    try:
        names = sorted(os.listdir(THEMES))
    except OSError:
        return out
    for name in names:
        path = os.path.join(THEMES, name, "skin.json")
        if not valid_id(name) or not os.path.isfile(path):
            continue
        try:
            if os.path.getsize(path) > MAX_SKIN_BYTES:
                continue
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
        except (OSError, ValueError):
            continue
        if isinstance(data, dict):
            out.append({"id": name, "dir": os.path.join(THEMES, name), "json": data})
    return out


class ThemeService(QObject):
    installedChanged = Signal()
    syncChanged = Signal()

    def __init__(self, settings, parent=None):
        super().__init__(parent)
        self._settings = settings
        self._installed = list_skins()
        self._sync = True
        self._last = None                  # (activeThemeId, variant) as last read or written
        self._applying = False             # mirroring the file into Settings: no echo back

        self._watcher = QFileSystemWatcher(self)
        self._watcher.directoryChanged.connect(self._changed)
        self._watcher.fileChanged.connect(self._changed)
        # A write is a burst of events (the temp file, the rename): read once it settles.
        self._state_timer = QTimer(self, singleShot=True, interval=15)
        self._state_timer.timeout.connect(self._read)
        self._skins_timer = QTimer(self, singleShot=True, interval=250)
        self._skins_timer.timeout.connect(self._rescan)
        try:
            os.makedirs(STATE_DIR, exist_ok=True)
        except OSError as e:
            print(f"subetha-monitor: cannot create {STATE_DIR}: {e}", file=sys.stderr)
        self._watch()

        settings.skinChanged.connect(self._push)
        settings.themeChanged.connect(self._push)
        self._read(start=True)

    # ---- watching ----
    def _watch(self):
        paths = [p for p in [STATE_DIR, STATE, THEMES] + [s["dir"] for s in self._installed] if os.path.exists(p)]
        missing = [p for p in paths if p not in self._watcher.directories() + self._watcher.files()]
        if missing:
            self._watcher.addPaths(missing)

    def _changed(self, path):
        if path in (STATE_DIR, STATE):
            self._state_timer.start()
        else:
            self._skins_timer.start()
        self._watch()                      # a renamed-over file drops its watch

    def _rescan(self):
        skins = list_skins()
        if skins != self._installed:
            self._installed = skins
            self.installedChanged.emit()
        self._watch()

    # ---- the state file ----
    def _read(self, start=False):
        try:
            with open(STATE, encoding="utf-8") as f:
                state = json.load(f)
        except (OSError, ValueError):
            state = None
        if not isinstance(state, dict) or not valid_id(state.get("activeThemeId")):
            if start:
                self._push()               # none yet: this window's theme starts it
            return
        sync = state.get("syncThemeAcrossApps") is not False
        if sync != self._sync:
            self._sync = sync
            self.syncChanged.emit()
        variant = state.get("variant") if state.get("variant") in VARIANTS else self._settings.theme
        self._last = (state["activeThemeId"], variant)
        if sync:
            self._applying = True
            try:
                self._settings.setProperty("skin", state["activeThemeId"])
                self._settings.setProperty("theme", variant)
            finally:
                self._applying = False

    def _write(self, theme_id, variant, sync):
        tmp = os.path.join(STATE_DIR, ".theme_state.json.monitor")
        try:
            os.makedirs(STATE_DIR, exist_ok=True)
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump({"activeThemeId": theme_id, "variant": variant, "syncThemeAcrossApps": sync}, f, indent=2)
                f.write("\n")
            os.replace(tmp, STATE)
        except OSError as e:
            print(f"subetha-monitor: cannot save {STATE}: {e}", file=sys.stderr)
        self._watch()

    def _push(self):
        if not self._sync or self._applying:
            return
        state = (self._settings.skin, self._settings.theme)
        if state != self._last:
            self._last = state
            self._write(*state, True)

    # ---- for QML ----
    installed = Property("QVariantList", lambda self: self._installed, notify=installedChanged)
    builtin = Property(str, lambda self: BUILTIN, constant=True)
    stateFile = Property(str, lambda self: STATE, constant=True)
    themesDir = Property(str, lambda self: THEMES, constant=True)

    def _set_sync(self, on):
        on = bool(on)
        if on == self._sync:
            return
        self._sync = on
        self.syncChanged.emit()
        # Turning it on hands this window's theme to the widget; off, the
        # file keeps its theme and only the flag changes.
        if on or not self._last:
            self._last = (self._settings.skin, self._settings.theme)
        self._write(*self._last, on)

    sync = Property(bool, lambda self: self._sync, _set_sync, notify=syncChanged)

    @Slot(str, str)
    def setTheme(self, theme_id, variant):
        """Apply a skin ("h2g2" for the Guide's own) and a variant; both apps follow while synced."""
        if valid_id(theme_id):
            self._settings.setProperty("skin", theme_id)
        if variant in VARIANTS:
            self._settings.setProperty("theme", variant)
