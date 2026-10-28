"""The live process table and its two actions, SIGTERM and SIGKILL.

The poller reads every process on its own thread (only while the Processes
tab is on screen); filtering and sorting happen on the GUI thread over the
last read, so a click on a column header re-sorts at once. A signal the
kernel refuses (another user's process) is retried through pkexec, which
asks for the admin password.
"""

import getpass
import os
import signal
import time

import psutil
from PySide6.QtCore import QObject, QProcess, Property, Signal, Slot

from .common import Poller, RowsModel, start_poller

INTERVAL_MS = 1500
KEYS = ["pid", "name", "user", "cpu", "memMb", "memPct", "io", "status", "threads", "cmd"]
SORTABLE = {"pid", "name", "user", "cpu", "memMb", "io"}


class _Reader:
    def __init__(self):
        self.ncpu = psutil.cpu_count() or 1
        self.prev_io = {}

    def read(self):
        now = time.monotonic()
        rows, io_now = [], {}
        attrs = ["pid", "name", "username", "cpu_percent", "memory_info", "memory_percent",
                 "io_counters", "status", "num_threads", "cmdline"]
        for p in psutil.process_iter(attrs, ad_value=None):
            i = p.info
            io, rate = i.get("io_counters"), -1
            if io is not None:
                total = io.read_bytes + io.write_bytes
                io_now[i["pid"]] = (total, now)
                old = self.prev_io.get(i["pid"])
                rate = max(0, (total - old[0]) / (now - old[1])) if old and now > old[1] else 0
            mem = i.get("memory_info")
            rows.append({
                "pid": i["pid"],
                "name": i.get("name") or "?",
                "user": i.get("username") or "?",
                # psutil counts one core as 100 %; the table shows share of the whole machine.
                "cpu": (i.get("cpu_percent") or 0) / self.ncpu,
                "memMb": (mem.rss / 2**20) if mem else 0,
                "memPct": i.get("memory_percent") or 0,
                "io": rate,
                "status": i.get("status") or "",
                "threads": i.get("num_threads") or 0,
                "cmd": " ".join(i.get("cmdline") or [])[:400],
            })
        self.prev_io = io_now
        return rows


class ProcessManager(QObject):
    changed = Signal()
    actionResult = Signal(str, bool)     # message, ok

    def __init__(self, parent=None):
        super().__init__(parent)
        self._me = getpass.getuser()
        self._raw = []
        self._model = RowsModel(KEYS, self)
        self._filter = ""
        self._user_only = False
        self._sort_key = "cpu"
        self._descending = True
        self._active = False
        self._jobs = set()

        self._poller = Poller(_Reader().read, INTERVAL_MS)
        self._poller.enabled = False
        self._poller.result.connect(self._on_rows)
        self._thread = start_poller(self._poller)

    def stop(self):
        self._thread.quit()
        self._thread.wait(3000)

    def _on_rows(self, rows):
        self._raw = rows
        self._apply()

    def _apply(self):
        needle = self._filter.lower()
        rows = [r for r in self._raw
                if (not self._user_only or r["user"] == self._me)
                and (not needle or needle in r["name"].lower() or needle in str(r["pid"])
                     or needle in r["user"].lower() or needle in r["cmd"].lower())]
        key = self._sort_key
        text = key in ("name", "user")
        rows.sort(key=lambda r: (r[key].lower() if text else r[key], r["pid"]), reverse=self._descending)
        self._model.set_rows(rows)
        self.changed.emit()

    # ---- QML ----
    def _set_active(self, on):
        if on == self._active:
            return
        self._active = on
        self._poller.enabled = on
        if on:
            self._poller.poke.emit()
        self.changed.emit()

    def _set_filter(self, text):
        if text != self._filter:
            self._filter = text
            self._apply()

    def _set_user_only(self, on):
        if on != self._user_only:
            self._user_only = on
            self._apply()

    @Slot(str)
    def sortBy(self, key):
        """A second click on the same column flips the order."""
        if key not in SORTABLE:
            return
        if key == self._sort_key:
            self._descending = not self._descending
        else:
            self._sort_key = key
            self._descending = key not in ("name", "user", "pid")
        self._apply()

    @Slot(int, str)
    def sendSignal(self, pid, which):
        """which: "TERM" or "KILL"."""
        sig = signal.SIGKILL if which == "KILL" else signal.SIGTERM
        if pid <= 1 or pid == os.getpid():
            self.actionResult.emit(f"REFUSED: PID {pid} IS LOAD-BEARING", False)
            return
        try:
            name = psutil.Process(pid).name()
            psutil.Process(pid).send_signal(sig)
            self.actionResult.emit(f"SIG{which} SENT TO {name} ({pid})", True)
            self._poller.poke.emit()
        except psutil.NoSuchProcess:
            self.actionResult.emit(f"PID {pid} HAS ALREADY LEFT THE GALAXY", True)
            self._poller.poke.emit()
        except psutil.AccessDenied:
            self._escalate(pid, which)

    def _escalate(self, pid, which):
        proc = QProcess(self)
        self._jobs.add(proc)

        def done(code, _status):
            self._jobs.discard(proc)
            err = bytes(proc.readAllStandardError()).decode(errors="replace").strip()
            if code == 0:
                self.actionResult.emit(f"SIG{which} SENT TO PID {pid} (AS ROOT)", True)
            elif code in (126, 127):
                self.actionResult.emit(f"AUTHORISATION DECLINED FOR PID {pid}", False)
            else:
                self.actionResult.emit(err.upper() or f"COULD NOT SIGNAL PID {pid}", False)
            proc.deleteLater()
            self._poller.poke.emit()

        proc.finished.connect(done)
        proc.errorOccurred.connect(lambda e: e == QProcess.FailedToStart and (
            self._jobs.discard(proc), self.actionResult.emit("PKEXEC UNAVAILABLE: PERMISSION DENIED", False)))
        self.actionResult.emit(f"PID {pid} BELONGS TO ANOTHER USER: REQUESTING AUTHORISATION...", True)
        proc.start("pkexec", ["kill", "-s", which, str(pid)])

    model = Property(QObject, lambda self: self._model, constant=True)
    active = Property(bool, lambda self: self._active, _set_active, notify=changed)
    filterText = Property(str, lambda self: self._filter, _set_filter, notify=changed)
    userOnly = Property(bool, lambda self: self._user_only, _set_user_only, notify=changed)
    sortKey = Property(str, lambda self: self._sort_key, notify=changed)
    sortDescending = Property(bool, lambda self: self._descending, notify=changed)
    total = Property(int, lambda self: len(self._raw), notify=changed)
    currentUser = Property(str, lambda self: self._me, constant=True)
