"""systemd service units over D-Bus (org.freedesktop.systemd1).

Calls go through busctl, systemd's own D-Bus client, which returns typed
JSON and handles polkit's interactive authorisation for system units, so
starting or stopping a system service asks for the password the usual way.
Every call runs as an asynchronous QProcess; the window never waits on the
bus.
"""

import json

from PySide6.QtCore import QObject, QProcess, QTimer, Property, Signal, Slot

from .common import RowsModel

DEST = ["org.freedesktop.systemd1", "/org/freedesktop/systemd1", "org.freedesktop.systemd1.Manager"]
KEYS = ["name", "description", "load", "active", "sub", "scope", "pending"]
ACTIONS = {"start": "StartUnit", "stop": "StopUnit", "restart": "RestartUnit"}
POLL_MS = 4000


class SystemdManager(QObject):
    changed = Signal()
    actionResult = Signal(str, bool)     # message, ok

    def __init__(self, parent=None):
        super().__init__(parent)
        self._model = RowsModel(KEYS, self)
        self._units = {"system": [], "user": []}
        self._scope = "system"
        self._filter = ""
        self._state = "all"              # all | active | inactive | failed
        self._active = False
        self._loading = False
        self._pending = {}               # unit name -> action in flight
        self._jobs = set()
        self._error = ""

        self._timer = QTimer(self)
        self._timer.setInterval(POLL_MS)
        self._timer.timeout.connect(self.refresh)

    def _busctl(self, scope, args, on_done):
        proc = QProcess(self)
        self._jobs.add(proc)

        def finished(code, _status):
            self._jobs.discard(proc)
            out = bytes(proc.readAllStandardOutput()).decode(errors="replace")
            err = bytes(proc.readAllStandardError()).decode(errors="replace").strip()
            proc.deleteLater()
            on_done(code, out, err)

        proc.finished.connect(finished)
        proc.errorOccurred.connect(lambda e: e == QProcess.FailedToStart and finished(-1, None))
        base = ["--user"] if scope == "user" else []
        proc.start("busctl", base + ["--json=short", "call"] + DEST + args)

    # ---- listing ----
    @Slot()
    def refresh(self):
        if self._loading:
            return
        self._loading = True
        self.changed.emit()
        scope = self._scope

        def done(code, out, err):
            self._loading = False
            if code == 0:
                try:
                    units = json.loads(out)["data"][0]
                except (ValueError, KeyError, IndexError):
                    units = []
                self._units[scope] = [{"name": u[0], "description": u[1], "load": u[2], "active": u[3],
                                       "sub": u[4], "scope": scope} for u in units]
                self._error = ""
            else:
                self._error = (err or "busctl unavailable").upper()
            self._apply()

        self._busctl(scope, ["ListUnitsByPatterns", "asas", "0", "1", "*.service"], done)

    def _apply(self):
        needle = self._filter.lower()
        state = self._state
        rows = [dict(u, pending=self._pending.get(u["name"], "")) for u in self._units[self._scope]
                if (not needle or needle in u["name"].lower() or needle in u["description"].lower())
                and (state == "all" or u["active"] == state
                     or (state == "inactive" and u["active"] not in ("active", "failed")))]
        rows.sort(key=lambda u: ({"failed": 0, "active": 1}.get(u["active"], 2) if state == "all" else 0,
                                 u["name"].lower()))
        self._model.set_rows(rows)
        self.changed.emit()

    # ---- control ----
    @Slot(str, str)
    def control(self, unit, action):
        method = ACTIONS.get(action)
        if not method or unit in self._pending:
            return
        scope = self._scope
        self._pending[unit] = action
        self.actionResult.emit(f"{action.upper()} {unit}...", True)

        def done(code, _out, err):
            self._pending.pop(unit, None)
            if code == 0:
                self.actionResult.emit(f"{action.upper()} {unit}: JOB QUEUED", True)
            else:
                msg = err.split("\n")[-1] if err else "FAILED"
                self.actionResult.emit(f"{action.upper()} {unit}: {msg}".upper(), False)
            # Give the job a moment to change the unit's state, then re-read.
            QTimer.singleShot(700, self.refresh)

        self._busctl(scope, [method, "ss", unit, "replace"], done)

    # ---- properties ----
    def _set_active(self, on):
        if on == self._active:
            return
        self._active = on
        if on:
            self.refresh()
            self._timer.start()
        else:
            self._timer.stop()
        self.changed.emit()

    def _set_scope(self, scope):
        if scope in ("system", "user") and scope != self._scope:
            self._scope = scope
            self._apply()          # the cached list at once, then a fresh read
            self.refresh()

    def _set_filter(self, text):
        if text != self._filter:
            self._filter = text
            self._apply()

    def _set_state(self, state):
        if state != self._state:
            self._state = state
            self._apply()

    def _counts(self):
        units = self._units[self._scope]
        return {"total": len(units),
                "active": sum(u["active"] == "active" for u in units),
                "failed": sum(u["active"] == "failed" for u in units)}

    model = Property(QObject, lambda self: self._model, constant=True)
    active = Property(bool, lambda self: self._active, _set_active, notify=changed)
    scope = Property(str, lambda self: self._scope, _set_scope, notify=changed)
    filterText = Property(str, lambda self: self._filter, _set_filter, notify=changed)
    stateFilter = Property(str, lambda self: self._state, _set_state, notify=changed)
    loading = Property(bool, lambda self: self._loading, notify=changed)
    error = Property(str, lambda self: self._error, notify=changed)
    counts = Property("QVariantMap", _counts, notify=changed)
