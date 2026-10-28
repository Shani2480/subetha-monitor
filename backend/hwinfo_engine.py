"""Hardware sensors in the manner of HWiNFO: every reading the kernel exposes,
grouped by device (processor, motherboard, graphics, drives, memory, battery)
and section, each with its session minimum, maximum and average.

The readings come from /sys/class/hwmon, /sys/class/powercap (the RAPL energy
counters, turned into watts), /sys/class/drm, /sys/class/nvme, cpufreq and
/proc, on the poller's own thread. NVMe health (life left, spare, data
read and written) comes from UDisks2 over D-Bus, which needs no root, once a
minute. A sensor shows only when the hardware reports it: nothing is guessed.

Polling starts the first time the tab is shown (or a log is started) and
then runs for the rest of the session, so the statistics cover all of it.
The statistics, the tree's collapsed state, the filter and the CSV log live
on the GUI thread; the model holds only the rows on screen.
"""

import csv
import glob
import io
import json
import os
import re
import shutil
import subprocess
import time

import psutil
from PySide6.QtCore import QObject, Property, Signal, Slot

from .common import Poller, RowsModel, start_poller
from .telemetry import _read, _read_int, cpu_model, discover_gpus

INTERVALS = (500, 1000, 2000)
INTERVAL_MS = 1000
LOG_PATH = os.path.expanduser("~/subetha_hwinfo_log.csv")
REDISCOVER_S = 30      # hot-plugged chips and drives
SMART_S = 60           # UDisks2 refreshes its own SMART cache far less often
KEYS = ["kind", "key", "depth", "label", "cur", "min", "max", "avg", "frac",
        "expanded", "count", "heat", "stripe"]

UDISKS = ["org.freedesktop.UDisks2"]
CPU_CHIPS = {"k10temp", "zenpower", "coretemp", "cpu_thermal", "fam15h_power"}
GPU_CHIPS = {"amdgpu", "radeon", "nouveau", "i915", "xe"}
DIMM_CHIPS = {"spd5118", "jc42"}
DRIVE_CHIPS = {"nvme", "drivetemp"}
BOARD_CHIP = re.compile(r"^(nct|it8|it87|f71|w83|sch5|asus|dell|thinkpad|gigabyte|hp|applesmc|acpitz|"
                        r"pch_|msi|lenovo|ideapad|surface|nzxt-smart|corsairpsu)")
VENDORS = {"ASUSTeK COMPUTER INC.": "ASUS", "Micro-Star International Co., Ltd.": "MSI",
           "Gigabyte Technology Co., Ltd.": "GIGABYTE", "ASRock": "ASRock", "Dell Inc.": "Dell",
           "LENOVO": "Lenovo", "HP": "HP", "Hewlett-Packard": "HP", "Framework": "Framework"}
LAPTOP_CHASSIS = {"8", "9", "10", "14", "31", "32"}
PCIE_GEN = {"2.5": 1, "5.0": 2, "8.0": 3, "16.0": 4, "32.0": 5, "64.0": 6}
ACRONYMS = {"cpu", "gpu", "aio", "opt", "pch", "vrm", "soc", "ccd", "ssd", "pcie", "mos", "vbat",
            "avcc", "vcc", "vccsa", "vddq", "vsb", "dram", "sys", "ppt"}

# hwmon file kind: (unit, divisor)
KINDS = {"temp": ("°C", 1000), "in": ("V", 1000), "curr": ("A", 1000), "power": ("W", 1e6),
         "fan": ("RPM", 1), "freq": ("MHz", 1e6), "pwm": ("%", 2.55)}
KIND_WORDS = {"temp": "Temperature", "curr": "Current", "power": "Power", "freq": "Clock"}
HWMON_FILE = re.compile(r"^(temp|in|curr|power|fan|freq)(\d+)_(input|average)$")

# Which section each kind of reading falls in, per device.
SECTIONS = {
    "cpu":   {"freq": "Clocks", "temp": "Temperatures", "in": "Voltages & Currents",
              "curr": "Voltages & Currents", "power": "Power & Energy"},
    "board": {"temp": "Temperatures", "in": "Power Rails", "curr": "Currents", "power": "Power",
              "fan": "Fans", "pwm": "Fans", "freq": "Clocks"},
    "gpu":   {"temp": "Temperatures", "freq": "Clocks", "in": "Voltages & Power", "curr": "Voltages & Power",
              "power": "Voltages & Power", "fan": "Fans", "pwm": "Fans"},
    "drive": {"temp": "Temperatures"},
    "mem":   {"temp": "SPD Hub Temperatures"},
    "other": {"temp": "Temperatures", "in": "Voltages", "curr": "Currents", "power": "Power",
              "fan": "Fans", "pwm": "Fans", "freq": "Clocks"},
}
ORDER = {
    "cpu":   ["Clocks", "Usage", "Temperatures", "Voltages & Currents", "Power & Energy"],
    "board": ["Temperatures", "Power Rails", "Currents", "Power", "Fans", "Clocks"],
    "gpu":   ["Status", "Temperatures", "Clocks", "Load & Memory", "Voltages & Power", "Fans", "Bus"],
    "drive": ["Temperatures", "Health", "Activity", "Bus"],
    "mem":   ["Usage", "SPD Hub Temperatures"],
    "battery": ["Charge", "Power", "Capacity"],
}

# Kernel labels (lower case) -> what HWiNFO calls them, per device.
LABELS = {
    "cpu": {"tdie": "CPU Die (Tdie)", "svi2_core": "CPU Core Voltage (SVI2 TFN)",
            "svi2_soc": "SoC Voltage (SVI2 TFN)", "svi2_c_core": "CPU Core Current (SVI2 TFN)",
            "svi2_c_soc": "SoC Current (SVI2 TFN)", "svi2_p_core": "CPU Core Power (SVI2 TFN)",
            "svi2_p_soc": "SoC Power (SVI2 TFN)"},
    "gpu": {"edge": "GPU Temperature", "junction": "GPU Hotspot (Junction)", "mem": "GPU Memory Junction (VRAM)",
            "vddgfx": "GPU Core Voltage (VDDCR_GFX)", "vddnb": "GPU SoC Voltage (VDDNB)",
            "ppt": "GPU PPT", "slowppt": "GPU Slow PPT", "fastppt": "GPU Fast PPT",
            "sclk": "GPU Clock", "mclk": "GPU Memory Clock", "fan1": "GPU Fan"},
    "board": {"systin": "Motherboard (SYSTIN)", "cputin": "CPU Socket (CPUTIN)", "vrm": "VRM / MOS",
              "chipset": "Chipset", "motherboard": "Motherboard", "cpu": "CPU", "t_sensor": "T_Sensor Header",
              "water_in": "Water In", "water_out": "Water Out", "pch_chip_temp": "Chipset (PCH)",
              "pch_chip_cpu_max_temp": "PCH CPU Max", "vcore": "Vcore", "cpu vcore": "Vcore",
              "3vcc": "+3.3V (3VCC)", "+3.3v": "+3.3V", "3.3v": "+3.3V", "avcc": "AVCC (+3.3V)",
              "3vsb": "+3.3V Standby (3VSB)", "vbat": "VBAT (CMOS Battery)", "+12v": "+12V", "12v": "+12V",
              "+5v": "+5V", "5v": "+5V", "vccsa": "VCCSA", "vddq": "VDDQ (DRAM)", "vtt": "VTT"},
    "drive": {"composite": "Drive Temperature (Composite)", "sensor 1": "Temperature Sensor 1",
              "sensor 2": "Temperature Sensor 2"},
}


def pretty(label):
    """"cpu_fan" -> "CPU Fan", "chassis fan 1" -> "Chassis Fan 1"."""
    words = [w for w in re.split(r"[_\s]+", label.strip()) if w]
    return " ".join(w.upper() if w.lower() in ACRONYMS else w[:1].upper() + w[1:] for w in words)


def pcie_link(dev):
    """"Gen4 x16" from a PCI device's link attributes, or ""."""
    speed = (_read(dev + "/current_link_speed") or "").split(" ")[0]
    width = _read(dev + "/current_link_width")
    if not speed or not width or speed == "Unknown":
        return ""
    gen = PCIE_GEN.get(speed)
    text = (f"Gen{gen}" if gen else speed + " GT/s") + f" x{width}"
    mspeed = (_read(dev + "/max_link_speed") or "").split(" ")[0]
    mwidth = _read(dev + "/max_link_width")
    if mspeed and mwidth and (mspeed != speed or mwidth != width):
        mgen = PCIE_GEN.get(mspeed)
        text += f" (max {'Gen%d' % mgen if mgen else mspeed} x{mwidth})"
    return text


def dpm_mhz(path):
    """The current level of an amdgpu pp_dpm_* table: "1: 2400Mhz *" -> 2400."""
    m = re.search(r"(\d+)\s*Mhz\s*\*", _read(path, "") or "", re.I)
    return int(m.group(1)) if m else None


def busctl(*args, timeout=3):
    """Typed JSON from systemd's D-Bus client, or None."""
    try:
        out = subprocess.run(["busctl", "--system", "-j", *args], capture_output=True,
                             text=True, timeout=timeout)
        return json.loads(out.stdout) if out.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired, ValueError):
        return None


def fmt(value, unit):
    """A reading with its unit, at the precision HWiNFO shows."""
    if value is None:
        return ""
    v = float(value)
    if unit == "°C":
        return f"{v:.1f} °C"
    if unit == "V":
        return f"{v:.3f} V"
    if unit in ("A", "MB/s", "GB", "Wh", "Ah"):
        return f"{v:.2f} {unit}"
    if unit == "W":
        return f"{v:.1f} W" if abs(v) >= 100 else f"{v:.2f} W"
    if unit in ("MHz", "%"):
        return f"{v:.1f} {unit}"
    if unit == "RPM":
        return f"{v:,.0f} RPM"
    if unit == "B":            # drive totals, in the decimal units drives are sold in
        for u, n in (("PB", 1e15), ("TB", 1e12), ("GB", 1e9), ("MB", 1e6)):
            if abs(v) >= n:
                return f"{v / n:.2f} {u}"
        return f"{v:.0f} B"
    if unit in ("h", "min"):
        return f"{v:,.0f} {unit}"
    return f"{v:,.0f}" if unit == "" else f"{v:g} {unit}"


class _Device:
    """One group of the tree while a sample is assembled."""

    def __init__(self, key, title, kind):
        self.key, self.title, self.kind = key, title, kind
        self.sections = {s: [] for s in ORDER.get(kind, [])}

    def add(self, section, label, unit, value, text=None):
        if value is None and not text:
            return
        self.sections.setdefault(section, []).append((label, unit, value, text))

    def out(self):
        seen, sections = set(), []
        for title, sensors in self.sections.items():
            if not sensors:
                continue
            rows = []
            for label, unit, value, text in sensors:
                key = f"{self.key}/{label}"
                n = 2
                while key in seen:                     # two chips both naming a reading "temp1"
                    key, n = f"{self.key}/{label}#{n}", n + 1
                seen.add(key)
                rows.append({"id": key, "label": label, "unit": unit,
                             "value": None if value is None else round(float(value), 4), "text": text or ""})
            sections.append({"id": f"{self.key}::{title}", "title": title, "sensors": rows})
        return {"id": self.key, "title": self.title, "kind": self.kind, "sections": sections}


class _Nvidia:
    """NVIDIA readings through pynvml when installed, else nvidia-smi."""

    SMI_FIELDS = [("temperature.gpu", "Temperatures", "GPU Temperature", "°C"),
                  ("clocks.gr", "Clocks", "GPU Clock", "MHz"),
                  ("clocks.mem", "Clocks", "GPU Memory Clock", "MHz"),
                  ("clocks.video", "Clocks", "GPU Video Clock", "MHz"),
                  ("utilization.gpu", "Load & Memory", "GPU Core Load", "%"),
                  ("utilization.memory", "Load & Memory", "GPU Memory Controller Load", "%"),
                  ("memory.used", "Load & Memory", "GPU Memory Allocated", "GB"),
                  ("power.draw", "Voltages & Power", "GPU Power", "W"),
                  ("fan.speed", "Fans", "GPU Fan Duty", "%"),
                  ("pcie.link.gen.current", None, None, None),
                  ("pcie.link.width.current", None, None, None)]

    def __init__(self):
        self.nv = None
        try:
            import pynvml
            pynvml.nvmlInit()
            self.nv = pynvml
        except Exception:
            pass
        self.smi = shutil.which("nvidia-smi")

    def read(self, slot, dev):
        if self.nv:
            n = self.nv
            try:
                h = n.nvmlDeviceGetHandleByPciBusId(slot)
            except Exception:
                return

            def q(fn, *a):
                try:
                    return fn(h, *a)
                except Exception:
                    return None
            dev.add("Temperatures", "GPU Temperature", "°C", q(n.nvmlDeviceGetTemperature, n.NVML_TEMPERATURE_GPU))
            for label, clock in (("GPU Clock", n.NVML_CLOCK_GRAPHICS), ("GPU SM Clock", n.NVML_CLOCK_SM),
                                 ("GPU Memory Clock", n.NVML_CLOCK_MEM), ("GPU Video Clock", n.NVML_CLOCK_VIDEO)):
                dev.add("Clocks", label, "MHz", q(n.nvmlDeviceGetClockInfo, clock))
            util = q(n.nvmlDeviceGetUtilizationRates)
            if util:
                dev.add("Load & Memory", "GPU Core Load", "%", util.gpu)
                dev.add("Load & Memory", "GPU Memory Controller Load", "%", util.memory)
            mem = q(n.nvmlDeviceGetMemoryInfo)
            if mem:
                dev.add("Load & Memory", "GPU Memory Allocated", "GB", mem.used / 2**30)
            mw = q(n.nvmlDeviceGetPowerUsage)
            dev.add("Voltages & Power", "GPU Power", "W", mw / 1000 if mw is not None else None)
            dev.add("Fans", "GPU Fan Duty", "%", q(n.nvmlDeviceGetFanSpeed))
            gen, width = q(n.nvmlDeviceGetCurrPcieLinkGeneration), q(n.nvmlDeviceGetCurrPcieLinkWidth)
            if gen and width:
                dev.add("Bus", "PCIe Link", "", None, f"Gen{gen} x{width}")
            return
        if not self.smi:
            return
        try:
            out = subprocess.run([self.smi, "--query-gpu=" + ",".join(f[0] for f in self.SMI_FIELDS),
                                  "--format=csv,noheader,nounits", f"--id={slot}"],
                                 capture_output=True, text=True, timeout=3).stdout
        except (OSError, subprocess.TimeoutExpired):
            return
        values = [v.strip() for v in out.split(",")]
        if len(values) != len(self.SMI_FIELDS):
            return
        num = {}
        for (field, section, label, unit), v in zip(self.SMI_FIELDS, values):
            try:
                num[field] = float(v)
            except ValueError:
                continue
            if section:
                dev.add(section, label, unit, num[field] / 1024 if unit == "GB" else num[field])
        if "pcie.link.gen.current" in num and "pcie.link.width.current" in num:
            dev.add("Bus", "PCIe Link", "", None,
                    f"Gen{num['pcie.link.gen.current']:.0f} x{num['pcie.link.width.current']:.0f}")


class _Reader:
    """Discovers the sensors, then reads them all once per tick (on the
    poller's thread). Rates (RAPL watts, usage, drive throughput) come from
    the change since the previous tick."""

    def __init__(self):
        self.prev_t = None
        self.prev_energy = {}
        self.prev_stat = {}
        self.prev_disk = {}
        self.smart = {}
        self.smart_t = 0
        self.found_t = 0
        self.cpu_name = cpu_model()
        self.gpus = discover_gpus()
        self.nvidia = _Nvidia() if any(g["vendor"] == "nvidia" for g in self.gpus) else None
        self.board_title = self._board_title()
        self._discover()

    # ---- discovery ----
    @staticmethod
    def _board_title():
        d = "/sys/class/dmi/id/"
        vendor = _read(d + "board_vendor") or _read(d + "sys_vendor") or ""
        vendor = VENDORS.get(vendor, vendor)
        board = _read(d + "board_name") or ""
        if _read(d + "chassis_type") in LAPTOP_CHASSIS:     # a laptop's board code says little
            product = re.sub(r"_" + re.escape(board) + "$", "", _read(d + "product_name") or "")
            board = product if board in product else f"{product} {board}".strip()
        return f"Motherboard: {vendor} {board}".strip()

    def _discover(self):
        self.found_t = time.monotonic()
        self.cores = self._cores()
        self.rapl = []
        for z in sorted(glob.glob("/sys/class/powercap/intel-rapl:*")):
            if _read_int(z + "/energy_uj") is not None:       # root-only on some kernels
                self.rapl.append((z, _read(z + "/name", ""), _read_int(z + "/max_energy_range_uj", 0) or 0))
        self.chips = [c for c in (self._chip(p) for p in sorted(glob.glob("/sys/class/hwmon/hwmon*"),
                                                               key=lambda p: int(re.sub(r"\D", "", p) or 0)))
                      if c]
        self.drives = self._drives()
        self.batteries = [b for b in sorted(glob.glob("/sys/class/power_supply/*"))
                          if _read(b + "/type") == "Battery" and _read(b + "/scope") != "Device"]

    @staticmethod
    def _cores():
        """[(core label, [cpu numbers])], one per physical core, in cpu order."""
        cores = {}
        for c in sorted(glob.glob("/sys/devices/system/cpu/cpu[0-9]*"), key=lambda p: int(p.rsplit("cpu", 1)[1])):
            n = int(c.rsplit("cpu", 1)[1])
            if _read(c + "/online", "1") != "1" or not os.path.isdir(c + "/cpufreq"):
                continue
            key = (_read(c + "/topology/physical_package_id", "0"), _read(c + "/topology/die_id", "0"),
                   _read(c + "/topology/core_id", str(n)))
            cores.setdefault(key, []).append(n)
        return [(f"Core {i}", cpus) for i, cpus in enumerate(cores.values())]

    @staticmethod
    def _chip(path):
        name = _read(path + "/name", "")
        dev = os.path.realpath(path + "/device") if os.path.exists(path + "/device") else ""
        if not name or "fan_curve" in name or "/power_supply/" in dev:
            return None
        entries = {}
        for f in os.listdir(path):
            m = HWMON_FILE.match(f)
            pm = re.match(r"^pwm(\d+)$", f)
            if m:
                kind, n, which = m.groups()
                # power: the average where both exist, as the GPU drivers mean it
                if (kind, n) in entries and which == "input":
                    continue
                entries[(kind, n)] = os.path.join(path, f)
            elif pm:
                entries[("pwm", pm.group(1))] = os.path.join(path, f)
        if not entries:
            return None
        readings = []
        for (kind, n), file in sorted(entries.items(), key=lambda e: (e[0][0], int(e[0][1]))):
            label = _read(f"{path}/{kind}{n}_label") if kind != "pwm" else None
            readings.append({"kind": kind, "n": n, "file": file, "label": label})
        if name in CPU_CHIPS:
            owner = "cpu"
        elif name in GPU_CHIPS:
            owner = "gpu"
        elif name in DIMM_CHIPS:
            owner = "mem"
        elif name in DRIVE_CHIPS:
            owner = "drive"
        elif BOARD_CHIP.match(name):
            owner = "board"
        else:
            owner = "other"
        return {"path": path, "real": os.path.realpath(path), "name": name, "dev": dev,
                "owner": owner, "readings": readings}

    def _drives(self):
        drives = []
        for c in sorted(glob.glob("/sys/class/nvme/nvme[0-9]*")):
            name = os.path.basename(c)
            ns = sorted(os.path.basename(p) for p in glob.glob(f"{c}/{name}n[0-9]*"))   # namespaces, not partitions
            hw = glob.glob(c + "/hwmon*") or glob.glob(c + "/device/hwmon/hwmon*")
            drives.append({"key": name, "model": re.sub(r"[_\s]+", " ", _read(c + "/model", "") or "").strip() or "NVMe Drive",
                           "serial": (_read(c + "/serial", "") or "").strip(), "blocks": ns,
                           "hwmon": os.path.realpath(hw[0]) if hw else None, "pci": c + "/device"})
        for b in sorted(glob.glob("/sys/block/sd[a-z]*")):
            if _read_int(b + "/removable", 0) or not os.path.exists(b + "/device/model"):
                continue
            hw = glob.glob(b + "/device/hwmon/hwmon*")
            drives.append({"key": os.path.basename(b), "model": (_read(b + "/device/model", "") or "").strip(),
                           "serial": "", "blocks": [os.path.basename(b)],
                           "hwmon": os.path.realpath(hw[0]) if hw else None, "pci": None})
        return drives

    def _smart(self):
        """Serial -> NVMe health from UDisks2: SmartGetAttributes, plus the
        power-on hours it keeps as a property."""
        out = {}
        if not shutil.which("busctl"):
            return out
        objs = busctl("call", *UDISKS, "/org/freedesktop/UDisks2",
                      "org.freedesktop.DBus.ObjectManager", "GetManagedObjects")
        if not objs or not objs.get("data"):
            return out
        for path, ifaces in objs["data"][0].items():
            drive, nv = ifaces.get("org.freedesktop.UDisks2.Drive"), ifaces.get("org.freedesktop.UDisks2.NVMe.Controller")
            if not drive or not nv:
                continue
            attrs = busctl("call", *UDISKS, path, "org.freedesktop.UDisks2.NVMe.Controller",
                           "SmartGetAttributes", "a{sv}", "0")
            a = {k: v["data"] for k, v in attrs["data"][0].items()} if attrs and attrs.get("data") else {}
            a["power_on_hours"] = nv.get("SmartPowerOnHours", {}).get("data")
            out[drive["Serial"]["data"].strip()] = a
        return out

    # ---- one sample ----
    def read(self):
        now = time.monotonic()
        dt = now - self.prev_t if self.prev_t else None
        self.prev_t = now
        if now - self.found_t > REDISCOVER_S:
            self._discover()
        if now - self.smart_t > SMART_S:
            self.smart_t = now
            self.smart = self._smart()

        devices = [self._cpu(dt), self._board()]
        devices += [self._gpu(i, g) for i, g in enumerate(self.gpus)]
        devices += [self._drive(d, dt) for d in self.drives]
        devices.append(self._memory())
        devices += [self._battery(b) for b in self.batteries]
        devices += self._others()
        return [d for d in (dev.out() for dev in devices) if d["sections"]]

    def _hwmon(self, dev, chip, labels=None, names=None):
        """Every reading of `chip` into `dev`, labelled through `labels`
        (kernel label -> name) or `names(kind, n, label)`."""
        sections = SECTIONS.get(dev.kind, SECTIONS["other"])
        labels = labels or {}
        fans = {r["n"]: r for r in chip["readings"] if r["kind"] == "fan"}
        for r in chip["readings"]:
            kind, n = r["kind"], r["n"]
            raw = _read_int(r["file"])
            if raw is None:
                continue
            unit, div = KINDS[kind]
            value = raw / div
            if kind == "pwm":
                fan = fans.get(n)
                base = (self._fan_label(fan, dev) if fan else f"PWM {n}")
                label = base + " Duty"
            elif kind == "fan":
                label = self._fan_label(r, dev)
            else:
                label = names(kind, n, r["label"]) if names else None
                if not label:
                    key = (r["label"] or "").lower()
                    label = labels.get(key) or (pretty(r["label"]) if r["label"] else
                                                f"VIN{n}" if kind == "in" else f"{KIND_WORDS[kind]} {n}")
            dev.add(sections.get(kind, "Other"), label, unit, value)

    @staticmethod
    def _fan_label(r, dev):
        if dev.kind == "gpu":
            return "GPU Fan" if r["n"] == "1" else f"GPU Fan {r['n']}"
        return pretty(r["label"]) if r["label"] else f"Fan {r['n']}"

    # ---- processor ----
    def _stat(self):
        """cpu number (or "all") -> (busy, total) jiffies from /proc/stat."""
        out = {}
        for line in (_read("/proc/stat", "") or "").splitlines():
            if not line.startswith("cpu"):
                break
            f = line.split()
            v = [int(x) for x in f[1:9]]
            idle = v[3] + v[4]
            out["all" if f[0] == "cpu" else int(f[0][3:])] = (sum(v) - idle, sum(v))
        return out

    def _cpu(self, dt):
        dev = _Device("cpu", f"CPU [#0]: {self.cpu_name}: Enhanced", "cpu")
        stat, prev = self._stat(), self.prev_stat
        self.prev_stat = stat

        def busy(n):
            a, b = stat.get(n), prev.get(n)
            if not a or not b or a[1] <= b[1]:
                return None
            return max(0.0, min(1.0, (a[0] - b[0]) / (a[1] - b[1])))

        effective = []
        for label, cpus in self.cores:
            freqs = [_read_int(f"/sys/devices/system/cpu/cpu{c}/cpufreq/scaling_cur_freq") for c in cpus]
            freqs = [f for f in freqs if f]
            if freqs:
                dev.add("Clocks", f"{label} Clock", "MHz", max(freqs) / 1000)
            # Effective clock: the kernel's APERF/MPERF average where it
            # offers one (6.13+), else the clock weighted by time not idle.
            avg = [_read_int(f"/sys/devices/system/cpu/cpu{c}/cpufreq/cpuinfo_avg_freq") for c in cpus]
            avg = [a for a in avg if a]
            if avg:
                eff = sum(avg) / len(avg) / 1000
            else:
                loads = [busy(c) for c in cpus]
                loads = [x for x in loads if x is not None]
                eff = max(freqs) / 1000 * sum(loads) / len(loads) if freqs and loads else None
            if eff is not None:
                effective.append(eff)
                dev.add("Clocks", f"{label} Effective Clock", "MHz", eff)
        if effective:
            dev.add("Clocks", "Average Effective Clock", "MHz", sum(effective) / len(effective))

        total = busy("all")
        if total is not None:
            dev.add("Usage", "Total CPU Usage", "%", total * 100)
            for label, cpus in self.cores:
                loads = [x for x in (busy(c) for c in cpus) if x is not None]
                if loads:
                    dev.add("Usage", f"{label} Usage", "%", sum(loads) / len(loads) * 100)

        for chip in self.chips:
            if chip["owner"] != "cpu":
                continue
            has_tdie = any((r["label"] or "").lower() == "tdie" for r in chip["readings"])

            def names(kind, n, label):
                low = (label or "").lower()
                if low == "tctl":
                    return "CPU (Tctl)" if has_tdie else "CPU (Tctl/Tdie)"
                m = re.fullmatch(r"tccd(\d+)", low)
                if m:
                    return f"CCD{m.group(1)} (Tdie)"
                m = re.fullmatch(r"core (\d+)", low)
                if m:
                    return f"Core {m.group(1)}"
                m = re.fullmatch(r"package id (\d+)", low)
                if m:
                    return "CPU Package" if m.group(1) == "0" else f"CPU Package {m.group(1)}"
                return None
            self._hwmon(dev, chip, LABELS["cpu"], names)
        temps = [(label, v) for label, unit, v, _ in dev.sections.get("Temperatures", [])
                 if re.match(r"^(Core \d+|CCD\d+)", label)]
        if len(temps) >= 2:
            dev.add("Temperatures", "CCD Max" if temps[0][0].startswith("CCD") else "Core Max", "°C",
                    max(v for _, v in temps))

        energy = {}
        for zone, name, top in self.rapl:
            uj = _read_int(zone + "/energy_uj")
            if uj is None:
                continue
            energy[zone] = uj
            old = self.prev_energy.get(zone)
            if old is None or not dt:
                continue
            delta = uj - old if uj >= old else uj + top - old     # the counter wrapped
            label = {"core": "CPU Core Power (RAPL)", "uncore": "Uncore / iGPU Power (RAPL)",
                     "dram": "DRAM Power (RAPL)", "psys": "Platform Power (PSys)"}.get(name)
            if not label:
                m = re.fullmatch(r"package-(\d+)", name)
                label = ("CPU Package Power (RAPL)" if m.group(1) == "0" else f"CPU Package {m.group(1)} Power (RAPL)") if m else pretty(name) + " Power"
            dev.add("Power & Energy", label, "W", delta / dt / 1e6)
        self.prev_energy = energy
        return dev

    # ---- motherboard ----
    def _board(self):
        dev = _Device("board", self.board_title, "board")
        for chip in self.chips:
            if chip["owner"] != "board":
                continue
            name = chip["name"]

            def names(kind, n, label, name=name):
                if name == "acpitz" and kind == "temp":
                    return f"ACPI Thermal Zone {n}"
                if name.startswith("pch_") and kind == "temp" and not label:
                    return "Chipset (PCH)"
                return None
            self._hwmon(dev, chip, LABELS["board"], names)
        return dev

    # ---- graphics ----
    def _gpu(self, i, g):
        dev = _Device(f"gpu{i}", f"GPU [#{i}]: {g['name']}", "gpu")
        pci = g["dev"]
        # A dGPU asleep in runtime suspend would be woken by every read.
        if _read(pci + "/power/runtime_status") == "suspended":
            dev.add("Status", "Power State", "", None, "Sleeping (runtime suspend), not woken to read")
            return dev
        if g["vendor"] == "nvidia" and self.nvidia:
            self.nvidia.read(g["slot"], dev)
        for chip in self.chips:
            if chip["owner"] == "gpu" and chip["dev"] == os.path.realpath(pci):
                self._hwmon(dev, chip, LABELS["gpu"])
        clocks = {label for label, *_ in dev.sections.get("Clocks", [])}
        for table, label in (("sclk", "GPU Clock"), ("mclk", "GPU Memory Clock"), ("fclk", "Fabric Clock (FCLK)"),
                             ("socclk", "GPU SoC Clock"), ("vclk", "Video Engine Clock (VCLK)"),
                             ("dclk", "Video Decode Clock (DCLK)")):
            if label not in clocks:
                dev.add("Clocks", label, "MHz", dpm_mhz(f"{pci}/pp_dpm_{table}"))
        card = os.path.dirname(pci)
        if "GPU Clock" not in clocks:      # Intel: i915, then xe
            mhz = _read_int(card + "/gt_act_freq_mhz")
            if mhz is None:
                act = glob.glob(pci + "/tile0/gt0/freq0/act_freq")
                mhz = _read_int(act[0]) if act else None
            dev.add("Clocks", "GPU Clock", "MHz", mhz)
        dev.add("Load & Memory", "GPU Core Load", "%", _read_int(pci + "/gpu_busy_percent"))
        dev.add("Load & Memory", "GPU Memory Controller Load", "%", _read_int(pci + "/mem_busy_percent"))
        dev.add("Load & Memory", "Video Engine Load", "%", _read_int(pci + "/vcn_busy_percent"))
        used, total = _read_int(pci + "/mem_info_vram_used"), _read_int(pci + "/mem_info_vram_total")
        if used is not None:
            dev.add("Load & Memory", "GPU Memory Allocated", "GB", used / 2**30)
            if total:
                dev.add("Load & Memory", "GPU Memory Usage", "%", used / total * 100)
        gtt = _read_int(pci + "/mem_info_gtt_used")
        if gtt is not None:
            dev.add("Load & Memory", "GPU Shared Memory (GTT)", "GB", gtt / 2**30)
        if not any(label == "PCIe Link" for label, *_ in dev.sections.get("Bus", [])):
            dev.add("Bus", "PCIe Link", "", None, pcie_link(pci))
        return dev

    # ---- drives ----
    def _drive(self, d, dt):
        title = f"Drive: {d['model']} ({d['key']})"
        dev = _Device("drive:" + (d["serial"] or d["key"]), title, "drive")
        if d["hwmon"]:
            for chip in self.chips:
                if chip["real"] == d["hwmon"]:
                    self._hwmon(dev, chip, LABELS["drive"],
                                lambda kind, n, label, nm=chip["name"]: "Drive Temperature" if nm == "drivetemp" else None)
        s = self.smart.get(d["serial"]) if d["serial"] else None
        if s:
            if s.get("percent_used") is not None:
                dev.add("Health", "Drive Remaining Life", "%", max(0, 100 - s["percent_used"]))
            dev.add("Health", "Available Spare", "%", s.get("avail_spare"))
            dev.add("Health", "Available Spare Threshold", "%", s.get("spare_thresh"))
            dev.add("Health", "Total Host Reads", "B", s.get("total_data_read"))
            dev.add("Health", "Total Host Writes", "B", s.get("total_data_written"))
            dev.add("Health", "Power-On Hours", "h", s.get("power_on_hours"))
            dev.add("Health", "Power Cycles", "", s.get("power_cycles"))
            dev.add("Health", "Unsafe Shutdowns", "", s.get("unsafe_shutdowns"))
            dev.add("Health", "Media Errors", "", s.get("media_errors"))
            dev.add("Health", "Error Log Entries", "", s.get("num_err_log_entries"))
            dev.add("Health", "Warning Temperature Time", "min", s.get("warning_temp_time"))
        # Throughput and activity from /proc/diskstats: sectors read (5),
        # written (9), and ms spent doing I/O (12, 1-based).
        for line in (_read("/proc/diskstats", "") or "").splitlines():
            f = line.split()
            if len(f) < 13 or f[2] not in d["blocks"]:
                continue
            cur = (int(f[5]) * 512, int(f[9]) * 512, int(f[12]))
            old = self.prev_disk.get(f[2])
            self.prev_disk[f[2]] = cur
            if old and dt:
                dev.add("Activity", "Read Rate", "MB/s", max(0, cur[0] - old[0]) / dt / 1e6)
                dev.add("Activity", "Write Rate", "MB/s", max(0, cur[1] - old[1]) / dt / 1e6)
                dev.add("Activity", "Total Activity", "%", min(100.0, max(0, cur[2] - old[2]) / (dt * 10)))
        if d["pci"]:
            dev.add("Bus", "PCIe Link", "", None, pcie_link(d["pci"]))
        return dev

    # ---- memory ----
    def _memory(self):
        vm, sw = psutil.virtual_memory(), psutil.swap_memory()
        dimms = [c for c in self.chips if c["owner"] == "mem"]
        kind = " DDR5" if any(c["name"] == "spd5118" for c in dimms) else ""
        dev = _Device("mem", f"Memory: {vm.total / 2**30:.1f} GB{kind}", "mem")
        dev.add("Usage", "Physical Memory Used", "GB", vm.used / 2**30)
        dev.add("Usage", "Physical Memory Available", "GB", vm.available / 2**30)
        dev.add("Usage", "Physical Memory Load", "%", vm.percent)
        if sw.total:
            dev.add("Usage", "Swap Used", "GB", sw.used / 2**30)
            dev.add("Usage", "Swap Load", "%", sw.percent)
        for chip in dimms:
            # The SPD hub's I2C address names the slot: 0x50 is DIMM 0.
            m = re.search(r"-00(5[0-7])$", chip["dev"])
            slot = int(m.group(1), 16) - 0x50 if m else None
            name = f"DIMM [#{slot}]" if slot is not None else f"DIMM {chip['name']}"
            self._hwmon(dev, chip, names=lambda kind, n, label, name=name:
                        f"{name} Temperature" if n == "1" else f"{name} Temperature {n}")
        return dev

    # ---- battery ----
    def _battery(self, b):
        name = " ".join(x for x in (_read(b + "/manufacturer"), _read(b + "/model_name")) if x) or os.path.basename(b)
        dev = _Device("battery:" + os.path.basename(b), f"Battery: {name}", "battery")
        status = _read(b + "/status", "")
        dev.add("Charge", "Charge Level", "%", _read_int(b + "/capacity"))
        dev.add("Charge", "State", "", None, status)
        uv = _read_int(b + "/voltage_now")
        dev.add("Power", "Voltage", "V", uv / 1e6 if uv else None)
        uw = _read_int(b + "/power_now")
        if uw is None:
            ua = _read_int(b + "/current_now")
            uw = ua * uv / 1e6 if ua is not None and uv else None
        if uw is not None:
            dev.add("Power", "Discharge Rate" if status == "Discharging" else "Charge Rate", "W", abs(uw) / 1e6)
        # Energy in µWh where the battery reports it, else charge in µAh.
        what, unit = ("energy", "Wh") if _read_int(b + "/energy_full") is not None else ("charge", "Ah")
        now, full, design = (_read_int(f"{b}/{what}_{k}") for k in ("now", "full", "full_design"))
        dev.add("Capacity", "Remaining Capacity", unit, now / 1e6 if now is not None else None)
        dev.add("Capacity", "Full Charge Capacity", unit, full / 1e6 if full else None)
        dev.add("Capacity", "Design Capacity", unit, design / 1e6 if design else None)
        if full and design:
            dev.add("Capacity", "Wear Level", "%", max(0.0, (1 - full / design) * 100))
        dev.add("Capacity", "Charge Cycles", "", _read_int(b + "/cycle_count") or None)
        return dev

    # ---- anything else with a sensor ----
    def _others(self):
        out = []
        for chip in self.chips:
            if chip["owner"] != "other":
                continue
            name = chip["name"]
            title = "Wi-Fi Adapter (iwlwifi)" if name.startswith("iwlwifi") else pretty(name)
            dev = _Device("chip:" + os.path.basename(chip["path"]), title, "other")
            self._hwmon(dev, chip)
            out.append(dev)
        return out


class _Stat:
    """Current, minimum, maximum and the cumulative moving average."""

    __slots__ = ("cur", "min", "max", "avg", "n")

    def __init__(self, v):
        self.cur = self.min = self.max = self.avg = v
        self.n = 1

    def push(self, v):
        self.cur = v
        self.min = min(self.min, v)
        self.max = max(self.max, v)
        self.n += 1
        self.avg += (v - self.avg) / self.n

    def reset(self):
        self.min = self.max = self.avg = self.cur
        self.n = 1


class HwInfoEngine(QObject):
    """What the Hardware Sensors tab binds to: the visible rows of the
    sensor tree, the session's statistics and the CSV log."""

    changed = Signal()
    intervalChanged = Signal()
    collapsedChanged = Signal()
    loggingChanged = Signal()
    actionResult = Signal(str, bool)     # message, ok

    def __init__(self, interval=INTERVAL_MS, collapsed=(), parent=None):
        super().__init__(parent)
        self._model = RowsModel(KEYS, self)
        self._devices = []
        self._stats = {}
        self._collapsed = set(collapsed or ())
        self._filter = ""
        self._active = False
        self._started = False
        self._interval = interval if interval in INTERVALS else INTERVAL_MS
        self._samples = 0
        self._since = None
        self._log = None            # (file, csv writer, [sensor ids])
        self._log_rows = 0
        self._log_wanted = False

        self._poller = Poller(_Reader().read, self._interval)
        self._poller.enabled = False
        self._poller.result.connect(self._on_sample)
        self._thread = start_poller(self._poller)

    def stop(self):
        self._thread.quit()
        self._thread.wait(3000)
        self._close_log()

    def _start(self):
        if not self._started:
            self._started = True
            self._poller.enabled = True
            self._poller.poke.emit()

    # ---- samples and statistics ----
    def _on_sample(self, devices):
        self._devices = devices
        for d in devices:
            for s in d["sections"]:
                for x in s["sensors"]:
                    v = x["value"]
                    if v is None:
                        continue
                    st = self._stats.get(x["id"])
                    if st is None:
                        self._stats[x["id"]] = _Stat(v)
                    else:
                        st.push(v)
        if self._since is None:
            self._since = time.monotonic()
        self._samples += 1
        if self._log_wanted:
            self._write_log()
        if self._active:
            self._rebuild()
        self.changed.emit()

    def reset_statistics(self):
        """Every minimum, maximum and average starts again from the current reading."""
        for st in self._stats.values():
            st.reset()
        self._samples = 1 if self._devices else 0
        self._since = time.monotonic()
        self._rebuild()
        self.changed.emit()

    @Slot()
    def resetStatistics(self):
        self.reset_statistics()
        self.actionResult.emit("MINIMUM, MAXIMUM AND AVERAGE RESET TO THE CURRENT READINGS", True)

    # ---- the visible tree ----
    def _rebuild(self):
        needle = self._filter.strip().lower()
        rows, stripe = [], 0
        for d in self._devices:
            dmatch = bool(needle) and needle in d["title"].lower()
            temps = [self._stats[x["id"]].cur for s in d["sections"] for x in s["sensors"]
                     if x["unit"] == "°C" and x["id"] in self._stats]
            heat = max(temps) if temps else -1
            body, count = [], 0
            dev_open = bool(needle) or d["id"] not in self._collapsed
            for s in d["sections"]:
                smatch = dmatch or (bool(needle) and needle in s["title"].lower())
                sensors = [x for x in s["sensors"] if not needle or smatch or needle in x["label"].lower()]
                if not sensors:
                    continue
                count += len(sensors)
                sec_open = bool(needle) or s["id"] not in self._collapsed
                body.append({"kind": "section", "key": s["id"], "depth": 1, "label": s["title"],
                             "cur": "", "min": "", "max": "", "avg": "", "frac": -1.0,
                             "expanded": sec_open, "count": len(sensors), "heat": -1.0, "stripe": 0})
                if not sec_open:
                    continue
                for x in sensors:
                    st = self._stats.get(x["id"])
                    unit = x["unit"]
                    if st is None or x["value"] is None:
                        cur, mn, mx, avg, frac = x["text"], "", "", "", -1.0
                    else:
                        cur, mn, mx, avg = fmt(st.cur, unit), fmt(st.min, unit), fmt(st.max, unit), fmt(st.avg, unit)
                        frac = (st.cur - st.min) / (st.max - st.min) if st.max > st.min else 0.0
                    body.append({"kind": "sensor", "key": x["id"], "depth": 2, "label": x["label"],
                                 "cur": cur, "min": mn, "max": mx, "avg": avg, "frac": frac,
                                 "expanded": False, "count": 0, "heat": -1.0, "stripe": stripe % 2})
                    stripe += 1
            if not body:
                continue
            rows.append({"kind": "device", "key": d["id"], "depth": 0, "label": d["title"],
                         "cur": "", "min": "", "max": "", "avg": "", "frac": -1.0,
                         "expanded": dev_open, "count": count, "heat": float(heat), "stripe": 0})
            if dev_open:
                rows.extend(body)
        self._model.set_rows(rows)

    def _set_collapsed(self, keys):
        self._collapsed = set(keys)
        self._rebuild()
        self.collapsedChanged.emit()
        self.changed.emit()

    @Slot(str)
    def toggle(self, key):
        self._set_collapsed(self._collapsed ^ {key})

    @Slot()
    def expandAll(self):
        self._set_collapsed(())

    @Slot()
    def collapseAll(self):
        self._set_collapsed(d["id"] for d in self._devices)

    def _set_active(self, on):
        if on == self._active:
            return
        self._active = on
        if on:
            self._start()
            self._rebuild()
        self.changed.emit()

    def _set_filter(self, text):
        if text != self._filter:
            self._filter = text
            self._rebuild()
            self.changed.emit()

    def _set_interval(self, ms):
        if ms in INTERVALS and ms != self._interval:
            self._interval = ms
            self._poller.retime.emit(ms)
            self.intervalChanged.emit()

    # ---- CSV log ----
    def _set_logging(self, on):
        if on == self._log_wanted:
            return
        self._log_wanted = on
        if on:
            self._start()
            if self._devices:
                self._write_log()
        else:
            self._close_log()
            self.actionResult.emit(f"LOG CLOSED: {self._log_rows} ROWS IN {LOG_PATH}", True)
        self.loggingChanged.emit()

    def _open_log(self):
        """Columns are fixed when the log opens, one per sensor then present.
        A file whose header differs (other hardware, an older log) is kept
        aside under a timestamped name instead of being mixed into."""
        cols, header = [], ["Date", "Time"]
        for d in self._devices:
            for s in d["sections"]:
                for x in s["sensors"]:
                    cols.append(x["id"])
                    header.append(f"{d['title']} / {x['label']}" + (f" [{x['unit']}]" if x["unit"] else ""))
        line = io.StringIO()
        csv.writer(line).writerow(header)
        try:
            if os.path.getsize(LOG_PATH) > 0:
                with open(LOG_PATH, newline="") as f:
                    first = f.readline()
                if first != line.getvalue():
                    os.replace(LOG_PATH, LOG_PATH[:-4] + time.strftime("-%Y%m%d-%H%M%S.csv"))
        except OSError:
            pass                         # no file yet
        fresh = not os.path.exists(LOG_PATH)
        f = open(LOG_PATH, "a", newline="")
        w = csv.writer(f)
        if fresh:
            w.writerow(header)
        self._log = (f, w, cols)
        self._log_rows = 0
        self.actionResult.emit(f"LOGGING {len(cols)} SENSORS TO {LOG_PATH}", True)

    def _write_log(self):
        try:
            if self._log is None:
                self._open_log()
            f, w, cols = self._log
            now = {x["id"]: (x["value"] if x["value"] is not None else x["text"])
                   for d in self._devices for s in d["sections"] for x in s["sensors"]}
            w.writerow([time.strftime("%Y-%m-%d"), time.strftime("%H:%M:%S")] + [now.get(c, "") for c in cols])
            f.flush()
            self._log_rows += 1
        except OSError as e:
            self._close_log()
            self._log_wanted = False
            self.loggingChanged.emit()
            self.actionResult.emit(f"CANNOT WRITE {LOG_PATH}: {e.strerror or e}", False)

    def _close_log(self):
        if self._log:
            try:
                self._log[0].close()
            except OSError:
                pass
            self._log = None

    def _sensor_count(self):
        return sum(len(s["sensors"]) for d in self._devices for s in d["sections"])

    model = Property(QObject, lambda self: self._model, constant=True)
    active = Property(bool, lambda self: self._active, _set_active, notify=changed)
    filterText = Property(str, lambda self: self._filter, _set_filter, notify=changed)
    interval = Property(int, lambda self: self._interval, _set_interval, notify=intervalChanged)
    intervals = Property("QVariantList", lambda self: list(INTERVALS), constant=True)
    collapsed = Property("QVariantList", lambda self: sorted(self._collapsed), notify=collapsedChanged)
    anyCollapsed = Property(bool, lambda self: any(d["id"] in self._collapsed or
                                                   any(s["id"] in self._collapsed for s in d["sections"])
                                                   for d in self._devices), notify=changed)
    logging = Property(bool, lambda self: self._log_wanted, _set_logging, notify=loggingChanged)
    logPath = Property(str, lambda self: LOG_PATH, constant=True)
    logRows = Property(int, lambda self: self._log_rows, notify=changed)
    samples = Property(int, lambda self: self._samples, notify=changed)
    sessionSeconds = Property(float, lambda self: time.monotonic() - self._since if self._since else 0, notify=changed)
    sensorCount = Property(int, _sensor_count, notify=changed)
    deviceCount = Property(int, lambda self: len(self._devices), notify=changed)
