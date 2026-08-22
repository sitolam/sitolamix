"""
Efficiency Tracker — Anki add-on
Compares your actual study time in Anki against the time you attempted
to study, and visualises your efficiency over time.
"""

import json
import os
from datetime import datetime, timedelta

from aqt import mw, gui_hooks
from aqt.qt import (
    QAction, QDialog, QVBoxLayout, QHBoxLayout, QPushButton,
    QLabel, QDoubleSpinBox, QDialogButtonBox, QDateEdit, QDate, Qt,
    QWebEngineView, QTimer, QComboBox, QFileDialog,
    QTimeEdit, QTime, QSpinBox, QRadioButton, QButtonGroup,
    QScrollArea, QWidget, QFormLayout,
)
from aqt.utils import qconnect, tooltip, showInfo, askUser

ADDON_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_FILE = os.path.join(ADDON_DIR, "user_data.json")
ACTIVE_SESSION_FILE = os.path.join(ADDON_DIR, "active_session.json")

DEFAULT_CONFIG = {
    "theme": "auto",
    "good_threshold": 70,
    "warn_threshold": 45,
    "show_toolbar_button": True,
    "range_days": 30,
    "notify_every_30min": True,
}

RANGE_OPTIONS = [(7, "Last 7 days"), (30, "Last 30 days"),
                 (90, "Last 90 days"), (365, "Last 365 days")]

# Cycle order for the in-dashboard theme toggle button.
THEME_CYCLE = ["auto", "light", "dark"]
THEME_LABELS = {"auto": "Theme: Auto 🌓", "light": "Theme: Light ☀️", "dark": "Theme: Dark 🌙"}


# ---------- Config ----------

def get_config():
    """Read the user's addon config, falling back to defaults for missing keys."""
    cfg = mw.addonManager.getConfig(__name__) or {}
    merged = dict(DEFAULT_CONFIG)
    merged.update(cfg)
    return merged


def save_config(cfg):
    mw.addonManager.writeConfig(__name__, cfg)


# ---------- Data persistence ----------

def load_data():
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            return {}
    return {}


def save_data(data):
    try:
        with open(DATA_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
    except IOError as e:
        showInfo(f"Could not save data: {e}")


# ---------- Active session persistence ----------
#
# A live session in progress is stored in active_session.json (separate from
# user_data.json so a corrupt running-session file can't damage your daily
# logs). Schema:
#
#   {"started_at": "2026-05-04T13:42:11", "anki_date": "2026-05-04",
#    "last_notify": "2026-05-04T14:12:11"}
#
# The file's existence is the source of truth: present means a session is
# running, absent means none.

def load_active_session():
    if not os.path.exists(ACTIVE_SESSION_FILE):
        return None
    try:
        with open(ACTIVE_SESSION_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return None


def save_active_session(session):
    try:
        with open(ACTIVE_SESSION_FILE, "w", encoding="utf-8") as f:
            json.dump(session, f, indent=2, ensure_ascii=False)
    except IOError as e:
        showInfo(f"Could not save active session: {e}")


def clear_active_session():
    if os.path.exists(ACTIVE_SESSION_FILE):
        try:
            os.remove(ACTIVE_SESSION_FILE)
        except OSError:
            pass


# ---------- Anki integration ----------

def get_rollover_hour():
    """Anki's day rollover hour (default 4 AM)."""
    try:
        return mw.col.get_config("rollover", 4)
    except Exception:
        try:
            return mw.col.conf.get("rollover", 4)
        except Exception:
            return 4


def anki_date_for(dt):
    """The Anki-day a given datetime belongs to (rollover-aware). At 02:30
    with rollover=4, this returns yesterday's calendar date — exactly how
    Anki itself counts reviews from that moment."""
    rollover = get_rollover_hour()
    if dt.hour < rollover:
        dt = dt - timedelta(days=1)
    return dt.strftime("%Y-%m-%d")


def today_anki_date():
    """Convenience: Anki-day for right now."""
    return anki_date_for(datetime.now())


def anki_day_start(date_str):
    """The wall-clock datetime at which the given Anki-day begins (i.e. the
    rollover hour on that calendar date)."""
    rollover = get_rollover_hour()
    dt = datetime.strptime(date_str, "%Y-%m-%d")
    return dt.replace(hour=rollover, minute=0, second=0, microsecond=0)


def qdate_for_anki_today():
    """QDate for Anki's current day (rollover-aware). Used as the default
    selection / max date in the input dialog so users see the day Anki
    is currently logging reviews against."""
    today_str = today_anki_date()
    y, m, d = today_str.split("-")
    return QDate(int(y), int(m), int(d))


def get_study_minutes_for_date(date_str):
    """Actual Anki study time in minutes for a YYYY-MM-DD date."""
    if mw.col is None:
        return 0.0
    rollover = get_rollover_hour()
    try:
        dt = datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError:
        return 0.0

    day_start = dt.replace(hour=rollover, minute=0, second=0, microsecond=0)
    day_end = day_start + timedelta(days=1)

    start_ms = int(day_start.timestamp() * 1000)
    end_ms = int(day_end.timestamp() * 1000)

    try:
        total_ms = mw.col.db.scalar(
            "SELECT SUM(time) FROM revlog WHERE id >= ? AND id < ?",
            start_ms, end_ms,
        ) or 0
        return total_ms / 1000.0 / 60.0
    except Exception:
        return 0.0


def get_study_minutes_in_window(start_dt, end_dt):
    """Actual Anki study time in minutes between two datetimes."""
    if mw.col is None:
        return 0.0
    start_ms = int(start_dt.timestamp() * 1000)
    end_ms = int(end_dt.timestamp() * 1000)
    try:
        total_ms = mw.col.db.scalar(
            "SELECT SUM(time) FROM revlog WHERE id >= ? AND id < ?",
            start_ms, end_ms,
        ) or 0
        return total_ms / 1000.0 / 60.0
    except Exception:
        return 0.0


# ---------- Live session tracker ----------
#
# LiveTracker is a singleton that owns the running-session state. The Qt
# widgets (statusbar label, dialogs) are observers — they call get_state()
# and a 1-second QTimer to keep their UI fresh. State changes go through
# tracker methods (start, stop) which fire callbacks so observers can refresh.

class LiveTracker:
    NOTIFY_INTERVAL_MIN = 30

    def __init__(self):
        self._listeners = []
        self._tick_timer = QTimer()
        self._tick_timer.setInterval(1000)  # 1 Hz
        self._tick_timer.timeout.connect(self._on_tick)

    def add_listener(self, fn):
        """Register a no-arg callback fired whenever the displayed state
        might change (every second while running, plus start/stop edges)."""
        if fn not in self._listeners:
            self._listeners.append(fn)

    def remove_listener(self, fn):
        if fn in self._listeners:
            self._listeners.remove(fn)

    def _notify_listeners(self):
        for fn in list(self._listeners):
            try:
                fn()
            except Exception:
                pass

    def is_running(self):
        return load_active_session() is not None

    def start(self, started_at=None):
        """Start a live session. By default anchored to right now, but a
        datetime can be passed for back-dated starts (e.g., 'I actually sat
        down 5 minutes ago')."""
        if self.is_running():
            return False
        now = datetime.now()
        if started_at is None:
            started_at = now
        save_active_session({
            "started_at": started_at.isoformat(timespec="seconds"),
            "anki_date": anki_date_for(started_at),
            "last_notify": now.isoformat(timespec="seconds"),
        })
        self._tick_timer.start()
        self._notify_listeners()
        return True

    def stop(self, silent=False):
        """End the live session and persist it as a normal timed session.
        If silent=True (used at app shutdown) no tooltip is shown."""
        sess = load_active_session()
        if sess is None:
            self._tick_timer.stop()
            return None
        try:
            started = datetime.fromisoformat(sess["started_at"])
        except (KeyError, ValueError):
            clear_active_session()
            self._tick_timer.stop()
            self._notify_listeners()
            return None

        end = datetime.now()
        minutes = max(0, (end - started).total_seconds() / 60.0)

        # Bucket to the Anki-day the session *started* on. If the user
        # studied across the rollover boundary we still attribute the whole
        # block to the start day; the alternative — splitting in two — would
        # surprise people who logged a single sitting.
        date_str = sess.get("anki_date") or today_anki_date()

        if minutes >= 0.5:  # ignore accidental clicks under 30 seconds
            new_session = {
                "start": started.strftime("%H:%M"),
                "end": end.strftime("%H:%M"),
                "minutes": round(minutes, 1),
            }
            sessions = get_sessions_for_date(date_str)
            sessions.append(new_session)
            write_sessions_for_date(date_str, sessions)

        clear_active_session()
        self._tick_timer.stop()
        self._notify_listeners()

        if not silent:
            tooltip(f"Saved session: {minutes:.1f} min on {date_str}")
        return minutes

    def ensure_timer_for_loaded_session(self):
        """Called at profile-load: if a session file survived a previous
        run, decide what to do with it. Per user preference: auto-stop and
        save. We treat the session as ending NOW (when Anki was reopened),
        i.e. duration = now - started_at."""
        sess = load_active_session()
        if sess is None:
            return
        try:
            started = datetime.fromisoformat(sess["started_at"])
        except (KeyError, ValueError):
            clear_active_session()
            return
        # Cap recovered sessions at 24h — anything longer is almost
        # certainly Anki being closed for days, not a real session.
        elapsed = datetime.now() - started
        if elapsed.total_seconds() > 24 * 3600:
            clear_active_session()
            tooltip("Discarded a stale running session (> 24 h old)")
            return
        # Save what was tracked so far, silently.
        self.stop(silent=True)
        tooltip(f"Recovered an unfinished session ({elapsed.total_seconds()/60:.0f} min) — saved")

    def get_state(self):
        """Snapshot of the running session for UI rendering. Returns None
        when no session is active."""
        sess = load_active_session()
        if sess is None:
            return None
        try:
            started = datetime.fromisoformat(sess["started_at"])
        except (KeyError, ValueError):
            return None
        now = datetime.now()
        elapsed_min = max(0, (now - started).total_seconds() / 60.0)
        active_min = get_study_minutes_in_window(started, now)
        eff = (active_min / elapsed_min * 100) if elapsed_min > 0 else None
        return {
            "started": started,
            "elapsed_min": elapsed_min,
            "active_min": active_min,
            "efficiency": eff,
            "anki_date": sess.get("anki_date"),
        }

    # ----- internal: tick handler -----

    def _on_tick(self):
        # Fire visual updates regardless of whether a notification is due.
        self._notify_listeners()

        # Notification logic — only if enabled and 30 minutes have passed
        # since the last notification (or session start).
        if not get_config().get("notify_every_30min", True):
            return
        sess = load_active_session()
        if sess is None:
            self._tick_timer.stop()
            return
        try:
            last = datetime.fromisoformat(sess.get("last_notify", sess["started_at"]))
        except (KeyError, ValueError):
            return
        now = datetime.now()
        if (now - last).total_seconds() < self.NOTIFY_INTERVAL_MIN * 60:
            return

        # Time for a check-in. Update the last-notify timestamp first so a
        # slow tooltip doesn't accidentally fire twice.
        sess["last_notify"] = now.isoformat(timespec="seconds")
        save_active_session(sess)

        state = self.get_state()
        if state is None:
            return
        eff_str = f"{state['efficiency']:.0f}%" if state["efficiency"] is not None else "—"
        tooltip(
            f"⏱ Efficiency check-in — studying for {state['elapsed_min']:.0f} min, "
            f"{state['active_min']:.1f} min in Anki ({eff_str})",
            period=6000,
        )


# Module-level singleton. Created lazily so test imports don't need a Qt
# event loop.
_tracker_instance = None

def get_tracker():
    global _tracker_instance
    if _tracker_instance is None:
        _tracker_instance = LiveTracker()
    return _tracker_instance


# ---------- Session helpers ----------

def compute_attempted_minutes(entry):
    """Total attempted minutes from a data entry, supporting both formats:
    - new: {"sessions": [{minutes, ?start, ?end}, ...]}
    - legacy: {"attempted": N}
    """
    if not isinstance(entry, dict):
        return 0
    sessions = entry.get("sessions")
    if isinstance(sessions, list) and sessions:
        total = 0
        for s in sessions:
            if isinstance(s, dict):
                m = s.get("minutes", 0)
                if isinstance(m, (int, float)):
                    total += m
        return total
    return entry.get("attempted", 0)


def compute_effective_attempted(raw_attempted, actual_minutes):
    """How many minutes of "attempted" we *display*. Capped from below by
    the actual Anki time so efficiency can't exceed 100%.

    Rationale: if you studied 60 min in Anki but only logged a 30 min
    session, you didn't *attempt less than you actually studied* — you
    just forgot to log enough. The efficiency you see is `actual /
    effective`, which becomes `actual / actual = 100%` until your logged
    sessions exceed your Anki time, at which point the ratio starts to
    drop honestly.

    A day with no logged sessions (raw == 0) returns 0 so we can show
    "no data" rather than pretending all-Anki-was-attempted.
    """
    if raw_attempted <= 0:
        return 0
    return max(raw_attempted, actual_minutes)


def compute_efficiency_percent(raw_attempted, actual_minutes):
    """Returns None when there is no attempted time logged for the day.
    Otherwise the percentage, always between 0 and 100."""
    effective = compute_effective_attempted(raw_attempted, actual_minutes)
    if effective <= 0:
        return None
    return min(100.0, actual_minutes / effective * 100)


def get_sessions_for_date(date_str):
    """Return the list of sessions for a date. Auto-converts a legacy
    'attempted' entry to a single untimed session for editing purposes."""
    data = load_data()
    entry = data.get(date_str, {})
    sessions = entry.get("sessions")
    if isinstance(sessions, list) and sessions:
        return list(sessions)
    legacy = entry.get("attempted", 0)
    if legacy > 0:
        return [{"minutes": float(legacy)}]
    return []


def write_sessions_for_date(date_str, sessions):
    """Persist a list of sessions for a date. Removes the day entry entirely
    if the list is empty. Always also writes the computed 'attempted' total
    so that legacy readers (and simpler exports) keep working.

    Also pings tracker listeners so any open statusbar widgets refresh
    their daily totals immediately."""
    data = load_data()
    if not sessions:
        if date_str in data:
            del data[date_str]
        save_data(data)
    else:
        total = sum(s.get("minutes", 0) for s in sessions if isinstance(s, dict))
        data[date_str] = {
            "sessions": sessions,
            "attempted": total,
        }
        save_data(data)
    # Notify any UI observers (statusbar) that daily totals may have changed.
    if _tracker_instance is not None:
        _tracker_instance._notify_listeners()


def compute_session_minutes(start_str, end_str):
    """Duration in minutes between two HH:MM strings. Wraps to next day
    if end is before start (i.e., session ran past midnight)."""
    try:
        sh, sm = map(int, start_str.split(":"))
        eh, em = map(int, end_str.split(":"))
    except (ValueError, AttributeError):
        return 0
    duration = (eh * 60 + em) - (sh * 60 + sm)
    if duration < 0:
        duration += 24 * 60
    return duration


def autofill_unaccounted_anki_time(date_str, before_dt):
    """If there's Anki review time on `date_str` from the day's start up to
    `before_dt` that isn't yet covered by logged sessions, append an
    untimed session for the gap and return its size (in minutes). Returns
    0 if no fill happened.

    Used at the start of a live session to make explicit any "I forgot to
    log earlier today" Anki time, so the user's effective attempted total
    is honest from the moment the live session begins."""
    day_start = anki_day_start(date_str)
    anki_before = get_study_minutes_in_window(day_start, before_dt)
    already_logged = sum(
        s.get("minutes", 0) for s in get_sessions_for_date(date_str)
    )
    gap = anki_before - already_logged
    # Only fill gaps of at least 30 seconds — anything smaller is rounding
    # noise and would create distractingly tiny sessions.
    if gap < 0.5:
        return 0
    sessions = get_sessions_for_date(date_str)
    # The auto flag tells the input dialog to render this row distinctly
    # and skip the click-to-edit affordance — auto-fills don't have a
    # clear semantic for editing, just delete-and-redo.
    sessions.append({"minutes": round(gap, 1), "auto": True})
    write_sessions_for_date(date_str, sessions)
    return gap


def projected_total_after_change(date_str, replaced_idx, new_session):
    """What the day's total logged minutes would be if `new_session` were
    added (replaced_idx=None) or replaced an existing one (replaced_idx=
    int). Includes the live session's elapsed minutes if it belongs to
    `date_str`. Used to drive the under-logging warning."""
    sessions = get_sessions_for_date(date_str)
    total = 0.0
    for i, s in enumerate(sessions):
        if i == replaced_idx:
            continue
        total += s.get("minutes", 0)
    total += new_session.get("minutes", 0)
    state = get_tracker().get_state()
    if state is not None and state["anki_date"] == date_str:
        total += state["elapsed_min"]
    return total


# ---------- Add / edit session dialog ----------

class AddSessionDialog(QDialog):
    """Sub-dialog for adding or editing a single session — either timed
    (start/end) or untimed (just a duration in minutes). Pass `initial=
    {minutes, ?start, ?end}` to pre-fill for editing."""

    def __init__(self, parent=None, initial=None):
        super().__init__(parent)
        self.setWindowTitle("Edit study session" if initial else "Add study session")
        self.resize(360, 240)

        layout = QVBoxLayout()
        layout.setContentsMargins(16, 16, 16, 16)
        layout.setSpacing(10)

        # Mode selector — wrap in a QButtonGroup so checking one always
        # unchecks the other. Without this, calling setChecked(True) on
        # one radio (e.g. when pre-filling for edit) doesn't reliably
        # uncheck its sibling and you end up with both visually selected.
        self.timed_radio = QRadioButton("Timed (from / to)")
        self.timed_radio.setChecked(True)
        self.bulk_radio = QRadioButton("Just minutes (no specific times)")
        self._mode_group = QButtonGroup(self)
        self._mode_group.addButton(self.timed_radio)
        self._mode_group.addButton(self.bulk_radio)
        layout.addWidget(self.timed_radio)
        layout.addWidget(self.bulk_radio)

        # Timed mode inputs
        self.timed_widget = QWidget()
        timed_form = QFormLayout(self.timed_widget)
        timed_form.setContentsMargins(20, 6, 0, 6)
        now = QTime.currentTime()
        self.start_edit = QTimeEdit(now.addSecs(-30 * 60))
        self.start_edit.setDisplayFormat("HH:mm")
        self.end_edit = QTimeEdit(now)
        self.end_edit.setDisplayFormat("HH:mm")
        self.duration_label = QLabel()
        self.duration_label.setStyleSheet("font-weight: bold;")
        timed_form.addRow("From:", self.start_edit)
        timed_form.addRow("To:", self.end_edit)
        timed_form.addRow("Duration:", self.duration_label)
        layout.addWidget(self.timed_widget)

        # Bulk mode input
        self.bulk_widget = QWidget()
        bulk_form = QFormLayout(self.bulk_widget)
        bulk_form.setContentsMargins(20, 6, 0, 6)
        self.bulk_spin = QSpinBox()
        self.bulk_spin.setRange(1, 1440)
        self.bulk_spin.setValue(30)
        self.bulk_spin.setSuffix(" min")
        self.bulk_spin.setSingleStep(5)
        bulk_form.addRow("Minutes:", self.bulk_spin)
        layout.addWidget(self.bulk_widget)
        self.bulk_widget.hide()

        # Apply initial values for edit mode.
        if initial is not None:
            if "start" in initial and "end" in initial:
                self.timed_radio.setChecked(True)
                try:
                    sh, sm = map(int, initial["start"].split(":"))
                    eh, em = map(int, initial["end"].split(":"))
                    self.start_edit.setTime(QTime(sh, sm))
                    self.end_edit.setTime(QTime(eh, em))
                except (ValueError, AttributeError):
                    pass
            else:
                self.bulk_radio.setChecked(True)
                m = initial.get("minutes", 30)
                try:
                    self.bulk_spin.setValue(int(m))
                except (TypeError, ValueError):
                    pass
            # Reflect the radio state in widget visibility.
            self._on_mode_changed()

        # Wire up reactivity
        self.timed_radio.toggled.connect(self._on_mode_changed)
        self.start_edit.timeChanged.connect(self._update_duration)
        self.end_edit.timeChanged.connect(self._update_duration)
        self._update_duration()

        # OK / Cancel
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        if initial is not None:
            buttons.button(QDialogButtonBox.StandardButton.Ok).setText("Save")
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

        self.setLayout(layout)

    def _on_mode_changed(self):
        if self.timed_radio.isChecked():
            self.timed_widget.show()
            self.bulk_widget.hide()
        else:
            self.timed_widget.hide()
            self.bulk_widget.show()

    def _update_duration(self):
        start = self.start_edit.time().toString("HH:mm")
        end = self.end_edit.time().toString("HH:mm")
        d = compute_session_minutes(start, end)
        self.duration_label.setText(f"{d} min" + (" (overnight)" if d > 0 and self.end_edit.time() < self.start_edit.time() else ""))

    def get_session(self):
        """Return a session dict for the current mode, or None if invalid."""
        if self.timed_radio.isChecked():
            start = self.start_edit.time().toString("HH:mm")
            end = self.end_edit.time().toString("HH:mm")
            duration = compute_session_minutes(start, end)
            if duration <= 0:
                return None
            return {"start": start, "end": end, "minutes": duration}
        else:
            minutes = self.bulk_spin.value()
            if minutes <= 0:
                return None
            return {"minutes": float(minutes)}


# ---------- Input dialog ----------

class _ClickableArea(QLabel):
    """A clickable rich-text label. Used for the session rows in the input
    dialog so the whole label area opens the edit dialog. We can't use a
    QPushButton because Qt's button rendering doesn't support rich text
    (no inline bold / colour). A QLabel does, but doesn't fire clicks by
    default — so we override mousePressEvent."""

    def __init__(self, text="", on_click=None, tooltip="", parent=None):
        super().__init__(text, parent)
        self._on_click = on_click
        self.setTextFormat(Qt.TextFormat.RichText)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        if tooltip:
            self.setToolTip(tooltip)
        # Slight padding + hover background so it visually behaves like a
        # button. Without this, "click anywhere on the label" feels lucky
        # rather than designed.
        self.setStyleSheet(
            "QLabel { padding: 6px 10px; border-radius: 4px; } "
            "QLabel:hover { background: rgba(128,128,128,0.18); }"
        )

    def mousePressEvent(self, ev):
        if ev.button() == Qt.MouseButton.LeftButton and self._on_click:
            self._on_click()
        super().mousePressEvent(ev)


class InputDialog(QDialog):
    """Main dialog: shows the day's sessions with add / edit / remove
    actions, plus a row for the live session if one is running. Changes
    are saved immediately (no separate Save button)."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Efficiency — log study time")
        self.resize(520, 500)

        # Throttle live refreshes the same way StatsDialog does — once per
        # displayed-minute is plenty for "8 min running" → "9 min running".
        self._last_live_int_min = None
        self._listener_fn = self._on_tracker_tick

        layout = QVBoxLayout()
        layout.setContentsMargins(16, 16, 16, 16)
        layout.setSpacing(12)

        # Date row — defaults to Anki's current day, honouring the rollover
        # hour. So at 02:30 with rollover=4 the dialog opens on yesterday's
        # calendar date (which is still "today" from Anki's perspective).
        date_row = QHBoxLayout()
        date_row.addWidget(QLabel("Date:"))
        anki_today = qdate_for_anki_today()
        self.date_edit = QDateEdit(anki_today)
        self.date_edit.setCalendarPopup(True)
        self.date_edit.setDisplayFormat("yyyy-MM-dd")
        self.date_edit.setMaximumDate(anki_today)
        self.date_edit.dateChanged.connect(self.refresh)
        date_row.addWidget(self.date_edit)
        date_row.addStretch()
        layout.addLayout(date_row)

        # Stats summary
        self.stats_label = QLabel()
        self.stats_label.setWordWrap(True)
        self.stats_label.setStyleSheet(
            "padding: 10px 12px; background: rgba(128,128,128,0.10); "
            "border-radius: 6px;"
        )
        layout.addWidget(self.stats_label)

        # Sessions header
        header = QHBoxLayout()
        header.addWidget(QLabel("<b>Sessions</b>"))
        header.addStretch()
        btn_add = QPushButton("➕ Add session")
        btn_add.clicked.connect(self.on_add_session)
        header.addWidget(btn_add)
        layout.addLayout(header)

        # Scrollable sessions list
        self.sessions_container = QWidget()
        self.sessions_layout = QVBoxLayout(self.sessions_container)
        self.sessions_layout.setContentsMargins(4, 4, 4, 4)
        self.sessions_layout.setSpacing(4)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setWidget(self.sessions_container)
        scroll.setMinimumHeight(200)
        scroll.setStyleSheet(
            "QScrollArea { border: 1px solid rgba(128,128,128,0.25); "
            "border-radius: 6px; }"
        )
        layout.addWidget(scroll)

        # Close button
        close_row = QHBoxLayout()
        close_row.addStretch()
        btn_close = QPushButton("Close")
        btn_close.clicked.connect(self.accept)
        close_row.addWidget(btn_close)
        layout.addLayout(close_row)

        self.setLayout(layout)
        self.refresh()

        get_tracker().add_listener(self._listener_fn)

    def closeEvent(self, ev):
        get_tracker().remove_listener(self._listener_fn)
        super().closeEvent(ev)

    def _on_tracker_tick(self):
        state = get_tracker().get_state()
        cur = int(state["elapsed_min"]) if state else None
        if cur != self._last_live_int_min:
            self._last_live_int_min = cur
            self.refresh()

    def current_date_str(self):
        return self.date_edit.date().toString("yyyy-MM-dd")

    def refresh(self):
        # Clear sessions list
        while self.sessions_layout.count():
            item = self.sessions_layout.takeAt(0)
            w = item.widget()
            if w is not None:
                w.deleteLater()

        date_str = self.current_date_str()
        sessions = get_sessions_for_date(date_str)

        # If a live session is running on the same Anki-day as we're viewing,
        # show it at the top of the list — distinct visual treatment, with
        # its own click-to-edit-start-time and ⏹ stop-and-save buttons.
        state = get_tracker().get_state()
        live_here = state is not None and state["anki_date"] == date_str
        if live_here:
            self.sessions_layout.addWidget(self._make_live_session_row(state))

        if not sessions and not live_here:
            empty = QLabel("No sessions logged yet for this day.\nClick ‘Add session’ above to log one.")
            empty.setAlignment(Qt.AlignmentFlag.AlignCenter)
            empty.setStyleSheet("color: rgba(128,128,128,0.85); padding: 30px; font-style: italic;")
            self.sessions_layout.addWidget(empty)
        else:
            for i, s in enumerate(sessions):
                self.sessions_layout.addWidget(self._make_session_row(s, i))
        self.sessions_layout.addStretch()

        self._update_stats()

    def _make_session_row(self, session, idx):
        wrap = QWidget()
        row = QHBoxLayout(wrap)
        row.setContentsMargins(2, 2, 2, 2)
        row.setSpacing(6)

        is_auto = session.get("auto") is True
        minutes = session.get("minutes", 0)

        if is_auto:
            # Auto-filled by the addon when starting a live session, to
            # cover Anki time done before tracking began. Visually
            # distinct (amber accent), and only deletable — there's no
            # clean semantic for editing a "we found these minutes for
            # you" entry; if it's wrong, just remove it.
            wrap.setStyleSheet(
                "background: rgba(232, 149, 69, 0.10); "
                "border: 1px solid rgba(232, 149, 69, 0.40); "
                "border-radius: 4px;"
            )
            text = (
                f'<span style="color:#e89545; font-weight:bold;">AUTO</span>'
                f' &nbsp; <span style="color:#8a8d99">earlier Anki activity</span>'
                f'  ·  {minutes:.0f} min'
            )
            label = QLabel(text)
            label.setTextFormat(Qt.TextFormat.RichText)
            label.setStyleSheet("QLabel { padding: 6px 10px; }")
            label.setToolTip(
                "Auto-logged when you started a live session, to cover Anki "
                "time done before tracking began. Editing isn't supported "
                "— remove and re-add if needed."
            )
            row.addWidget(label, 1)
        else:
            if "start" in session and "end" in session:
                text = f"<b>{session['start']}</b> → <b>{session['end']}</b>  ·  {minutes:.0f} min"
            else:
                text = f"<i>Untimed</i>  ·  {minutes:.0f} min"
            # The label is itself a clickable area so the whole row opens
            # the edit dialog — easier to hit than a tiny pencil icon.
            edit_btn = _ClickableArea(
                text=text,
                on_click=lambda i=idx: self.on_edit_session(i),
                tooltip="Click to edit this session",
            )
            row.addWidget(edit_btn, 1)

        remove_btn = QPushButton("✕")
        remove_btn.setFixedWidth(32)
        remove_btn.setToolTip("Remove this session")
        remove_btn.clicked.connect(lambda _=False, i=idx: self.on_remove_session(i))
        row.addWidget(remove_btn)

        # Zebra-striping for non-auto rows only — the auto styling already
        # provides its own distinct background.
        if not is_auto and idx % 2 == 0:
            wrap.setStyleSheet("background: rgba(128,128,128,0.06); border-radius: 4px;")
        return wrap

    def _make_live_session_row(self, state):
        wrap = QWidget()
        wrap.setStyleSheet(
            "background: rgba(107, 164, 255, 0.12); "
            "border: 1px solid rgba(107, 164, 255, 0.45); "
            "border-radius: 4px;"
        )
        row = QHBoxLayout(wrap)
        row.setContentsMargins(2, 2, 2, 2)
        row.setSpacing(6)

        elapsed = state["elapsed_min"]
        started = state["started"].strftime("%H:%M")
        text = (
            f'<span style="color:#6ba4ff; font-weight:bold;">● LIVE</span>'
            f' &nbsp; <b>{started}</b> → <i>now</i>  ·  {elapsed:.0f} min'
        )

        edit_btn = _ClickableArea(
            text=text,
            on_click=self.on_edit_live_session,
            tooltip="Click to adjust the start time of this running session",
        )
        row.addWidget(edit_btn, 1)

        stop_btn = QPushButton("⏹")
        stop_btn.setFixedWidth(32)
        stop_btn.setToolTip("Stop this session and save it")
        stop_btn.clicked.connect(self.on_stop_live_session)
        row.addWidget(stop_btn)

        return wrap

    def _update_stats(self):
        date_str = self.current_date_str()
        raw = sum(s.get("minutes", 0) for s in get_sessions_for_date(date_str))
        # Add the running session's elapsed time if it belongs to this day.
        state = get_tracker().get_state()
        if state is not None and state["anki_date"] == date_str:
            raw += state["elapsed_min"]
        actual = get_study_minutes_for_date(date_str)
        effective = compute_effective_attempted(raw, actual)
        eff = compute_efficiency_percent(raw, actual)

        msg = (
            f"Total attempted: <b>{effective:.0f} min</b>"
            f" &nbsp;·&nbsp; Active in Anki: <b>{actual:.1f} min</b>"
        )
        if eff is not None:
            msg += f" &nbsp;·&nbsp; Efficiency: <b>{eff:.1f}%</b>"
        self.stats_label.setText(msg)

    def on_add_session(self):
        dialog = AddSessionDialog(self)
        if dialog.exec():
            session = dialog.get_session()
            if session is None:
                showInfo("Session duration must be greater than zero.")
                return
            date_str = self.current_date_str()
            if not self._confirm_no_underlogging(date_str, None, session):
                return
            sessions = get_sessions_for_date(date_str)
            sessions.append(session)
            write_sessions_for_date(date_str, sessions)
            self.refresh()

    def _confirm_no_underlogging(self, date_str, replaced_idx, new_session):
        """If the day's projected total (after this add/edit) would still
        be less than the actual Anki time, ask the user to confirm. Returns
        False if the user cancels, True otherwise (including 'no warning
        needed')."""
        projected = projected_total_after_change(date_str, replaced_idx, new_session)
        actual = get_study_minutes_for_date(date_str)
        # Allow a small tolerance for float rounding — 0.5 min is below the
        # display granularity anyway.
        if projected + 0.5 >= actual:
            return True
        gap = actual - projected
        return askUser(
            f"Anki shows <b>{actual:.0f} min</b> studied today, but with this "
            f"change your logged sessions would total only <b>{projected:.0f} min</b> — "
            f"<b>{gap:.0f} min</b> would still be unaccounted for.<br><br>"
            f"Save this session anyway?",
            parent=self,
            title="Under-logged day",
        )

    def on_edit_session(self, idx):
        date_str = self.current_date_str()
        sessions = get_sessions_for_date(date_str)
        if not (0 <= idx < len(sessions)):
            return
        if sessions[idx].get("auto") is True:
            # Should not happen via normal UI (auto rows aren't clickable),
            # but guard anyway in case of programmatic invocation.
            return
        dialog = AddSessionDialog(self, initial=sessions[idx])
        if dialog.exec():
            new_session = dialog.get_session()
            if new_session is None:
                showInfo("Session duration must be greater than zero.")
                return
            if not self._confirm_no_underlogging(date_str, idx, new_session):
                return
            sessions[idx] = new_session
            write_sessions_for_date(date_str, sessions)
            self.refresh()

    def on_remove_session(self, idx):
        date_str = self.current_date_str()
        sessions = get_sessions_for_date(date_str)
        if 0 <= idx < len(sessions):
            del sessions[idx]
            write_sessions_for_date(date_str, sessions)
            self.refresh()

    def on_edit_live_session(self):
        """Adjust the start time of a running session in place."""
        state = get_tracker().get_state()
        if state is None:
            return
        started = state["started"]
        initial = QTime(started.hour, started.minute)
        dialog = StartSessionDialog(self, initial_time=initial, edit_mode=True)
        if dialog.exec():
            new_start = dialog.get_start_datetime()
            sess = load_active_session()
            if sess is None:
                return
            sess["started_at"] = new_start.isoformat(timespec="seconds")
            # Anki-date may shift if the user back-dates across the rollover.
            sess["anki_date"] = anki_date_for(new_start)
            save_active_session(sess)
            get_tracker()._notify_listeners()
            self.refresh()

    def on_stop_live_session(self):
        get_tracker().stop()
        self.refresh()


def show_input_dialog():
    dialog = InputDialog(mw)
    dialog.exec()


# ---------- Export / import ----------

def _extract_data_dict(payload):
    """Accept either {version, data: {...}} or a raw {date: {attempted: n}} dict."""
    if isinstance(payload, dict) and "data" in payload and "version" in payload:
        return payload["data"]
    if isinstance(payload, dict):
        return payload
    return None


def _filter_valid_entries(raw):
    """Keep only entries that look like a valid date → data mapping. Accepts
    both legacy `{"attempted": N}` and new `{"sessions": [...]}` formats."""
    valid = {}
    if not isinstance(raw, dict):
        return valid
    for k, v in raw.items():
        if not isinstance(k, str):
            continue
        try:
            datetime.strptime(k, "%Y-%m-%d")
        except ValueError:
            continue
        if not isinstance(v, dict):
            continue

        # New format: validate and clean each session.
        raw_sessions = v.get("sessions")
        if isinstance(raw_sessions, list) and raw_sessions:
            clean_sessions = []
            for s in raw_sessions:
                if not isinstance(s, dict):
                    continue
                m = s.get("minutes")
                # If minutes missing but start/end present, derive it.
                if not isinstance(m, (int, float)) and isinstance(s.get("start"), str) and isinstance(s.get("end"), str):
                    m = compute_session_minutes(s["start"], s["end"])
                if not isinstance(m, (int, float)) or m <= 0:
                    continue
                clean = {"minutes": float(m)}
                if isinstance(s.get("start"), str) and isinstance(s.get("end"), str):
                    clean["start"] = s["start"]
                    clean["end"] = s["end"]
                if s.get("auto") is True:
                    clean["auto"] = True
                clean_sessions.append(clean)
            if clean_sessions:
                valid[k] = {
                    "sessions": clean_sessions,
                    "attempted": sum(s["minutes"] for s in clean_sessions),
                }
                continue

        # Legacy fallback: plain attempted minutes.
        att = v.get("attempted")
        if isinstance(att, (int, float)) and att >= 0:
            valid[k] = {"attempted": float(att)}
    return valid


def show_export_dialog():
    default_name = f"efficiency_tracker_export_{datetime.now().strftime('%Y%m%d')}.json"
    path, _ = QFileDialog.getSaveFileName(
        mw, "Export efficiency data", default_name, "JSON files (*.json)"
    )
    if not path:
        return
    if not path.lower().endswith(".json"):
        path += ".json"

    data = load_data()
    payload = {
        "version": 1,
        "addon": "efficiency_tracker",
        "exported_at": datetime.now().isoformat(timespec="seconds"),
        "data": data,
    }
    try:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2, ensure_ascii=False)
    except IOError as e:
        showInfo(f"Could not write export file:\n{e}")
        return

    tooltip(f"Exported {len(data)} entries to {os.path.basename(path)}")


def show_import_dialog():
    path, _ = QFileDialog.getOpenFileName(
        mw, "Import efficiency data", "", "JSON files (*.json);;All files (*.*)"
    )
    if not path:
        return

    try:
        with open(path, "r", encoding="utf-8") as f:
            payload = json.load(f)
    except (IOError, json.JSONDecodeError) as e:
        showInfo(f"Could not read file:\n{e}")
        return

    raw = _extract_data_dict(payload)
    if raw is None:
        showInfo("File format not recognised — expected a JSON object.")
        return

    incoming = _filter_valid_entries(raw)
    if not incoming:
        showInfo("File contained no valid entries.")
        return

    existing = load_data()
    overlap = sum(1 for k in incoming if k in existing)
    new_count = len(incoming) - overlap

    msg = (
        f"Found {len(incoming)} valid entries in the import file.\n\n"
        f"  • {new_count} new\n"
        f"  • {overlap} will overwrite existing entries\n\n"
        f"Imported values win on conflicts. Continue?"
    )
    if not askUser(msg, parent=mw, title="Import efficiency data"):
        return

    merged = dict(existing)
    merged.update(incoming)
    save_data(merged)
    if _tracker_instance is not None:
        _tracker_instance._notify_listeners()

    tooltip(f"Imported {len(incoming)} entries ({new_count} new, {overlap} updated)")


# ---------- Stats dialog ----------

def _eff_class(eff, good_threshold, warn_threshold):
    if eff is None:
        return "muted"
    if eff >= good_threshold:
        return "good"
    if eff >= warn_threshold:
        return "warn"
    return "bad"


def _eff_str(eff):
    return f"{eff:.0f}%" if eff is not None else "—"


def build_stats_html():
    config = get_config()
    theme = config.get("theme", "auto")
    good_threshold = config.get("good_threshold", 70)
    warn_threshold = config.get("warn_threshold", 45)
    num_days = config.get("range_days", 30)

    data = load_data()
    # Anchor the window to Anki's "today" — at 02:30 with rollover=4, the
    # last bar should still be yesterday's calendar date, matching what
    # Anki's own statistics would show.
    today_str = today_anki_date()
    today_dt = datetime.strptime(today_str, "%Y-%m-%d")

    # If a live session is running, fold its elapsed time into the matching
    # day's attempted total so the dashboard ticks up live too.
    live_state = get_tracker().get_state()
    live_anki_date = live_state["anki_date"] if live_state else None
    live_elapsed = live_state["elapsed_min"] if live_state else 0

    days = []
    for i in range(num_days - 1, -1, -1):
        d = today_dt - timedelta(days=i)
        date_str = d.strftime("%Y-%m-%d")
        raw_attempted = compute_attempted_minutes(data.get(date_str, {}))
        if date_str == live_anki_date:
            raw_attempted += live_elapsed
        actual = get_study_minutes_for_date(date_str)
        # Display the effective (capped-at-actual) attempted; efficiency
        # follows the same rule and is therefore always between 0 and 100%.
        attempted = compute_effective_attempted(raw_attempted, actual)
        eff = compute_efficiency_percent(raw_attempted, actual)
        days.append({
            "date": date_str,
            "label": d.strftime("%d/%m"),
            "weekday": d.strftime("%a"),
            "attempted": round(attempted, 1),
            "actual": round(actual, 1),
            "efficiency": round(eff, 1) if eff is not None else None,
        })

    today = days[-1]
    valid = [d for d in days if d["efficiency"] is not None]
    avg_30 = sum(d["efficiency"] for d in valid) / len(valid) if valid else None
    last_7 = [d for d in days[-7:] if d["efficiency"] is not None]
    avg_7 = sum(d["efficiency"] for d in last_7) / len(last_7) if last_7 else None

    # SVG dimensions
    chart_w = 880
    chart_h = 280
    pad_l, pad_r, pad_t, pad_b = 50, 20, 20, 40
    inner_w = chart_w - pad_l - pad_r
    inner_h = chart_h - pad_t - pad_b

    # Bar chart data
    max_minutes = max(
        [d["attempted"] for d in days] + [d["actual"] for d in days] + [10]
    )

    def nice_max(v):
        if v <= 30: return 30
        if v <= 60: return 60
        if v <= 120: return 120
        if v <= 240: return 240
        if v <= 480: return 480
        return ((int(v) // 60) + 1) * 60
    y_max = nice_max(max_minutes)

    n = len(days)
    group_w = inner_w / n
    # For large ranges, narrow bars and reduce inter-bar gap so bars stay
    # visible without overlapping the next group.
    if n > 90:
        bar_w = group_w * 0.45
        bar_gap = 0.2
    elif n > 30:
        bar_w = group_w * 0.42
        bar_gap = 0.5
    else:
        bar_w = group_w * 0.38
        bar_gap = 1

    # Generate bars
    bars_svg = []
    x_labels = []
    for i, d in enumerate(days):
        gx = pad_l + i * group_w + group_w / 2
        ah = (d["attempted"] / y_max) * inner_h if y_max > 0 else 0
        ay = pad_t + inner_h - ah
        rh = (d["actual"] / y_max) * inner_h if y_max > 0 else 0
        ry = pad_t + inner_h - rh
        bars_svg.append(
            f'<rect x="{gx - bar_w - bar_gap:.2f}" y="{ay:.1f}" width="{bar_w:.2f}" height="{ah:.1f}" '
            f'fill="var(--warn)" rx="2"><title>{d["date"]}: {d["attempted"]} min attempted</title></rect>'
        )
        bars_svg.append(
            f'<rect x="{gx + bar_gap:.2f}" y="{ry:.1f}" width="{bar_w:.2f}" height="{rh:.1f}" '
            f'fill="var(--accent)" rx="2"><title>{d["date"]}: {d["actual"]} min active</title></rect>'
        )
        if i % max(1, n // 10) == 0 or i == n - 1:
            x_labels.append(
                f'<text x="{gx:.1f}" y="{chart_h - 22:.0f}" text-anchor="middle" class="axis-label">{d["label"]}</text>'
            )

    # Y-axis ticks for bar chart
    y_ticks = []
    y_grid = []
    n_ticks = 4
    for k in range(n_ticks + 1):
        v = y_max * k / n_ticks
        y = pad_t + inner_h - (v / y_max) * inner_h
        y_ticks.append(
            f'<text x="{pad_l - 8:.0f}" y="{y + 4:.1f}" text-anchor="end" class="axis-label">{v:.0f}</text>'
        )
        y_grid.append(
            f'<line x1="{pad_l}" y1="{y:.1f}" x2="{pad_l + inner_w}" y2="{y:.1f}" class="grid"/>'
        )

    # Line chart for efficiency
    eff_chart_h = 240
    eff_inner_h = eff_chart_h - pad_t - pad_b
    eff_y_max = 100  # Efficiency is capped at 100% by definition now.

    dots = []
    for i, d in enumerate(days):
        if d["efficiency"] is None:
            continue
        gx = pad_l + i * group_w + group_w / 2
        gy = pad_t + eff_inner_h - (d["efficiency"] / eff_y_max) * eff_inner_h
        eff = d["efficiency"]
        color = "#6dd97a" if eff >= good_threshold else ("#f5a557" if eff >= warn_threshold else "#ec6666")
        dots.append(
            f'<circle cx="{gx:.1f}" cy="{gy:.1f}" r="4" fill="{color}" stroke="var(--card)" stroke-width="2">'
            f'<title>{d["date"]}: {d["efficiency"]:.1f}%</title></circle>'
        )

    # Build line segments — only connect consecutive valid days
    segments = []
    current_seg = []
    for i, d in enumerate(days):
        if d["efficiency"] is None:
            if len(current_seg) > 1:
                segments.append(" ".join(f"{x:.1f},{y:.1f}" for x, y in current_seg))
            current_seg = []
        else:
            gx = pad_l + i * group_w + group_w / 2
            gy = pad_t + eff_inner_h - (d["efficiency"] / eff_y_max) * eff_inner_h
            current_seg.append((gx, gy))
    if len(current_seg) > 1:
        segments.append(" ".join(f"{x:.1f},{y:.1f}" for x, y in current_seg))
    polylines = "\n".join(
        f'<polyline points="{seg}" fill="none" stroke="var(--good)" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"/>'
        for seg in segments
    )

    # Eff y-ticks
    eff_y_ticks = []
    eff_y_grid = []
    for k in range(5):
        v = eff_y_max * k / 4
        y = pad_t + eff_inner_h - (v / eff_y_max) * eff_inner_h
        eff_y_ticks.append(
            f'<text x="{pad_l - 8:.0f}" y="{y + 4:.1f}" text-anchor="end" class="axis-label">{v:.0f}%</text>'
        )
        eff_y_grid.append(
            f'<line x1="{pad_l}" y1="{y:.1f}" x2="{pad_l + inner_w}" y2="{y:.1f}" class="grid"/>'
        )
    y_100 = pad_t + eff_inner_h - (100 / eff_y_max) * eff_inner_h
    ref_line = (
        f'<line x1="{pad_l}" y1="{y_100:.1f}" x2="{pad_l + inner_w}" y2="{y_100:.1f}" '
        f'stroke="var(--muted)" stroke-width="1" stroke-dasharray="3,3" opacity="0.6"/>'
    )

    eff_x_labels = []
    for i, d in enumerate(days):
        if i % max(1, n // 10) == 0 or i == n - 1:
            gx = pad_l + i * group_w + group_w / 2
            eff_x_labels.append(
                f'<text x="{gx:.1f}" y="{eff_chart_h - 22:.0f}" text-anchor="middle" class="axis-label">{d["label"]}</text>'
            )

    # History table — show recent entries, capped so the table stays readable
    history_count = min(num_days, 30) if num_days >= 14 else num_days
    history_rows = []
    for d in reversed(days[-history_count:]):
        eff_text = _eff_str(d["efficiency"])
        eff_cls = _eff_class(d["efficiency"], good_threshold, warn_threshold)
        history_rows.append(f"""
            <tr>
                <td>{d['date']} <span class="muted">({d['weekday']})</span></td>
                <td>{d['attempted']:.0f} min</td>
                <td>{d['actual']:.1f} min</td>
                <td class="{eff_cls}"><b>{eff_text}</b></td>
            </tr>
        """)

    # Theme variables (resolved server-side so we don't depend on the
    # webview's prefers-color-scheme behaviour).
    dark_vars = """
  --bg: #1e1f26;
  --card: #2a2b34;
  --text: #e8e9ed;
  --muted: #8a8d99;
  --accent: #6ba4ff;
  --good: #6dd97a;
  --warn: #f5a557;
  --bad: #ec6666;
  --grid: rgba(255,255,255,0.08);
  --border: rgba(255,255,255,0.08);
"""
    light_vars = """
  --bg: #f5f6f8;
  --card: #ffffff;
  --text: #1a1a1a;
  --muted: #6b7280;
  --accent: #6ba4ff;
  --good: #5cb86a;
  --warn: #e89545;
  --bad: #d65555;
  --grid: rgba(0,0,0,0.06);
  --border: rgba(0,0,0,0.06);
"""

    if theme == "dark":
        theme_css = f":root {{{dark_vars}}}"
    elif theme == "light":
        theme_css = f":root {{{light_vars}}}"
    else:  # auto
        theme_css = (
            f":root {{{dark_vars}}}"
            f"@media (prefers-color-scheme: light) {{ :root {{{light_vars}}} }}"
        )

    # Build legend strings dynamically from configured thresholds.
    legend_good = f"≥ {good_threshold:.0f}%"
    legend_warn = f"{warn_threshold:.0f}–{good_threshold - 1:.0f}%"
    legend_bad = f"&lt; {warn_threshold:.0f}%"

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<style>
{theme_css}
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
body {{
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
  background: var(--bg);
  color: var(--text);
  padding: 24px;
  line-height: 1.5;
  font-size: 14px;
}}
h1 {{ font-size: 22px; font-weight: 700; margin-bottom: 4px; }}
.subtitle {{ color: var(--muted); margin-bottom: 20px; font-size: 13px; }}
.stats {{
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: 12px;
  margin-bottom: 20px;
}}
.stat-card {{
  background: var(--card);
  padding: 14px 16px;
  border-radius: 10px;
  border: 1px solid var(--border);
}}
.stat-label {{
  color: var(--muted);
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 4px;
  font-weight: 600;
}}
.stat-value {{ font-size: 26px; font-weight: 700; }}
.stat-value .unit {{ font-size: 13px; color: var(--muted); font-weight: 500; }}
.good {{ color: var(--good); }}
.warn {{ color: var(--warn); }}
.bad {{ color: var(--bad); }}
.muted {{ color: var(--muted); }}
.chart-card {{
  background: var(--card);
  padding: 18px;
  border-radius: 10px;
  margin-bottom: 16px;
  border: 1px solid var(--border);
}}
.chart-header {{
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
  flex-wrap: wrap;
  gap: 8px;
}}
.chart-title {{ font-size: 15px; font-weight: 600; }}
.legend {{ display: flex; gap: 14px; font-size: 12px; color: var(--muted); }}
.legend-item {{ display: flex; align-items: center; gap: 6px; }}
.legend-swatch {{ width: 10px; height: 10px; border-radius: 2px; }}
svg {{ width: 100%; height: auto; display: block; }}
.axis-label {{ fill: var(--muted); font-size: 11px; }}
.grid {{ stroke: var(--grid); stroke-width: 1; }}
table {{ width: 100%; border-collapse: collapse; font-size: 13px; }}
th, td {{ padding: 8px 10px; text-align: left; border-bottom: 1px solid var(--border); }}
th {{ color: var(--muted); font-weight: 600; font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px; }}
tr:last-child td {{ border-bottom: none; }}
</style>
</head>
<body>
<h1>📊 Efficiency Tracker</h1>
<p class="subtitle">Actual study time in Anki vs. time attempted to study — last {num_days} days</p>

<div class="stats">
  <div class="stat-card">
    <div class="stat-label">Today</div>
    <div class="stat-value {_eff_class(today['efficiency'], good_threshold, warn_threshold)}">{_eff_str(today['efficiency'])}</div>
  </div>
  <div class="stat-card">
    <div class="stat-label">7-day average</div>
    <div class="stat-value {_eff_class(avg_7, good_threshold, warn_threshold)}">{_eff_str(avg_7)}</div>
  </div>
  <div class="stat-card">
    <div class="stat-label">30-day average</div>
    <div class="stat-value {_eff_class(avg_30, good_threshold, warn_threshold)}">{_eff_str(avg_30)}</div>
  </div>
  <div class="stat-card">
    <div class="stat-label">Active today</div>
    <div class="stat-value">{today['actual']:.0f}<span class="unit"> min</span></div>
  </div>
  <div class="stat-card">
    <div class="stat-label">Attempted today</div>
    <div class="stat-value">{today['attempted']:.0f}<span class="unit"> min</span></div>
  </div>
</div>

<div class="chart-card">
  <div class="chart-header">
    <div class="chart-title">Study time per day</div>
    <div class="legend">
      <div class="legend-item"><div class="legend-swatch" style="background:var(--warn)"></div>Attempted</div>
      <div class="legend-item"><div class="legend-swatch" style="background:var(--accent)"></div>Active in Anki</div>
    </div>
  </div>
  <svg viewBox="0 0 {chart_w} {chart_h}" preserveAspectRatio="xMidYMid meet">
    {''.join(y_grid)}
    {''.join(bars_svg)}
    {''.join(y_ticks)}
    {''.join(x_labels)}
  </svg>
</div>

<div class="chart-card">
  <div class="chart-header">
    <div class="chart-title">Efficiency per day</div>
    <div class="legend">
      <div class="legend-item"><div class="legend-swatch" style="background:var(--good)"></div>{legend_good}</div>
      <div class="legend-item"><div class="legend-swatch" style="background:var(--warn)"></div>{legend_warn}</div>
      <div class="legend-item"><div class="legend-swatch" style="background:var(--bad)"></div>{legend_bad}</div>
    </div>
  </div>
  <svg viewBox="0 0 {chart_w} {eff_chart_h}" preserveAspectRatio="xMidYMid meet">
    {''.join(eff_y_grid)}
    {ref_line}
    {polylines}
    {''.join(dots)}
    {''.join(eff_y_ticks)}
    {''.join(eff_x_labels)}
  </svg>
</div>

<div class="chart-card">
  <div class="chart-title" style="margin-bottom: 10px;">Recent history ({history_count} days)</div>
  <table>
    <thead>
      <tr>
        <th>Date</th>
        <th>Attempted</th>
        <th>Active</th>
        <th>Efficiency</th>
      </tr>
    </thead>
    <tbody>
      {''.join(history_rows)}
    </tbody>
  </table>
</div>
</body>
</html>"""


class StatsDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Efficiency Tracker — Statistics")
        self.resize(960, 760)

        # Throttle live refreshes to once per displayed-minute. The tracker
        # fires the listener every second, but rebuilding HTML that often
        # would cause the webview to flicker. We re-render on every state
        # edge (start/stop, dialog edits) plus once per minute while a
        # session is running.
        self._last_live_int_min = None
        self._listener_fn = self._on_tracker_tick

        layout = QVBoxLayout()
        layout.setContentsMargins(0, 0, 0, 0)

        self.web = QWebEngineView(self)
        self.web.setMinimumHeight(600)
        self.web.setHtml(build_stats_html())
        layout.addWidget(self.web)

        btn_row = QHBoxLayout()
        btn_row.setContentsMargins(12, 8, 12, 12)

        btn_input = QPushButton("➕ Enter study time")
        btn_input.clicked.connect(self.open_input)
        btn_row.addWidget(btn_input)

        btn_refresh = QPushButton("🔄 Refresh")
        btn_refresh.clicked.connect(self.refresh)
        btn_row.addWidget(btn_refresh)

        # Range selector — switches the time window for the dashboard.
        btn_row.addSpacing(8)
        btn_row.addWidget(QLabel("Range:"))
        self.range_combo = QComboBox()
        for days, label in RANGE_OPTIONS:
            self.range_combo.addItem(label, days)
        current_days = get_config().get("range_days", 30)
        for i in range(self.range_combo.count()):
            if self.range_combo.itemData(i) == current_days:
                self.range_combo.setCurrentIndex(i)
                break
        self.range_combo.currentIndexChanged.connect(self.on_range_changed)
        btn_row.addWidget(self.range_combo)

        btn_row.addStretch()

        # Theme toggle — cycles auto → light → dark and persists to config.
        self.btn_theme = QPushButton()
        self.btn_theme.setToolTip("Cycle the dashboard theme (auto / light / dark)")
        self.btn_theme.clicked.connect(self.cycle_theme)
        self._refresh_theme_label()
        btn_row.addWidget(self.btn_theme)

        btn_close = QPushButton("Close")
        btn_close.clicked.connect(self.accept)
        btn_row.addWidget(btn_close)

        layout.addLayout(btn_row)
        self.setLayout(layout)

        get_tracker().add_listener(self._listener_fn)

    def closeEvent(self, ev):
        get_tracker().remove_listener(self._listener_fn)
        super().closeEvent(ev)

    def _on_tracker_tick(self):
        state = get_tracker().get_state()
        cur = int(state["elapsed_min"]) if state else None
        if cur != self._last_live_int_min:
            self._last_live_int_min = cur
            self.refresh()

    def _refresh_theme_label(self):
        cur = get_config().get("theme", "auto")
        self.btn_theme.setText(THEME_LABELS.get(cur, THEME_LABELS["auto"]))

    def cycle_theme(self):
        cfg = get_config()
        cur = cfg.get("theme", "auto")
        try:
            nxt = THEME_CYCLE[(THEME_CYCLE.index(cur) + 1) % len(THEME_CYCLE)]
        except ValueError:
            nxt = "auto"
        cfg["theme"] = nxt
        save_config(cfg)
        self._refresh_theme_label()
        self.refresh()

    def on_range_changed(self, idx):
        new_days = self.range_combo.itemData(idx)
        if new_days is None:
            return
        cfg = get_config()
        cfg["range_days"] = new_days
        save_config(cfg)
        self.refresh()

    def refresh(self):
        self.web.setHtml(build_stats_html())

    def open_input(self):
        dialog = InputDialog(self)
        if dialog.exec():
            self.refresh()


def _open_stats_dialog():
    dialog = StatsDialog(mw)
    dialog.exec()


def show_stats():
    # Defer the dialog opening by one event-loop tick. This is essential
    # when invoked from the top toolbar: the toolbar link click runs inside
    # a webview bridge callback, and opening a modal dialog with another
    # webview from within that nested context causes QtWebEngine to fail
    # to render the page (the dialog appears blank/transparent). Deferring
    # ensures the bridge callback returns first, then the dialog opens in
    # a clean event-loop state.
    QTimer.singleShot(0, _open_stats_dialog)


# ---------- Top toolbar button ----------

def _add_toolbar_link(links, toolbar):
    """Insert an "Efficiency" link in the top toolbar, right after Stats."""
    if not get_config().get("show_toolbar_button", True):
        return

    link = toolbar.create_link(
        cmd="efficiency_tracker",
        label="Efficiency",
        func=show_stats,
        tip="Open Efficiency Tracker statistics",
        id="efficiency-tracker",
    )

    # Anki's default order is decks, add, browse, stats, sync. We want our
    # link directly after stats — that's index 4. If the toolbar layout
    # ever changes, we fall back to appending.
    insert_at = None
    for i, raw in enumerate(links):
        if 'id="qt-link-stats"' in raw or "qt-link-stats" in raw:
            insert_at = i + 1
            break
    if insert_at is None:
        insert_at = min(4, len(links))
    links.insert(insert_at, link)


gui_hooks.top_toolbar_did_init_links.append(_add_toolbar_link)


# ---------- Statusbar widget for the live session ----------
#
# Two pieces, both pinned to Anki's bottom-right statusbar:
#  1. A small Start/Stop button — always visible.
#  2. A label with live session stats — only visible while a session is
#     running. Shows elapsed time / Anki minutes so far / efficiency
#     percentage (the same look from before this iteration).

_statusbar_button = None
_statusbar_label = None
_start_action_ref = None  # menu action whose label switches Start ↔ Stop


def _eff_colour(eff):
    if eff is None:
        return "#8a8d99"
    cfg = get_config()
    if eff >= cfg.get("good_threshold", 70):
        return "#5cb86a"
    if eff >= cfg.get("warn_threshold", 45):
        return "#e89545"
    return "#d65555"


def _format_elapsed(minutes):
    if minutes >= 60:
        h = int(minutes // 60)
        m = int(minutes % 60)
        return f"{h}h{m:02d}"
    return f"{int(minutes)}:{int((minutes - int(minutes)) * 60):02d}"


def _refresh_statusbar():
    """Pull state from the tracker and redraw both widgets.

    The label always shows the day's totals: total attempted minutes,
    total Anki review minutes, and efficiency. While a live session is
    running, its elapsed time is added on top of the saved sessions so
    the numbers tick up live as you study.
    """
    global _statusbar_button, _statusbar_label, _start_action_ref
    if _statusbar_button is None or _statusbar_label is None:
        return

    state = get_tracker().get_state()
    running = state is not None

    # --- Button: always visible, compact, label flips on state ---
    _statusbar_button.setText("⏹" if running else "▶")
    _statusbar_button.setToolTip(
        "Stop the live session and save it"
        if running else "Start a live session"
    )

    # --- Day totals ---
    # Anchor on the Anki-date the session started in if running, otherwise
    # today. This keeps a session that crosses the rollover boundary
    # (e.g. 23:30 → 00:30 with rollover=4) contributing to the same day
    # the user thinks of as "now".
    today_str = state["anki_date"] if running else today_anki_date()
    data = load_data()
    saved_attempted = compute_attempted_minutes(data.get(today_str, {}))
    actual_today = get_study_minutes_for_date(today_str)

    raw_attempted = saved_attempted + (state["elapsed_min"] if running else 0)
    effective = compute_effective_attempted(raw_attempted, actual_today)
    eff = compute_efficiency_percent(raw_attempted, actual_today)
    eff_str = f"{eff:.0f}%" if eff is not None else "—"
    colour = _eff_colour(eff)

    _statusbar_label.setText(
        f'⏱ <b>{effective:.0f}</b> min attempted'
        f' &nbsp;·&nbsp; <b>{actual_today:.1f}</b> min Anki'
        f' &nbsp;·&nbsp; <b style="color:{colour}">{eff_str}</b>'
    )
    _statusbar_label.setVisible(True)

    # --- Sync the menu action label ---
    if _start_action_ref is not None:
        _start_action_ref.setText("⏹ Stop session" if running else "▶ Start session…")


def _install_statusbar():
    """Create the statusbar widgets and register them with the tracker."""
    global _statusbar_button, _statusbar_label
    if _statusbar_button is not None:
        return
    sb = mw.statusBar()
    if sb is None:
        return

    button = QPushButton("▶")
    button.setFlat(True)
    button.setCursor(Qt.CursorShape.PointingHandCursor)
    # Compact: tight padding, fixed-ish width so it doesn't shift when
    # the icon switches between ▶ and ⏹.
    button.setFixedWidth(28)
    button.setStyleSheet(
        "QPushButton { padding: 1px 0; border: 1px solid rgba(128,128,128,0.30); "
        "border-radius: 3px; font-size: 11px; } "
        "QPushButton:hover { background: rgba(128,128,128,0.15); }"
    )
    button.clicked.connect(toggle_live_session)

    label = QLabel()
    label.setTextFormat(Qt.TextFormat.RichText)
    label.setStyleSheet("QLabel { padding: 0 8px; }")
    label.setVisible(False)

    sb.addPermanentWidget(button)
    sb.addPermanentWidget(label)
    _statusbar_button = button
    _statusbar_label = label
    get_tracker().add_listener(_refresh_statusbar)


# ---------- Start / stop actions ----------

class StartSessionDialog(QDialog):
    """Tiny dialog asked when the user clicks Start. Defaults to the current
    time but can be back-dated, so a user who started studying 5 minutes
    ago and only now hit Start can correct that. Also reused for editing
    the start time of an already-running session."""

    def __init__(self, parent=None, initial_time=None, edit_mode=False):
        super().__init__(parent)
        self.setWindowTitle("Edit start time" if edit_mode else "Start session")
        self.resize(300, 120)

        layout = QVBoxLayout()
        layout.setContentsMargins(16, 16, 16, 16)
        layout.setSpacing(10)

        row = QHBoxLayout()
        row.addWidget(QLabel("Started at:"))
        self.time_edit = QTimeEdit(initial_time or QTime.currentTime())
        self.time_edit.setDisplayFormat("HH:mm")
        # Maximum is "now" — back-dating only, no future timestamps.
        self.time_edit.setMaximumTime(QTime.currentTime())
        row.addWidget(self.time_edit)
        row.addStretch()
        layout.addLayout(row)

        if edit_mode:
            hint_text = "Adjust the moment your current session began."
        else:
            hint_text = "Defaults to right now. Adjust if you started a few minutes ago."
        self.hint = QLabel(hint_text)
        self.hint.setStyleSheet("color: rgba(128,128,128,0.85); font-size: 11px;")
        self.hint.setWordWrap(True)
        layout.addWidget(self.hint)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.button(QDialogButtonBox.StandardButton.Ok).setText(
            "Save" if edit_mode else "Start"
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

        self.setLayout(layout)

    def get_start_datetime(self):
        """Return today's date combined with the chosen time. If the chosen
        time is later than 'now' (e.g. user picked 23:00 and it's 00:30),
        treat it as belonging to yesterday so the elapsed duration is
        positive and small rather than ~23 hours."""
        now = datetime.now()
        chosen = self.time_edit.time()
        candidate = now.replace(
            hour=chosen.hour(), minute=chosen.minute(),
            second=0, microsecond=0,
        )
        if candidate > now:
            candidate -= timedelta(days=1)
        return candidate


def toggle_live_session():
    """Single menu entry that starts or stops the session depending on
    current state. Connected to a keyboard shortcut for fast access."""
    tracker = get_tracker()
    if tracker.is_running():
        tracker.stop()
    else:
        _prompt_and_start()


def _prompt_and_start():
    """Show the start-time dialog, auto-fill any earlier unaccounted Anki
    time, then start the session if confirmed."""
    dialog = StartSessionDialog(mw)
    if dialog.exec():
        started_at = dialog.get_start_datetime()
        # If the user already did some Anki today before clicking Start
        # (without logging it), bookkeep that time as an untimed session
        # right now, so the live session begins from a clean baseline
        # and the displayed efficiency stays honest.
        date_str = anki_date_for(started_at)
        filled = autofill_unaccounted_anki_time(date_str, started_at)
        get_tracker().start(started_at=started_at)

        msg = f"Live session started — anchored to {started_at.strftime('%H:%M')}"
        if filled > 0:
            msg += f" (auto-logged {filled:.0f} min of earlier Anki activity)"
        tooltip(msg, period=5000)


def start_live_session():
    if get_tracker().is_running():
        showInfo("A session is already running. Stop it first.")
        return
    _prompt_and_start()


def stop_live_session():
    if not get_tracker().is_running():
        showInfo("No session is currently running.")
        return
    get_tracker().stop()


# ---------- Profile lifecycle ----------

def _on_profile_open():
    """Runs after the user's profile loads. Creates the statusbar widget,
    handles a session that survived a previous shutdown, and refreshes the
    UI to match current state."""
    _install_statusbar()
    get_tracker().ensure_timer_for_loaded_session()
    _refresh_statusbar()


def _on_profile_close():
    """Runs as Anki is shutting down. Per user preference: auto-stop and
    save whatever was tracked so far."""
    if get_tracker().is_running():
        get_tracker().stop(silent=True)


gui_hooks.profile_did_open.append(_on_profile_open)
gui_hooks.profile_will_close.append(_on_profile_close)


# ---------- Menu setup ----------

def setup_menu():
    global _start_action_ref
    menu = mw.form.menuTools.addMenu("Efficiency Tracker")

    # Live session toggle — label switches based on state. Refreshed by
    # _refresh_statusbar() which the tracker calls every second while
    # running and on every state edge.
    action_toggle = QAction("▶ Start session…", mw)
    action_toggle.setShortcut("Ctrl+Shift+R")
    qconnect(action_toggle.triggered, toggle_live_session)
    menu.addAction(action_toggle)
    _start_action_ref = action_toggle

    menu.addSeparator()

    action_input = QAction("➕ Enter study time…", mw)
    action_input.setShortcut("Ctrl+Shift+E")
    qconnect(action_input.triggered, show_input_dialog)
    menu.addAction(action_input)

    action_stats = QAction("📊 Show statistics…", mw)
    action_stats.setShortcut("Ctrl+Shift+S")
    qconnect(action_stats.triggered, show_stats)
    menu.addAction(action_stats)

    menu.addSeparator()

    action_export = QAction("📤 Export data…", mw)
    qconnect(action_export.triggered, show_export_dialog)
    menu.addAction(action_export)

    action_import = QAction("📥 Import data…", mw)
    qconnect(action_import.triggered, show_import_dialog)
    menu.addAction(action_import)


setup_menu()
