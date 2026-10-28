"""The live process table and its actions: SIGTERM, SIGKILL and renice, plus
a detailed look at one process (memory maps, open files, family).

The poller reads every process on its own thread (only while the Processes
tab is on screen); filtering and sorting happen on the GUI thread over the
last read, so a click on a column header re-sorts at once. An action the
kernel refuses (another user's process, or a nice below the current one) is
retried through pkexec, which asks for the admin password.
"""

import getpass
import os
import signal
import time

import psutil
from PySide6.QtCore import QObject, QProcess, Property, Signal, Slot

from .common import Poller, RowsModel, start_poller

INTERVAL_MS = 1500
KEYS = ["pid", "name", "user", "system", "cpu", "memMb", "memPct", "read", "write",
        "status", "threads", "nice", "cmd"]
SORTABLE = {"pid", "name", "user", "cpu", "memMb", "read", "write", "threads", "nice"}
QUICK_FILTERS = ("all", "mine", "system", "heavy")
HEAVY_CPU = 5          # % of the whole machine
FIRST_LOGIN_UID = 1000
MAX_MAPS = 40
MAX_FILES = 80


class _Reader:
    def __init__(self):
        self.ncpu = psutil.cpu_count() or 1
        self.prev_io = {}

    def read(self):
        now = time.monotonic()
        rows, io_now = [], {}
        attrs = ["pid", "name", "username", "uids", "cpu_percent", "memory_info", "memory_percent",
                 "io_counters", "status", "num_threads", "nice", "cmdline"]
        for p in psutil.process_iter(attrs, ad_value=None):
            i = p.info
            io, read, write = i.get("io_counters"), -1, -1
            if io is not None:
                io_now[i["pid"]] = (io.read_bytes, io.write_bytes, now)
                old = self.prev_io.get(i["pid"])
                if old and now > old[2]:
                    read = max(0, (io.read_bytes - old[0]) / (now - old[2]))
                    write = max(0, (io.write_bytes - old[1]) / (now - old[2]))
                else:
                    read = write = 0
            mem, uids = i.get("memory_info"), i.get("uids")
            rows.append({
                "pid": i["pid"],
                "name": i.get("name") or "?",
                "user": i.get("username") or "?",
                "system": uids is not None and uids.real < FIRST_LOGIN_UID,
                # psutil counts one core as 100 %; the table shows share of the whole machine.
                "cpu": (i.get("cpu_percent") or 0) / self.ncpu,
                "memMb": (mem.rss / 2**20) if mem else 0,
                "memPct": i.get("memory_percent") or 0,
                "read": read,
                "write": write,
                "status": i.get("status") or "",
                "threads": i.get("num_threads") or 0,
                "nice": i.get("nice") if i.get("nice") is not None else 0,
                "cmd": " ".join(i.get("cmdline") or []).replace("\n", " ")[:400],
            })
        self.prev_io = io_now
        return rows


def _try(fn, default=None):
    """fn(), or `default` when the process hides it from us or has gone."""
    try:
        return fn()
    except (psutil.AccessDenied, psutil.ZombieProcess, psutil.NoSuchProcess, OSError):
        return default


class ProcessManager(QObject):
    changed = Signal()
    actionResult = Signal(str, bool)     # message, ok

    def __init__(self, parent=None):
        super().__init__(parent)
        self._me = getpass.getuser()
        self._raw = []
        self._model = RowsModel(KEYS, self)
        self._filter = ""
        self._quick = "all"
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

    def setInterval(self, ms):
        self._poller.retime.emit(ms)

    def _on_rows(self, rows):
        self._raw = rows
        self._apply()

    def _keep(self, r):
        q = self._quick
        return (q == "all" or (q == "mine" and r["user"] == self._me)
                or (q == "system" and r["system"]) or (q == "heavy" and r["cpu"] > HEAVY_CPU))

    def _apply(self):
        needle = self._filter.lower()
        rows = [r for r in self._raw
                if self._keep(r)
                and (not needle or needle in r["name"].lower() or needle in str(r["pid"])
                     or needle in r["cmd"].lower())]
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

    def _set_quick(self, which):
        if which in QUICK_FILTERS and which != self._quick:
            self._quick = which
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
            self._descending = key not in ("name", "user", "pid", "nice")
        self._apply()

    def _refuse(self, pid):
        if pid <= 1 or pid == os.getpid():
            self.actionResult.emit(f"REFUSED: PID {pid} IS LOAD-BEARING", False)
            return True
        return False

    @Slot(int, str)
    def sendSignal(self, pid, which):
        """which: "TERM" or "KILL"."""
        if self._refuse(pid):
            return
        sig = signal.SIGKILL if which == "KILL" else signal.SIGTERM
        try:
            name = psutil.Process(pid).name()
            psutil.Process(pid).send_signal(sig)
            self.actionResult.emit(f"SIG{which} SENT TO {name} ({pid})", True)
            self._poller.poke.emit()
        except psutil.NoSuchProcess:
            self.actionResult.emit(f"PID {pid} HAS ALREADY LEFT THE GALAXY", True)
            self._poller.poke.emit()
        except psutil.AccessDenied:
            self._escalate(pid, ["kill", "-s", which, str(pid)], f"SIG{which} SENT TO PID {pid} (AS ROOT)")

    @Slot(int, int)
    def setNice(self, pid, nice):
        """-20 (most favoured) to 19. Lowering a nice value needs root."""
        if self._refuse(pid):
            return
        nice = max(-20, min(19, nice))
        try:
            proc = psutil.Process(pid)
            proc.nice(nice)
            self.actionResult.emit(f"NICE {nice:+d} SET ON {proc.name()} ({pid})", True)
            self._poller.poke.emit()
        except psutil.NoSuchProcess:
            self.actionResult.emit(f"PID {pid} HAS ALREADY LEFT THE GALAXY", True)
            self._poller.poke.emit()
        except psutil.AccessDenied:
            self._escalate(pid, ["renice", "-n", str(nice), "-p", str(pid)], f"NICE {nice:+d} SET ON PID {pid} (AS ROOT)")

    def _escalate(self, pid, argv, ok_message):
        proc = QProcess(self)
        self._jobs.add(proc)

        def done(code, _status):
            self._jobs.discard(proc)
            err = bytes(proc.readAllStandardError()).decode(errors="replace").strip()
            if code == 0:
                self.actionResult.emit(ok_message, True)
            elif code in (126, 127):
                self.actionResult.emit(f"AUTHORISATION DECLINED FOR PID {pid}", False)
            else:
                self.actionResult.emit(err.upper() or f"{argv[0].upper()} FAILED ON PID {pid}", False)
            proc.deleteLater()
            self._poller.poke.emit()

        proc.finished.connect(done)
        proc.errorOccurred.connect(lambda e: e == QProcess.FailedToStart and (
            self._jobs.discard(proc), self.actionResult.emit("PKEXEC UNAVAILABLE: PERMISSION DENIED", False)))
        self.actionResult.emit(f"PID {pid} NEEDS MORE CLEARANCE: REQUESTING AUTHORISATION...", True)
        proc.start("pkexec", argv)

    @Slot(int, result="QVariantMap")
    def details(self, pid):
        """Everything the properties dialog shows. Fields the kernel will not
        tell us about another user's process come back empty, and `denied`
        lists them."""
        try:
            p = psutil.Process(pid)
        except psutil.NoSuchProcess:
            return {"pid": pid, "gone": True}
        denied = []

        def get(label, fn, default=None):
            try:
                return fn()
            except (psutil.AccessDenied, psutil.ZombieProcess):
                denied.append(label)
            except (psutil.NoSuchProcess, OSError):
                pass
            return default

        with p.oneshot():
            out = {
                "pid": pid,
                "gone": False,
                "name": _try(p.name, "?"),
                "exe": get("executable", p.exe, ""),
                "cmd": " ".join(get("command line", p.cmdline, []) or []),
                "cwd": get("working directory", p.cwd, ""),
                "user": _try(p.username, "?"),
                "status": _try(p.status, ""),
                "started": _try(p.create_time, 0),
                "threads": _try(p.num_threads, 0),
                "nice": _try(p.nice, 0),
                "cpu": _try(lambda: sum(p.cpu_times()[:2]), 0),
            }
            mem = get("unique memory (USS, PSS, swap)", p.memory_full_info) or _try(p.memory_info)
            out["memory"] = {k: getattr(mem, k) for k in ("rss", "vms", "shared", "uss", "pss", "swap")
                             if mem is not None and hasattr(mem, k)}
            out["fds"] = get("file descriptors", p.num_fds, -1)

        out["parents"] = [{"pid": a.pid, "name": _try(a.name, "?")} for a in reversed(_try(p.parents, []))]
        out["children"] = [{"pid": c.pid, "name": _try(c.name, "?")} for c in _try(p.children, [])]

        maps = get("memory maps", lambda: p.memory_maps(grouped=True), []) or []
        maps = sorted(maps, key=lambda m: m.rss, reverse=True)
        out["mapCount"] = len(maps)
        out["maps"] = [{"path": m.path or "[anon]", "rss": m.rss, "size": getattr(m, "size", 0)}
                       for m in maps[:MAX_MAPS]]

        files = get("open files", p.open_files, []) or []
        out["fileCount"] = len(files)
        out["files"] = [{"fd": f.fd, "path": f.path} for f in sorted(files, key=lambda f: f.fd)[:MAX_FILES]]
        out["denied"] = denied
        return out

    model = Property(QObject, lambda self: self._model, constant=True)
    active = Property(bool, lambda self: self._active, _set_active, notify=changed)
    filterText = Property(str, lambda self: self._filter, _set_filter, notify=changed)
    quickFilter = Property(str, lambda self: self._quick, _set_quick, notify=changed)
    sortKey = Property(str, lambda self: self._sort_key, notify=changed)
    sortDescending = Property(bool, lambda self: self._descending, notify=changed)
    total = Property(int, lambda self: len(self._raw), notify=changed)
    currentUser = Property(str, lambda self: self._me, constant=True)
    heavyCpu = Property(int, lambda self: HEAVY_CPU, constant=True)
