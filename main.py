#!/usr/bin/env python3
"""The Sub-Etha System Monitor: a standalone companion to the Sub-Etha Guide
widget, in the same two looks (1981 BBC terminal, 2005 film pages).

    subetha-monitor [--tab=overview|sensors|processes|services|network|disks|settings]

One window per session: a second launch hands its --tab to the running
window over a local socket, raises it and exits, so the widget's diagnostic
buttons can aim the open monitor at a tab. While a system tray exists,
closing the window (by default) hides it to the tray instead of quitting.
The preferences (theme, tray behaviour, layout, process columns, window
size) persist in ~/.config/subetha-monitor.json.
"""

import argparse
import json
import os
import signal
import sys
import time

from PySide6.QtCore import QObject, Property, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QIcon
from PySide6.QtNetwork import QLocalServer, QLocalSocket
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtWidgets import QApplication

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from backend.hwinfo_engine import HwInfoEngine  # noqa: E402
from backend.process_manager import ProcessManager  # noqa: E402
from backend.systemd_manager import SystemdManager  # noqa: E402
from backend.telemetry import Telemetry  # noqa: E402
from backend.tray import METRICS as TRAY_METRICS, Tray  # noqa: E402

APP_ID = "subetha-monitor"
TABS = ["overview", "sensors", "processes", "services", "network", "disks", "settings"]
THEMES = ["dark", "light", "auto"]
DAY_HOURS = (7, 19)                     # "auto" shows the film pages from 07:00 to 19:00
INTERVAL_RANGE = (500, 5000)            # telemetry period, ms
CONFIG = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), APP_ID + ".json")
SOCKET = f"{APP_ID}-{os.getuid()}"
DEFAULTS = {
    "theme": "dark", "tab": "overview", "width": 1280, "height": 860,
    "closeToTray": True, "minimizeToTray": False, "startMinimized": False, "trayTooltip": True,
    "trayMetric": "planet", "trayStyle": "number",
    "tabPosition": "left", "sidebarCollapsed": False, "interval": 1500, "startupTab": "last",
    "columnWidths": {}, "columnOrder": [],
    "sensorInterval": 1000, "sensorCollapsed": [], "sensorColumnWidths": {},
}


class Settings(QObject):
    """The persisted preferences, written back on every change."""

    themeChanged = Signal()
    darkChanged = Signal()
    tabChanged = Signal()
    closeToTrayChanged = Signal()
    minimizeToTrayChanged = Signal()
    startMinimizedChanged = Signal()
    trayTooltipChanged = Signal()
    trayMetricChanged = Signal()
    trayStyleChanged = Signal()
    tabPositionChanged = Signal()
    sidebarCollapsedChanged = Signal()
    intervalChanged = Signal()
    startupTabChanged = Signal()
    columnWidthsChanged = Signal()
    columnOrderChanged = Signal()
    sensorIntervalChanged = Signal()
    sensorCollapsedChanged = Signal()
    sensorColumnWidthsChanged = Signal()
    tabRequested = Signal(str)           # a later launch, or the tray, asked for a tab

    def __init__(self, tab=None, parent=None):
        super().__init__(parent)
        self._cfg = dict(DEFAULTS)
        try:
            with open(CONFIG) as f:
                self._cfg.update(json.load(f))
        except (OSError, ValueError):
            pass
        start = self._cfg["startupTab"]
        self._start_tab = tab or (start if start in TABS else self._cfg["tab"])
        if self._start_tab not in TABS:
            self._start_tab = "overview"
        # "auto" follows the sun, roughly: the film pages by day, the terminal by night.
        self._dark = self._resolve_dark()
        self._clock = QTimer(self)
        self._clock.timeout.connect(self._update_dark)
        self._clock.start(60_000)
        self.themeChanged.connect(self._update_dark)

    def _resolve_dark(self):
        theme = self._cfg["theme"]
        if theme == "auto":
            return not DAY_HOURS[0] <= time.localtime().tm_hour < DAY_HOURS[1]
        return theme != "light"

    def _update_dark(self):
        dark = self._resolve_dark()
        if dark != self._dark:
            self._dark = dark
            self.darkChanged.emit()

    def _save(self):
        try:
            os.makedirs(os.path.dirname(CONFIG), exist_ok=True)
            tmp = CONFIG + ".tmp"
            with open(tmp, "w") as f:
                json.dump(self._cfg, f, indent=2)
            os.replace(tmp, CONFIG)
        except OSError as e:
            print(f"subetha-monitor: cannot save {CONFIG}: {e}", file=sys.stderr)

    def _setter(key, signal_name, check=None):
        def set_(self, value):
            if check and not check(value):
                return
            if self._cfg.get(key) != value:
                self._cfg[key] = value
                self._save()
                getattr(self, signal_name).emit()
        return set_

    theme = Property(str, lambda self: self._cfg["theme"] if self._cfg["theme"] in THEMES else "dark",
                     _setter("theme", "themeChanged", lambda v: v in THEMES), notify=themeChanged)
    tab = Property(str, lambda self: self._cfg["tab"] if self._cfg["tab"] in TABS else "overview",
                   _setter("tab", "tabChanged", lambda v: v in TABS), notify=tabChanged)
    closeToTray = Property(bool, lambda self: bool(self._cfg["closeToTray"]),
                           _setter("closeToTray", "closeToTrayChanged"), notify=closeToTrayChanged)
    minimizeToTray = Property(bool, lambda self: bool(self._cfg["minimizeToTray"]),
                              _setter("minimizeToTray", "minimizeToTrayChanged"), notify=minimizeToTrayChanged)
    startMinimized = Property(bool, lambda self: bool(self._cfg["startMinimized"]),
                              _setter("startMinimized", "startMinimizedChanged"), notify=startMinimizedChanged)
    trayTooltip = Property(bool, lambda self: bool(self._cfg["trayTooltip"]),
                           _setter("trayTooltip", "trayTooltipChanged"), notify=trayTooltipChanged)
    # What the tray icon shows: "planet" or a key of backend.tray.METRICS,
    # as a "number" or a "graph".
    trayMetric = Property(str, lambda self: self._cfg["trayMetric"] if self._cfg["trayMetric"] in TRAY_METRICS else "planet",
                          _setter("trayMetric", "trayMetricChanged", lambda v: v == "planet" or v in TRAY_METRICS),
                          notify=trayMetricChanged)
    trayStyle = Property(str, lambda self: "graph" if self._cfg["trayStyle"] == "graph" else "number",
                         _setter("trayStyle", "trayStyleChanged", lambda v: v in ("number", "graph")),
                         notify=trayStyleChanged)
    tabPosition = Property(str, lambda self: "top" if self._cfg["tabPosition"] == "top" else "left",
                           _setter("tabPosition", "tabPositionChanged", lambda v: v in ("top", "left")),
                           notify=tabPositionChanged)
    sidebarCollapsed = Property(bool, lambda self: bool(self._cfg["sidebarCollapsed"]),
                                _setter("sidebarCollapsed", "sidebarCollapsedChanged"), notify=sidebarCollapsedChanged)
    interval = Property(int, lambda self: min(INTERVAL_RANGE[1], max(INTERVAL_RANGE[0], int(self._cfg["interval"]))),
                        _setter("interval", "intervalChanged", lambda v: INTERVAL_RANGE[0] <= v <= INTERVAL_RANGE[1]),
                        notify=intervalChanged)
    startupTab = Property(str, lambda self: self._cfg["startupTab"],
                          _setter("startupTab", "startupTabChanged", lambda v: v == "last" or v in TABS),
                          notify=startupTabChanged)
    # Process table columns: {key: width px}, and the keys in display order.
    columnWidths = Property("QVariantMap", lambda self: self._cfg["columnWidths"],
                            _setter("columnWidths", "columnWidthsChanged"), notify=columnWidthsChanged)
    columnOrder = Property("QVariantList", lambda self: self._cfg["columnOrder"],
                           _setter("columnOrder", "columnOrderChanged"), notify=columnOrderChanged)
    # Hardware Sensors: the polling period (500, 1000 or 2000 ms), the
    # collapsed groups, and the table's column widths.
    sensorInterval = Property(int, lambda self: int(self._cfg["sensorInterval"]),
                              _setter("sensorInterval", "sensorIntervalChanged", lambda v: v in (500, 1000, 2000)),
                              notify=sensorIntervalChanged)
    sensorCollapsed = Property("QVariantList", lambda self: self._cfg["sensorCollapsed"],
                               _setter("sensorCollapsed", "sensorCollapsedChanged"), notify=sensorCollapsedChanged)
    sensorColumnWidths = Property("QVariantMap", lambda self: self._cfg["sensorColumnWidths"],
                                  _setter("sensorColumnWidths", "sensorColumnWidthsChanged"),
                                  notify=sensorColumnWidthsChanged)
    # The theme in force: `theme`, with "auto" resolved by the clock.
    dark = Property(bool, lambda self: self._dark, notify=darkChanged)
    startTab = Property(str, lambda self: self._start_tab, constant=True)
    # The size is read once at start-up and written back on close.
    width = Property(int, lambda self: int(self._cfg["width"]), constant=True)
    height = Property(int, lambda self: int(self._cfg["height"]), constant=True)
    tabs = Property("QStringList", lambda self: TABS, constant=True)
    configPath = Property(str, lambda self: CONFIG, constant=True)

    @Slot(int, int)
    def saveSize(self, w, h):
        if (w, h) != (self._cfg["width"], self._cfg["height"]):
            self._cfg["width"], self._cfg["height"] = w, h
            self._save()


def hand_off(tab):
    """Pass `tab` to a running monitor. True when one answered."""
    sock = QLocalSocket()
    sock.connectToServer(SOCKET)
    if not sock.waitForConnected(400):
        return False
    sock.write((tab or "").encode() + b"\n")
    sock.waitForBytesWritten(400)
    sock.disconnectFromServer()
    return True


def listen(settings):
    server = QLocalServer()
    QLocalServer.removeServer(SOCKET)          # a stale socket from a crash
    server.setSocketOptions(QLocalServer.UserAccessOption)
    server.listen(SOCKET)

    def accept():
        conn = server.nextPendingConnection()

        def read():
            tab = bytes(conn.readAll()).decode(errors="replace").strip()
            settings.tabRequested.emit(tab if tab in TABS else "")
        conn.readyRead.connect(read)
        conn.disconnected.connect(conn.deleteLater)
    server.newConnection.connect(accept)
    return server


def parse_args(argv):
    p = argparse.ArgumentParser(prog=APP_ID, description="The Sub-Etha System Monitor. Don't Panic.")
    p.add_argument("--tab", choices=TABS, help="open on this tab")
    p.add_argument("--theme", choices=THEMES, help="switch to this theme (it is remembered)")
    args, _qt = p.parse_known_args(argv[1:])
    return args


def build(argv):
    """The application, its engine and backends; the caller runs exec()."""
    args = parse_args(argv)
    QQuickStyle.setStyle("Basic")              # flat controls the themes can repaint
    QQuickWindow.setDefaultAlphaBuffer(True)   # the frameless window has round corners
    # QApplication rather than QGuiApplication: the tray's menu is a widget.
    app = QApplication(argv)
    app.setApplicationName(APP_ID)
    app.setApplicationDisplayName("Sub-Etha System Monitor")
    app.setOrganizationName("subetha")
    app.setDesktopFileName(APP_ID)
    icon = os.path.join(HERE, "subetha-monitor.png")
    app.setWindowIcon(QIcon.fromTheme(APP_ID, QIcon(icon)))
    # The window decides when closing quits (see MainAppWindow's onClosing).
    app.setQuitOnLastWindowClosed(False)

    if hand_off(args.tab or ""):
        return app, None, None

    settings = Settings(args.tab, app)
    if args.theme:
        settings.setProperty("theme", args.theme)
    telemetry = Telemetry(app)
    processes = ProcessManager(app)
    services = SystemdManager(app)
    hwinfo = HwInfoEngine(settings.sensorInterval, settings.sensorCollapsed, app)
    hwinfo.intervalChanged.connect(lambda: settings.setProperty("sensorInterval", hwinfo.interval))
    hwinfo.collapsedChanged.connect(lambda: settings.setProperty("sensorCollapsed", hwinfo.collapsed))
    app._server = listen(settings)
    tray = Tray(app, settings, telemetry, os.path.join(HERE, "assets", "subetha-icon.svg"))

    def retime():
        telemetry.setInterval(settings.interval)
        processes.setInterval(settings.interval)
    settings.intervalChanged.connect(retime)
    retime()

    def shutdown():
        telemetry.stop()
        processes.stop()
        hwinfo.stop()
    app.aboutToQuit.connect(shutdown)

    engine = QQmlApplicationEngine()
    ctx = engine.rootContext()
    ctx.setContextProperty("settings", settings)
    ctx.setContextProperty("telemetry", telemetry)
    ctx.setContextProperty("processes", processes)
    ctx.setContextProperty("services", services)
    ctx.setContextProperty("hwinfo", hwinfo)
    ctx.setContextProperty("tray", tray)
    engine.load(QUrl.fromLocalFile(os.path.join(HERE, "qml", "MainAppWindow.qml")))
    if not engine.rootObjects():
        sys.exit(1)
    return app, engine, (settings, telemetry, processes, services, hwinfo, tray)


def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)   # Ctrl+C in a terminal quits
    app, engine, _keep = build(sys.argv)
    if engine is None:
        return 0                                 # handed off to the running window
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
