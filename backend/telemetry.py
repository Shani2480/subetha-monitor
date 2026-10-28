"""Hardware telemetry: CPU, memory, GPU, fans, network, storage and battery.

Everything is read from /proc and /sys (through psutil where it reads the
same files), on the poller's thread, every 1.5 s unless the settings say
otherwise. A sample is one plain dict handed to QML as a QVariantMap; rolling
histories ride along in it. Static facts (models, kernel, RAM size) are read
once into `specs`. The public WAN address is fetched from api.ipify.org on
the GUI thread when the active connection changes.
"""

import glob
import os
import platform
import re
import shutil
import socket
import subprocess
import time
from collections import deque

import psutil
from PySide6.QtCore import QObject, QUrl, Property, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtNetwork import QNetworkAccessManager, QNetworkReply, QNetworkRequest

from .common import Poller, start_poller

INTERVAL_MS = 1500
HISTORY = 24          # overview sparklines
FAN_FULL_RPM = 6000   # a fan's full speed when the kernel gives no fan*_max
NET_HISTORY = 60      # network tab curves
SECTOR = 512          # /proc/diskstats counts 512-byte sectors on every device

SKIP_FS = {"squashfs", "overlay", "tmpfs", "devtmpfs", "ramfs", "autofs", "efivarfs"}


def _read(path, default=None):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def _read_int(path, default=None):
    try:
        return int(_read(path))
    except (TypeError, ValueError):
        return default


# ---- names ----

def cpu_model():
    """"AMD Ryzen 7 9800X3D 8-Core Processor" -> "AMD Ryzen 7 9800X3D"."""
    name = ""
    for line in (_read("/proc/cpuinfo", "") or "").splitlines():
        if line.startswith("model name"):
            name = line.split(":", 1)[1]
            break
    name = re.sub(r"\s+\d+-Core Processor\s*$", "", name, flags=re.I)
    name = re.sub(r"\s+with Radeon Graphics\s*$", "", name, flags=re.I)
    name = re.sub(r"\((R|TM)\)", "", name)
    name = re.sub(r"\s+CPU\s+@.*$", "", name)
    return re.sub(r"\s+", " ", name).strip() or platform.processor() or "UNKNOWN"


VENDORS = [(r"AMD|ATI", "AMD"), (r"NVIDIA", "NVIDIA"), (r"Intel", "Intel")]


def lspci_name(slot):
    """lspci -mm: "77:00.0" "VGA ..." "Advanced Micro Devices, Inc. [AMD/ATI]"
    "Rembrandt [Radeon 680M]" -> "AMD Radeon 680M"."""
    if not shutil.which("lspci"):
        return ""
    try:
        out = subprocess.run(["lspci", "-mm", "-s", slot], capture_output=True,
                             text=True, timeout=3).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""
    fields = re.findall(r'"([^"]*)"', out)
    if len(fields) < 3:
        return ""
    vendor = next((v for pat, v in VENDORS if re.search(pat, fields[1])), "")
    model = (re.search(r"\[([^\]]+)\]", fields[2]) or [None, fields[2]])[1]
    return (vendor + " " if vendor and not model.startswith(vendor) else "") + model


def os_name():
    for line in (_read("/etc/os-release", "") or "").splitlines():
        if line.startswith("PRETTY_NAME="):
            return line.split("=", 1)[1].strip('"')
    return platform.system()


# ---- discovery ----

def discover_gpus():
    """Every DRM card with a PCI device: AMD reports load in sysfs, NVIDIA
    through NVML (pynvml) or nvidia-smi, Intel only its temperature."""
    gpus = []
    for card in sorted(glob.glob("/sys/class/drm/card[0-9]*")):
        if "-" in os.path.basename(card):          # connectors: card1-DP-1
            continue
        dev = os.path.join(card, "device")
        if not os.path.isdir(dev):
            continue
        slot = os.path.basename(os.path.realpath(dev))
        hwmon = sorted(glob.glob(dev + "/hwmon/hwmon*"))
        vendor = {"0x1002": "amd", "0x10de": "nvidia", "0x8086": "intel"}.get(_read(dev + "/vendor"), "other")
        gpus.append({
            "dev": dev, "slot": slot, "vendor": vendor,
            "hwmon": hwmon[0] if hwmon else None,
            "name": lspci_name(slot) or os.path.basename(card),
            "vram": _read_int(dev + "/mem_info_vram_total", 0),
        })
    # The discrete card (most VRAM, NVIDIA otherwise) leads.
    gpus.sort(key=lambda g: (g["vendor"] == "nvidia", g["vram"]), reverse=True)
    return gpus


FAN_NAMES = {"amdgpu": "GPU", "nouveau": "GPU", "k10temp": "CPU", "coretemp": "CPU"}


def discover_fans():
    fans = []
    for path in sorted(glob.glob("/sys/class/hwmon/hwmon*/fan*_input"),
                       key=lambda p: [int(n) for n in re.findall(r"\d+", p)]):
        d = os.path.dirname(path)
        n = re.search(r"fan(\d+)_input$", path).group(1)
        chip = _read(d + "/name", "hwmon")
        label = _read(f"{d}/fan{n}_label") or FAN_NAMES.get(chip) or f"{chip} {n}"
        label = label.replace("_", " ").upper()
        fans.append({"path": path, "label": label, "chip": chip,
                     "max": _read_int(f"{d}/fan{n}_max", 0)})
    # Two "CPU FAN"s become "CPU FAN 1" and "CPU FAN 2".
    seen = {}
    for f in fans:
        seen[f["label"]] = seen.get(f["label"], 0) + 1
    count = {}
    for f in fans:
        if seen[f["label"]] > 1:
            count[f["label"]] = count.get(f["label"], 0) + 1
            f["label"] = f"{f['label']} {count[f['label']]}"
    return fans


def default_iface():
    """The interface holding the lowest-metric default route."""
    best = None
    for line in (_read("/proc/net/route", "") or "").splitlines()[1:]:
        f = line.split()
        if len(f) > 6 and f[1] == "00000000":
            metric = int(f[6])
            if best is None or metric < best[1]:
                best = (f[0], metric)
    return best[0] if best else ""


class _Nvml:
    """NVIDIA readings through pynvml when installed, else nvidia-smi."""

    def __init__(self):
        self.nvml = None
        try:
            import pynvml
            pynvml.nvmlInit()
            self.nvml = pynvml
        except Exception:
            pass
        self.smi = shutil.which("nvidia-smi")

    def read(self, index=0):
        if self.nvml:
            n = self.nvml
            h = n.nvmlDeviceGetHandleByIndex(index)
            util = n.nvmlDeviceGetUtilizationRates(h)
            mem = n.nvmlDeviceGetMemoryInfo(h)
            temp = n.nvmlDeviceGetTemperature(h, n.NVML_TEMPERATURE_GPU)
            try:
                power = n.nvmlDeviceGetPowerUsage(h) / 1000
            except Exception:
                power = 0
            return {"usage": util.gpu, "memUsage": util.memory, "vramUsed": mem.used,
                    "vramTotal": mem.total, "temp": temp, "power": power}
        if self.smi:
            out = subprocess.run([self.smi, "--query-gpu=utilization.gpu,utilization.memory,memory.used,"
                                  "memory.total,temperature.gpu,power.draw", "--format=csv,noheader,nounits",
                                  f"--id={index}"], capture_output=True, text=True, timeout=3).stdout
            v = [x.strip() for x in out.split(",")]
            if len(v) >= 6:
                num = lambda s: float(s) if re.match(r"^[\d.]+$", s) else 0
                return {"usage": num(v[0]), "memUsage": num(v[1]), "vramUsed": num(v[2]) * 2**20,
                        "vramTotal": num(v[3]) * 2**20, "temp": num(v[4]), "power": num(v[5])}
        return {}


class Collector:
    """Turns successive reads into rates and rolling histories."""

    def __init__(self):
        self.gpus = discover_gpus()
        self.fans = discover_fans()
        self.nv = _Nvml() if any(g["vendor"] == "nvidia" for g in self.gpus) else None
        self.prev_net = None
        self.prev_disk = None
        self.prev_t = None
        self.hist = {k: deque(maxlen=HISTORY) for k in ("cpu", "gpu", "ram", "rx", "tx", "diskRead", "diskWrite")}
        self.net_hist = {k: deque(maxlen=NET_HISTORY) for k in ("rx", "tx")}
        self.fan_hist = {}
        self.fan_peak = {}
        self.disk_hist = {}
        self.ticks = 0
        psutil.cpu_percent(percpu=True)   # prime: the first real call measures from here

    # ---- static facts ----
    def specs(self):
        threads = psutil.cpu_count() or 0
        return {
            "host": socket.gethostname(),
            "cpuModel": cpu_model(),
            "cores": psutil.cpu_count(logical=False) or threads,
            "threads": threads,
            "gpuModel": self.gpus[0]["name"] if self.gpus else "NO GRAPHICS ENGINE",
            "gpuModels": [g["name"] for g in self.gpus],
            "ramTotal": psutil.virtual_memory().total,
            "kernel": platform.release(),
            "os": os_name(),
            "bootTime": psutil.boot_time(),
        }

    # ---- one sample ----
    def sample(self):
        now = time.monotonic()
        dt = (now - self.prev_t) if self.prev_t else None
        self.prev_t = now
        self.ticks += 1
        if self.ticks % 40 == 0:          # once a minute: hot-plugged fans
            self.fans = discover_fans()

        s = {
            "cpu": self._cpu(),
            "mem": self._mem(),
            "gpu": self._gpu(),
            "fans": self._fans(),
            "net": self._net(dt),
            "battery": self._battery(),
            "uptime": time.time() - psutil.boot_time(),
        }
        s["disks"], s["diskRead"], s["diskWrite"] = self._disks(dt)

        h = self.hist
        h["cpu"].append(s["cpu"]["usage"] / 100)
        h["gpu"].append(s["gpu"].get("usage", 0) / 100)
        h["ram"].append(s["mem"]["percent"] / 100)
        h["rx"].append(s["net"]["rx"])
        h["tx"].append(s["net"]["tx"])
        h["diskRead"].append(s["diskRead"])
        h["diskWrite"].append(s["diskWrite"])
        self.net_hist["rx"].append(s["net"]["rx"])
        self.net_hist["tx"].append(s["net"]["tx"])
        s["history"] = {k: list(v) for k, v in h.items()}
        s["netHistory"] = {k: list(v) for k, v in self.net_hist.items()}
        s["fanHistory"] = {k: list(v) for k, v in self.fan_hist.items()}
        s["diskHistory"] = {k: {"read": list(v[0]), "write": list(v[1])} for k, v in self.disk_hist.items()}
        return s

    def _cpu(self):
        cores = psutil.cpu_percent(percpu=True)
        freq = psutil.cpu_freq()
        temp = 0
        temps = psutil.sensors_temperatures()
        for chip in ("k10temp", "zenpower", "coretemp", "cpu_thermal", "acpitz"):
            readings = temps.get(chip)
            if not readings:
                continue
            pick = next((r for r in readings if r.label in ("Tctl", "Tdie", "Package id 0")), readings[0])
            temp = pick.current or 0
            break
        return {
            "usage": sum(cores) / len(cores) if cores else 0,
            "perCore": cores,
            "temp": temp,
            "freq": freq.current if freq else 0,
            "freqMax": freq.max if freq else 0,
            "load": list(os.getloadavg()),
        }

    def _mem(self):
        vm, sw = psutil.virtual_memory(), psutil.swap_memory()
        return {
            "total": vm.total, "used": vm.used, "available": vm.available,
            "cached": getattr(vm, "cached", 0) + getattr(vm, "buffers", 0),
            "percent": vm.percent,
            "swapTotal": sw.total, "swapUsed": sw.used, "swapPercent": sw.percent,
        }

    def _gpu(self):
        if not self.gpus:
            return {"present": False}
        g = self.gpus[0]
        out = {"present": True, "name": g["name"], "vendor": g["vendor"], "usage": 0, "memUsage": 0,
               "vramUsed": 0, "vramTotal": 0, "temp": 0, "junction": 0, "memTemp": 0, "power": 0}
        dev = g["dev"]
        if g["vendor"] == "nvidia" and self.nv:
            try:
                out.update(self.nv.read())
            except Exception:
                pass
        else:
            out["usage"] = _read_int(dev + "/gpu_busy_percent", 0)
            out["memUsage"] = _read_int(dev + "/mem_busy_percent", 0)
            out["vramUsed"] = _read_int(dev + "/mem_info_vram_used", 0)
            out["vramTotal"] = _read_int(dev + "/mem_info_vram_total", 0)
        hw = g["hwmon"]
        if hw:
            for p in glob.glob(hw + "/temp*_input"):
                label = (_read(p.replace("_input", "_label"), "edge") or "edge").lower()
                v = (_read_int(p, 0) or 0) / 1000
                key = {"edge": "temp", "junction": "junction", "mem": "memTemp"}.get(label)
                if key and not out.get(key):
                    out[key] = v
            uw = _read_int(hw + "/power1_average") or _read_int(hw + "/power1_input")
            if uw:
                out["power"] = uw / 1e6
        if not out["temp"]:
            out["temp"] = out["junction"]
        return out

    def _fans(self):
        out = []
        for f in self.fans:
            rpm = _read_int(f["path"])
            if rpm is None:
                continue
            # Duty: the share of full speed. Without a reported maximum, full
            # is FAN_FULL_RPM, or the fastest this fan has been seen to go.
            peak = self.fan_peak[f["label"]] = max(rpm, self.fan_peak.get(f["label"], 0))
            full = f["max"] if f["max"] > 0 else max(FAN_FULL_RPM, peak)
            out.append({"label": f["label"], "chip": f["chip"], "rpm": rpm, "max": f["max"],
                        "full": full, "duty": min(1.0, rpm / full)})
            self.fan_hist.setdefault(f["label"], deque(maxlen=HISTORY)).append(rpm)
        return out

    def _net(self, dt):
        counters = psutil.net_io_counters(pernic=True)
        addrs = psutil.net_if_addrs()
        stats = psutil.net_if_stats()
        active = default_iface()
        if not active:   # no default route: the busiest interface that is up
            up = [n for n, st in stats.items() if st.isup and n != "lo"]
            active = max(up, key=lambda n: counters[n].bytes_recv if n in counters else 0, default="")
        prev = self.prev_net or {}
        self.prev_net = {n: (c.bytes_recv, c.bytes_sent) for n, c in counters.items()}

        ifaces = []
        for name, c in counters.items():
            if name == "lo":
                continue
            p = prev.get(name)
            rx = max(0, (c.bytes_recv - p[0]) / dt) if p and dt else 0
            tx = max(0, (c.bytes_sent - p[1]) / dt) if p and dt else 0
            st = stats.get(name)
            v4 = [a.address for a in addrs.get(name, []) if a.family == socket.AF_INET]
            v6 = [a.address.split("%")[0] for a in addrs.get(name, []) if a.family == socket.AF_INET6]
            mac = next((a.address for a in addrs.get(name, []) if a.family == psutil.AF_LINK), "")
            ifaces.append({
                "name": name, "up": bool(st and st.isup), "speed": st.speed if st else 0,
                "mtu": st.mtu if st else 0, "mac": mac, "ipv4": v4, "ipv6": v6,
                "rx": rx, "tx": tx, "rxTotal": c.bytes_recv, "txTotal": c.bytes_sent,
                "active": name == active,
                "kind": "wifi" if os.path.isdir(f"/sys/class/net/{name}/wireless") else
                        "virtual" if not os.path.exists(f"/sys/class/net/{name}/device") else "wired",
            })
        ifaces.sort(key=lambda i: (not i["active"], not i["up"], i["kind"] == "virtual", i["name"]))
        a = next((i for i in ifaces if i["active"]), None)
        return {
            "iface": active, "rx": a["rx"] if a else 0, "tx": a["tx"] if a else 0,
            "rxTotal": a["rxTotal"] if a else 0, "txTotal": a["txTotal"] if a else 0,
            "lan": (a["ipv4"] or [""])[0] if a else "", "kind": a["kind"] if a else "",
            "interfaces": ifaces,
        }

    def _disks(self, dt):
        stats = {}
        for line in (_read("/proc/diskstats", "") or "").splitlines():
            f = line.split()
            if len(f) > 9:
                stats[f[2]] = (int(f[5]) * SECTOR, int(f[9]) * SECTOR)
        prev = self.prev_disk or {}
        self.prev_disk = stats

        by_dev = {}
        for p in psutil.disk_partitions(all=False):
            if p.fstype in SKIP_FS or p.device.startswith("/dev/loop") or not p.device.startswith("/dev/"):
                continue
            by_dev.setdefault(p.device, []).append(p)
        disks, total_r, total_w = [], 0, 0
        for device, parts in by_dev.items():
            parts.sort(key=lambda p: len(p.mountpoint))   # "/" before "/home" on one btrfs device
            mount = parts[0].mountpoint
            try:
                u = psutil.disk_usage(mount)
            except OSError:
                continue
            kname = os.path.basename(os.path.realpath(device))
            cur, old = stats.get(kname), prev.get(kname)
            r = max(0, (cur[0] - old[0]) / dt) if cur and old and dt else 0
            w = max(0, (cur[1] - old[1]) / dt) if cur and old and dt else 0
            total_r += r
            total_w += w
            hist = self.disk_hist.setdefault(device, (deque(maxlen=HISTORY), deque(maxlen=HISTORY)))
            hist[0].append(r)
            hist[1].append(w)
            rotational = _read_int(f"/sys/class/block/{re.sub(r'p?[0-9]+$', '', kname)}/queue/rotational")
            disks.append({
                "device": device, "kname": kname, "mount": mount,
                "mounts": [p.mountpoint for p in parts], "fstype": parts[0].fstype,
                "total": u.total, "used": u.used, "free": u.free, "percent": u.percent,
                "read": r, "write": w,
                "kind": "nvme" if kname.startswith("nvme") else "hdd" if rotational == 1 else "ssd",
                "label": os.path.basename(mount) or "ROOT",
            })
        disks.sort(key=lambda d: (d["mount"] != "/", d["mount"]))
        return disks, total_r, total_w

    def _battery(self):
        b = psutil.sensors_battery()
        if not b:
            return {"present": False}
        watts = 0
        for bat in glob.glob("/sys/class/power_supply/BAT*"):
            uw = _read_int(bat + "/power_now")
            if uw is None:
                ua, uv = _read_int(bat + "/current_now"), _read_int(bat + "/voltage_now")
                uw = ua * uv / 1e6 if ua and uv else 0
            watts += uw / 1e6
        secs = b.secsleft if isinstance(b.secsleft, int) and b.secsleft >= 0 else -1
        return {"present": True, "percent": b.percent, "plugged": bool(b.power_plugged),
                "secsLeft": secs, "watts": watts}


class Telemetry(QObject):
    """What QML binds to: `data` (the latest sample), `specs`, and the public
    address with its lookup state."""

    dataChanged = Signal()
    wanChanged = Signal()
    intervalChanged = Signal()
    copied = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._collector = Collector()
        self._specs = self._collector.specs()
        self._data = {}
        self._wan = ""
        self._wan_state = "resolving"
        self._wan_key = None
        self._nam = QNetworkAccessManager(self)
        self._interval = INTERVAL_MS

        self._poller = Poller(self._collector.sample, INTERVAL_MS)
        self._poller.result.connect(self._on_sample)
        self._thread = start_poller(self._poller)

    def stop(self):
        self._thread.quit()
        self._thread.wait(3000)

    def setInterval(self, ms):
        if ms != self._interval:
            self._interval = ms
            self._poller.retime.emit(ms)
            self.intervalChanged.emit()

    def _on_sample(self, sample):
        self._data = sample
        self.dataChanged.emit()
        key = (sample["net"]["iface"], sample["net"]["lan"])
        if key != self._wan_key:        # a new connection: look the address up again
            self._wan_key = key
            self.refreshWan()

    @Slot()
    def refreshWan(self):
        self._wan_state = "resolving"
        self.wanChanged.emit()
        if not self._wan_key or not self._wan_key[0]:
            self._wan_state = "offline"
            self.wanChanged.emit()
            return
        req = QNetworkRequest(QUrl("https://api.ipify.org"))
        req.setTransferTimeout(8000)
        reply = self._nam.get(req)
        reply.finished.connect(lambda: self._on_wan(reply))

    def _on_wan(self, reply):
        text = bytes(reply.readAll()).decode(errors="replace").strip()
        ok = reply.error() == QNetworkReply.NoError and re.fullmatch(r"[0-9a-fA-F:.]+", text)
        self._wan, self._wan_state = (text, "ok") if ok else ("", "offline")
        reply.deleteLater()
        self.wanChanged.emit()

    @Slot(str)
    def copyText(self, text):
        QGuiApplication.clipboard().setText(text)
        self.copied.emit(text)

    data = Property("QVariantMap", lambda self: self._data, notify=dataChanged)
    specs = Property("QVariantMap", lambda self: self._specs, constant=True)
    wanIp = Property(str, lambda self: self._wan, notify=wanChanged)
    wanState = Property(str, lambda self: self._wan_state, notify=wanChanged)
    interval = Property(int, lambda self: self._interval, notify=intervalChanged)
