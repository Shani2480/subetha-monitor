#!/usr/bin/env python3
"""The Sub-Etha System Monitor: a standalone companion to the Sub-Etha Guide
widget, in the same two looks (1981 BBC terminal, 2005 film pages).

    subetha-monitor [--tab=overview|processes|services|network|disks]

One window per session: a second launch hands its --tab to the running
window over a local socket, raises it and exits, so the widget's diagnostic
buttons can aim the open monitor at a tab. The theme, last tab and window
size persist in ~/.config/subetha-monitor.json.
"""

import argparse
import json
import os
import signal
import sys

from PySide6.QtCore import QObject, Property, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtNetwork import QLocalServer, QLocalSocket
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from backend.process_manager import ProcessManager  # noqa: E402
from backend.systemd_manager import SystemdManager  # noqa: E402
from backend.telemetry import Telemetry  # noqa: E402

APP_ID = "subetha-monitor"
TABS = ["overview", "processes", "services", "network", "disks"]
CONFIG = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), APP_ID + ".json")
SOCKET = f"{APP_ID}-{os.getuid()}"


class Settings(QObject):
    """The persisted preferences, written back on every change."""

    themeChanged = Signal()
    tabChanged = Signal()
    tabRequested = Signal(str)           # a later launch asked for a tab

    def __init__(self, tab=None, parent=None):
        super().__init__(parent)
        self._cfg = {"theme": "dark", "tab": "overview", "width": 1280, "height": 860}
        try:
            with open(CONFIG) as f:
                self._cfg.update(json.load(f))
        except (OSError, ValueError):
            pass
        if tab:
            self._cfg["tab"] = tab

    def _save(self):
        try:
            os.makedirs(os.path.dirname(CONFIG), exist_ok=True)
            tmp = CONFIG + ".tmp"
            with open(tmp, "w") as f:
                json.dump(self._cfg, f, indent=2)
            os.replace(tmp, CONFIG)
        except OSError as e:
            print(f"subetha-monitor: cannot save {CONFIG}: {e}", file=sys.stderr)

    def _setter(key, signal_name):
        def set_(self, value):
            if self._cfg.get(key) != value:
                self._cfg[key] = value
                self._save()
                getattr(self, signal_name).emit()
        return set_

    theme = Property(str, lambda self: self._cfg["theme"], _setter("theme", "themeChanged"), notify=themeChanged)
    tab = Property(str, lambda self: self._cfg["tab"] if self._cfg["tab"] in TABS else "overview",
                   _setter("tab", "tabChanged"), notify=tabChanged)
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
    p.add_argument("--theme", choices=["dark", "light"], help="switch to this theme (it is remembered)")
    args, _qt = p.parse_known_args(argv[1:])
    return args


def build(argv):
    """The application, its engine and backends; the caller runs exec()."""
    args = parse_args(argv)
    QQuickStyle.setStyle("Basic")              # flat controls the themes can repaint
    app = QGuiApplication(argv)
    app.setApplicationName(APP_ID)
    app.setApplicationDisplayName("Sub-Etha System Monitor")
    app.setOrganizationName("subetha")
    app.setDesktopFileName(APP_ID)
    icon = os.path.join(HERE, "subetha-monitor.png")
    app.setWindowIcon(QIcon.fromTheme(APP_ID, QIcon(icon)))

    if hand_off(args.tab or ""):
        return app, None, None

    settings = Settings(args.tab, app)
    if args.theme:
        settings.setProperty("theme", args.theme)
    telemetry = Telemetry(app)
    processes = ProcessManager(app)
    services = SystemdManager(app)
    app._server = listen(settings)

    def shutdown():
        telemetry.stop()
        processes.stop()
    app.aboutToQuit.connect(shutdown)

    engine = QQmlApplicationEngine()
    ctx = engine.rootContext()
    ctx.setContextProperty("settings", settings)
    ctx.setContextProperty("telemetry", telemetry)
    ctx.setContextProperty("processes", processes)
    ctx.setContextProperty("services", services)
    engine.load(QUrl.fromLocalFile(os.path.join(HERE, "qml", "MainAppWindow.qml")))
    if not engine.rootObjects():
        sys.exit(1)
    return app, engine, (settings, telemetry, processes, services)


def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)   # Ctrl+C in a terminal quits
    app, engine, _keep = build(sys.argv)
    if engine is None:
        return 0                                 # handed off to the running window
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
