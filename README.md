# Sub-Etha System Monitor

A standalone desktop system monitor in the two looks of
[The Sub-Etha Guide](https://github.com/Shani2480/subetha-guide), the KDE Plasma widget it pairs with:
the 1981 BBC terminal's phosphor green on CRT black (with scanlines and amber
reticles), and the 2005 film's cream Encyclopedia pages (with hard flat
shadows). One button in the title bar switches between them (`Ctrl+T`);
a third setting, Solar Auto, shows the film pages from 07:00 to 19:00 and
the terminal after dark.

The window draws its own frame: a title bar with the smiling planet, DON'T
PANIC, the theme switch and minimize / maximize / close (drag it to move,
double-click to maximize; the edges resize). Navigation sits in a left rail
(collapsible to a 48px strip of tab numbers) or along the top, as you
prefer. A planet in the system tray (or, if you prefer, one live reading drawn as
a number or a graph) shows CPU, RAM and GPU temperature in its tooltip and keeps the monitor running when the window is closed.

| Tab | Shows |
| --- | --- |
| Overview | Host profile (CPU, GPU, RAM, kernel) with a Guide entry fitted to the machine's state; CPU, GPU, memory, cooling, network and storage tiles with load-over-temperature bars and 24-sample sparklines |
| Processes | Every process: PID, name and command line, user, CPU %, memory, disk read and write, threads, nice. Filter by name, PID or command; quick filters for your own, system (UID < 1000) and busy (> 5 % CPU) processes. Click a heading to sort (again to flip), drag it to reorder, drag its edge to resize. Right-click a process to end (SIGTERM) or kill (SIGKILL) it after a confirmation, set its priority, copy its PID or command line, or open its properties: memory, ancestry and children, largest memory maps, open files |
| Systemd units | System or user-session services over D-Bus (`org.freedesktop.systemd1`): load and active state, description, START / STOP / RESTART |
| Network | Two-way throughput curve of the active link (90 s), LAN / WAN / IPv6 / MAC (click to copy), every interface |
| Storage | A card per filesystem: capacity meter, filesystem and drive badges, all mount points, live read / write dials (MB/s) |
| Settings | Tray behaviour (close / minimize to tray, start in the tray, live tooltip, the icon as the planet or a live number or graph of CPU, memory, swap or GPU load or temperature), tab position, telemetry interval (0.5 to 5 s), startup tab, and the three themes with previews |

The fans spin in proportion to how hard they are working: still when
stopped, 2.5 turns a second at full speed (the kernel's `fan*_max`, or
6000 RPM when it gives none), easing between readings like a real rotor,
with a motion blur above half speed. Drawing the literal RPM would strobe:
a four-bladed fan at 2400 RPM moves 240° a frame and seems to stutter or
run backwards.

## Install

Needs Python 3 with PySide6 (Qt 6.6+) and psutil. `lspci` names the GPU;
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
subetha-monitor [--tab=overview|processes|services|network|disks|settings] [--theme=dark|light|auto]
```

There is one window per session: a second launch hands its `--tab` to the
open window and raises it. The widget's **Launch full process diagnostics**
button opens the Processes tab this way, and its context menu entry the
Overview. `Ctrl+1`-`Ctrl+6` switch tabs, `Ctrl+F` searches processes,
`Delete` kills the selected one (after asking), `Alt+Enter` opens its
properties, `Ctrl+Q` quits.

While a system tray exists, closing the window hides it there (once a
session a notification says so); quit from the tray icon's menu, which
also restores the window, opens it on a tab or switches the theme. Turn
`closeToTray` off and closing quits as usual.

Signalling or renicing another user's process, raising any process's
priority (a negative nice), and controlling system units, asks polkit for
the admin password. User units (`systemctl --user`) need none.

Everything is saved in `~/.config/subetha-monitor.json`:

| Key | Default | |
| --- | --- | --- |
| `theme` | `"dark"` | `"dark"`, `"light"` or `"auto"` |
| `closeToTray` | `true` | the close button hides to the tray |
| `minimizeToTray` | `false` | minimizing hides to the tray instead of the taskbar |
| `startMinimized` | `false` | start in the tray, window hidden |
| `trayTooltip` | `true` | live CPU / RAM / GPU in the tray tooltip |
| `trayMetric` | `"planet"` | the tray icon: the planet, or `"cpu"`, `"cpuTemp"`, `"ram"`, `"swap"`, `"gpu"`, `"gpuTemp"` |
| `trayStyle` | `"number"` | a reading as a `"number"` or a `"graph"` of the last 20 samples |
| `tabPosition` | `"left"` | `"left"` rail or `"top"` strip |
| `sidebarCollapsed` | `false` | the rail as a 48px strip |
| `interval` | `1500` | telemetry period in ms, 500 to 5000 |
| `startupTab` | `"last"` | `"last"` or a tab name |
| `columnWidths`, `columnOrder` | | the process table's layout |
| `tab`, `width`, `height` | | the last tab and window size |

### Alerts

The CPU, GPU, memory and storage cards follow the widget's alert levels.
At a warning a card shows `[WARN]` and its figure turns amber. When
critical, `[CRITICAL: 88°C]` blinks, the card is haloed with a breathing
crimson glow, and its bar strobes (temperature) or pulses (load). The
thresholds have the widget's defaults: 75 / 85 °C for temperatures and
90 / 95 / 90 % for CPU, GPU and memory load. A disk is critical at 90 %
full. All of them, and switches for the colours and the motion, are in
Settings → Alerts and saved as `alertsEnabled`, `enablePulsingAnimations`
and `…Threshold` keys in the config file. The two apps don't share these
settings: each keeps its own.

## How it reads

- `backend/telemetry.py`: CPU usage, clocks and package temperature, memory and
  swap, GPU load / VRAM / edge and junction temperature (AMD from
  `/sys/class/drm`, NVIDIA through NVML), every `fan*_input` under
  `/sys/class/hwmon`, network rates and addresses, filesystem usage and I/O
  rates from `/proc/diskstats`, battery. Sampled every 1.5 s (or the
  configured interval) on a worker thread; the public address comes from api.ipify.org when the connection
  changes.
- `backend/process_manager.py`: the process table, read only while its tab
  is on screen; filtering and sorting run over the last read, so a header
  click re-sorts at once. Signals and renice, with pkexec when refused, and
  one process's details on demand.
- `backend/tray.py`: the tray icon (`assets/subetha-icon.svg`), its menu
  and tooltip.
- `backend/systemd_manager.py`: `ListUnitsByPatterns`, `StartUnit`,
  `StopUnit` and `RestartUnit` through `busctl`, systemd's D-Bus client,
  asynchronously, every 4 s while the tab is on screen.
- `qml/`: the window and tabs; `qml/components/` holds the title bar, the
  navigation rail, the themed controls,
  `DynamicFanBlade`, `DualMetricBar` and `SparklineGraph` (both ported from
  the widget's `contents/ui/common/`).
