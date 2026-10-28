"""The system tray icon: the smiling planet, or one live reading drawn as a
number or a graph (settings.trayMetric, settings.trayStyle), with telemetry
in its tooltip and a menu to restore the window, open it on a tab, switch
the theme or quit.

The window itself lives in QML, so the tray only asks: `activateRequested`
(a click on the icon) and `toggleThemeRequested` are handled there, and a
tab request goes through `settings.tabRequested` like a second launch's.
Quitting from here is the one way out while closeToTray is on.
"""

from collections import deque

from PySide6.QtCore import QBuffer, QByteArray, QObject, QPointF, QRectF, Qt, Property, Signal, Slot
from PySide6.QtGui import QAction, QColor, QFont, QFontMetricsF, QIcon, QPainter, QPainterPath, QPen, QPixmap
from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

TAB_LABELS = [("overview", "Overview"), ("sensors", "Hardware Sensors"), ("processes", "Processes"), ("services", "Services"),
              ("network", "Network"), ("disks", "Storage"), ("settings", "Settings")]
HINT = "Sub-Etha Monitor is still running in the system tray. Right-click icon to quit."

SIZE = 64             # drawn at 64 px; the panel scales it down
GRAPH_SAMPLES = 20


def _gpu(d, key):
    g = d.get("gpu", {})
    return g.get(key) if g.get("present") else None


# key: (reading from a sample or None, unit shown after the number, is a temperature)
METRICS = {
    "cpu":     (lambda d: d["cpu"]["usage"], "", False),
    "cpuTemp": (lambda d: d["cpu"]["temp"] or None, "°", True),
    "ram":     (lambda d: d["mem"]["percent"], "", False),
    "swap":    (lambda d: d["mem"]["swapPercent"] if d["mem"]["swapTotal"] else None, "", False),
    "gpu":     (lambda d: _gpu(d, "usage"), "", False),
    "gpuTemp": (lambda d: _gpu(d, "temp") or None, "°", True),
}
TEMP_RANGE = (30, 100)       # a temperature graph spans this, in °C

# The two looks, as in qml/components/Theme.qml: ground, rule, and the
# good / middling / bad levels.
PALETTE = {
    True:  {"bg": "#040806", "rule": "#00FF66", "levels": ("#00FF66", "#FFB000", "#FF3333")},
    False: {"bg": "#F5F2EB", "rule": "#1B2028", "levels": ("#1B2028", "#C98A00", "#E53935"),
            "fills": ("#26A69A", "#FFBE1A", "#FF6B4A")},
}


def _level(value, temp):
    """0 good, 1 middling, 2 bad: Theme.heat for temperatures, Theme.load otherwise."""
    hi, mid = (90, 75) if temp else (85, 50)
    return 2 if value >= hi else 1 if value >= mid else 0


def render(value, history, unit, temp, dark, style):
    """One reading as a 64 px icon: a framed number, or a framed area graph
    of the recent history coloured by the latest level."""
    pal = PALETTE[dark]
    level = _level(value, temp)
    pix = QPixmap(SIZE, SIZE)
    pix.fill(Qt.transparent)
    p = QPainter(pix)
    p.setRenderHint(QPainter.Antialiasing)
    frame = QRectF(2, 2, SIZE - 4, SIZE - 4)
    p.setPen(QPen(QColor(pal["rule"]), 3))
    p.setBrush(QColor(pal["bg"]))
    p.drawRoundedRect(frame, 8, 8)

    if style == "graph":
        inner = frame.adjusted(5, 5, -5, -5)
        lo, hi = TEMP_RANGE if temp else (0, 100)
        pts = list(history)[-GRAPH_SAMPLES:] or [value]
        step = inner.width() / max(1, GRAPH_SAMPLES - 1)
        x0 = inner.right() - step * (len(pts) - 1)
        line = QPainterPath()
        for i, v in enumerate(pts):
            f = max(0.0, min(1.0, (v - lo) / (hi - lo)))
            pt = QPointF(x0 + i * step, inner.bottom() - f * inner.height())
            line.lineTo(pt) if i else line.moveTo(pt)
        area = QPainterPath(line)
        area.lineTo(inner.right(), inner.bottom())
        area.lineTo(x0, inner.bottom())
        area.closeSubpath()
        stroke = QColor(pal["levels"][level])
        fill = QColor(pal.get("fills", pal["levels"])[level])
        fill.setAlphaF(0.45 if dark else 0.7)
        p.setPen(Qt.NoPen)
        p.setBrush(fill)
        p.drawPath(area)
        p.setPen(QPen(stroke, 3.5, Qt.SolidLine, Qt.RoundCap, Qt.RoundJoin))
        p.setBrush(Qt.NoBrush)
        p.drawPath(line)
    else:
        text = f"{value:.0f}{unit}"
        font = QFont("monospace")
        font.setBold(True)
        font.setStyleHint(QFont.Monospace)
        px = 44                                  # as large as fits the frame
        while px > 12:
            font.setPixelSize(px)
            if QFontMetricsF(font).horizontalAdvance(text) <= frame.width() - 6:
                break
            px -= 2
        p.setFont(font)
        p.setPen(QColor(pal["levels"][level]))
        p.drawText(frame, Qt.AlignCenter, text)
    p.end()
    return pix


class Tray(QObject):
    activateRequested = Signal()
    toggleThemeRequested = Signal()
    previewChanged = Signal()

    def __init__(self, app, settings, telemetry, icon_path):
        super().__init__(app)
        self._app = app
        self._settings = settings
        self._telemetry = telemetry
        self._hinted = False
        self._planet = QIcon(icon_path)
        self._history = {k: deque(maxlen=GRAPH_SAMPLES) for k in METRICS}
        self._preview = ""
        self._available = QSystemTrayIcon.isSystemTrayAvailable()
        self._icon = None
        telemetry.dataChanged.connect(self._on_sample)
        for sig in (settings.trayMetricChanged, settings.trayStyleChanged, settings.darkChanged):
            sig.connect(self._redraw)
        if not self._available:
            return

        self._icon = QSystemTrayIcon(self._planet, self)
        self._icon.setToolTip("Sub-Etha Monitor")
        self._icon.activated.connect(self._on_activated)

        menu = QMenu()
        menu.addAction("Show / Restore Window", lambda: settings.tabRequested.emit(""))
        tabs = menu.addMenu("Open to Tab...")
        for key, label in TAB_LABELS:
            tabs.addAction(label, lambda key=key: settings.tabRequested.emit(key))
        self._theme_action = QAction(menu)
        self._theme_action.triggered.connect(self.toggleThemeRequested)
        menu.addAction(self._theme_action)
        menu.addSeparator()
        menu.addAction("Quit Sub-Etha Monitor", self.quit)
        menu.aboutToShow.connect(self._label_theme)
        self._menu = menu                         # the tray icon does not own it
        self._icon.setContextMenu(menu)

        telemetry.dataChanged.connect(self._update_tooltip)
        settings.trayTooltipChanged.connect(self._update_tooltip)
        self._icon.show()

    def _on_activated(self, reason):
        if reason in (QSystemTrayIcon.Trigger, QSystemTrayIcon.DoubleClick):
            self.activateRequested.emit()

    def _label_theme(self):
        dark = self._settings.dark
        self._theme_action.setText("Toggle Theme (to 2005 Movie Light)" if dark
                                   else "Toggle Theme (to 1981 CRT Dark)")

    def _on_sample(self):
        d = self._telemetry.data
        for key, (read, _unit, _temp) in METRICS.items():
            v = read(d)
            if v is not None:
                self._history[key].append(v)
        # The telemetry keeps usage histories already (0..1), so those graphs
        # start full; temperatures and swap fill up as samples arrive.
        for key in ("cpu", "ram", "gpu"):
            past = d.get("history", {}).get(key)
            if past:
                self._history[key] = deque((v * 100 for v in past), maxlen=GRAPH_SAMPLES)
        self._redraw()

    def _redraw(self):
        """The planet, or the chosen reading; the planet too while that
        reading is missing (no GPU, no sensor, no sample yet)."""
        key = self._settings.trayMetric
        d = self._telemetry.data
        read, unit, temp = METRICS.get(key, (None, "", False))
        value = read(d) if read and d else None
        if value is None:
            icon, preview = self._planet, ""
        else:
            pix = render(value, self._history[key], unit, temp, self._settings.dark, self._settings.trayStyle)
            icon = QIcon(pix)
            buf = QBuffer()
            buf.open(QBuffer.WriteOnly)
            pix.save(buf, "PNG")
            preview = "data:image/png;base64," + bytes(QByteArray(buf.data()).toBase64()).decode()
        if self._icon:
            self._icon.setIcon(icon)
        if preview != self._preview:
            self._preview = preview
            self.previewChanged.emit()

    def _update_tooltip(self):
        if not self._settings.trayTooltip:
            self._icon.setToolTip("Sub-Etha Monitor")
            return
        d = self._telemetry.data
        if not d:
            return
        parts = [f"CPU: {d['cpu']['usage']:.0f}%", f"RAM: {d['mem']['percent']:.0f}%"]
        gpu = d.get("gpu", {})
        if gpu.get("present") and gpu.get("temp"):
            parts.append(f"GPU: {gpu['temp']:.0f}°C")
        self._icon.setToolTip("Sub-Etha Monitor | " + " | ".join(parts))

    # ---- QML ----
    @Slot()
    def hintOnce(self):
        """Tell the user, once a session, that closing did not quit."""
        if self._icon and not self._hinted:
            self._hinted = True
            self._icon.showMessage("Sub-Etha Monitor", HINT, QIcon(self._icon.icon()), 6000)

    @Slot()
    def quit(self):
        QApplication.quit()

    available = Property(bool, lambda self: self._available, constant=True)
    # The icon as drawn now, as a data: URL for the settings page; "" for the planet.
    preview = Property(str, lambda self: self._preview, notify=previewChanged)
