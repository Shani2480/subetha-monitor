# Sub-Etha System Monitor

A standalone desktop system monitor in the two looks of
[The Sub-Etha Guide](../subetha-guide), the KDE Plasma widget it pairs with:
the 1981 BBC terminal's phosphor green on CRT black (with scanlines and amber
reticles), and the 2005 film's cream Encyclopedia pages (with hard flat
shadows). One button in the top-right corner switches between them
(`Ctrl+T`).

| Tab | Shows |
| --- | --- |
| Overview | Host profile (CPU, GPU, RAM, kernel) with a Guide entry fitted to the machine's state; CPU, GPU, memory, cooling, network and storage tiles with load-over-temperature bars and 24-sample sparklines |
| Processes | Every process: PID, name, user, CPU %, memory, disk I/O. Search, "user only" filter, click a column to sort (again to flip), TERMINATE (SIGTERM) and KILL (SIGKILL) after a confirmation |
| Systemd units | System or user-session services over D-Bus (`org.freedesktop.systemd1`): load and active state, description, START / STOP / RESTART |
| Network | Two-way throughput curve of the active link (90 s), LAN / WAN / IPv6 / MAC (click to copy), every interface |
| Storage | A card per filesystem: capacity meter, filesystem and drive badges, all mount points, live read / write dials (MB/s) |

The fans spin at their reported speed: one turn every 60000 / RPM ms
(100 ms at 600 RPM, 30 ms from 2000 RPM), easing between readings like a
real rotor, with a motion blur once they are fast.

## Install

Needs Python 3 with PySide6 (Qt 6.5+) and psutil. `lspci` names the GPU;
NVIDIA cards report load through `pynvml` (`nvidia-ml-py`) or `nvidia-smi`.

```sh
sudo pacman -S pyside6 python-psutil      # Arch; or: pip install -r requirements.txt
./install.sh
```

`install.sh` puts a `subetha-monitor` launcher in `~/.local/bin` (pinned to
the first Python that has PySide6), the menu entry in
`~/.local/share/applications/subetha-monitor.desktop` (so it shows in
KRunner and the application menu, with jump-list actions per tab) and the
icon. `./install.sh --uninstall` removes them.

## Use

```sh
subetha-monitor [--tab=overview|processes|services|network|disks] [--theme=dark|light]
```

There is one window per session: a second launch hands its `--tab` to the
open window and raises it. The widget's **Launch full process diagnostics**
button opens the Processes tab this way, and its context menu entry the
Overview. `Ctrl+1`-`Ctrl+5` switch tabs, `Ctrl+F` searches processes,
`Delete` kills the selected one (after asking).

Signalling another user's process, and controlling system units, asks
polkit for the admin password. User units (`systemctl --user`) need none.

The theme, last tab and window size live in `~/.config/subetha-monitor.json`.

## How it reads

- `backend/telemetry.py`: CPU usage, clocks and package temperature, memory and
  swap, GPU load / VRAM / edge and junction temperature (AMD from
  `/sys/class/drm`, NVIDIA through NVML), every `fan*_input` under
  `/sys/class/hwmon`, network rates and addresses, filesystem usage and I/O
  rates from `/proc/diskstats`, battery. Sampled every 1.5 s on a worker
  thread; the public address comes from api.ipify.org when the connection
  changes.
- `backend/process_manager.py`: the process table, read only while its tab
  is on screen; filtering and sorting run over the last read, so a header
  click re-sorts at once.
- `backend/systemd_manager.py`: `ListUnitsByPatterns`, `StartUnit`,
  `StopUnit` and `RestartUnit` through `busctl`, systemd's D-Bus client,
  asynchronously, every 4 s while the tab is on screen.
- `qml/`: the window and tabs; `qml/components/` holds the themed controls,
  `DynamicFanBlade`, `DualMetricBar` and `SparklineGraph` (both ported from
  the widget's `contents/ui/common/`).
