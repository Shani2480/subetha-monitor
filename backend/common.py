"""Plumbing shared by the backends: a poller that samples on its own thread,
and a list model that updates rows in place so views keep their scroll."""

import traceback

from PySide6.QtCore import (QAbstractListModel, QModelIndex, QObject, QThread,
                            QTimer, Property, Qt, Signal, Slot)


class Poller(QObject):
    """Calls `fn` every `interval` ms on a worker thread and emits what it
    returns. While `enabled` is false the timer still ticks but samples
    nothing, so a hidden tab costs no reads. `poke` samples at once;
    `retime` changes the interval from any thread."""

    result = Signal(object)
    poke = Signal()
    retime = Signal(int)

    def __init__(self, fn, interval):
        super().__init__()
        self._fn = fn
        self._interval = interval
        self._timer = None
        self.enabled = True
        self.poke.connect(self.tick)
        self.retime.connect(self._retime)

    @Slot()
    def start(self):
        self._timer = QTimer(self)
        self._timer.timeout.connect(self.tick)
        self._timer.start(self._interval)
        self.tick()

    @Slot(int)
    def _retime(self, ms):
        self._interval = ms
        if self._timer:
            self._timer.setInterval(ms)

    @Slot()
    def tick(self):
        if not self.enabled:
            return
        try:
            self.result.emit(self._fn())
        except Exception:  # a bad read must never kill the poller
            traceback.print_exc()


def start_poller(poller):
    """Run `poller` on a thread of its own; returns the thread to stop later."""
    thread = QThread()
    poller.moveToThread(thread)
    thread.started.connect(poller.start)
    thread.start()
    return thread


class RowsModel(QAbstractListModel):
    """Rows of dicts, one role per key. set_rows() overwrites rows in place and
    only inserts or removes at the tail, so a re-sorted table refreshes
    without resetting its view's scroll position or delegates."""

    countChanged = Signal()

    def __init__(self, keys, parent=None):
        super().__init__(parent)
        self._keys = list(keys)
        self._roles = {Qt.UserRole + 1 + i: k for i, k in enumerate(self._keys)}
        self._rows = []

    def roleNames(self):
        return {r: k.encode() for r, k in self._roles.items()}

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self._rows)

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid() or not 0 <= index.row() < len(self._rows):
            return None
        key = self._roles.get(role)
        return self._rows[index.row()].get(key) if key else None

    def rows(self):
        return self._rows

    def set_rows(self, rows):
        old, new = len(self._rows), len(rows)
        if new < old:
            self.beginRemoveRows(QModelIndex(), new, old - 1)
            del self._rows[new:]
            self.endRemoveRows()
        common = min(old, new)
        if common:
            self._rows[:common] = rows[:common]
            self.dataChanged.emit(self.index(0), self.index(common - 1))
        if new > old:
            self.beginInsertRows(QModelIndex(), old, new - 1)
            self._rows.extend(rows[old:])
            self.endInsertRows()
        if new != old:
            self.countChanged.emit()

    @Slot(int, result="QVariantMap")
    def get(self, row):
        return dict(self._rows[row]) if 0 <= row < len(self._rows) else {}

    count = Property(int, lambda self: len(self._rows), notify=countChanged)
