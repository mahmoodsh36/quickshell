pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// cltpt agenda as a month view. clock click, or qs ipc call calendar toggle.
Singleton {
  id: root
  readonly property bool open: popup.open

  property int viewYear: 0
  property int viewMonth: 0
  property date selected: new Date()
  property date today: new Date()

  readonly property var locale: Qt.locale()
  readonly property int firstDay: locale.firstDayOfWeek % 7
  // always 6 rows so the height stays fixed
  readonly property date gridStart: {
    const first = new Date(viewYear, viewMonth, 1);
    return addDays(first, -((first.getDay() - firstDay + 7) % 7));
  }

  // yyyy-mm-dd -> entries
  property var entries: ({})
  property var cache: ({})
  property bool loading: false
  property string error: ""
  property string pending: ""
  // when cache was last emptied, edits after it make it stale
  property real since: Date.now()

  function show() {
    Popups.open("calendar");
    goTo(new Date());
    refresh();
  }
  function hide() {
    Popups.close("calendar");
  }
  function toggle() {
    if (open)
      hide();
    else
      show();
  }

  function addDays(d, n) {
    return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
  }
  function key(d) {
    return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
  }
  function sameDay(a, b) {
    return key(a) === key(b);
  }

  function goTo(d) {
    selected = d;
    if (d.getFullYear() !== viewYear || d.getMonth() !== viewMonth) {
      viewYear = d.getFullYear();
      viewMonth = d.getMonth();
      fetch(false);
    }
  }
  function moveMonth(n) {
    const d = new Date(viewYear, viewMonth + n, 1);
    // clamp to the month's last day
    const last = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
    goTo(new Date(d.getFullYear(), d.getMonth(), Math.min(selected.getDate(), last)));
  }

  // reparsing every note is slow, so cached months are kept until an org file changes
  function refresh() {
    today = new Date();
    changes.exec(["find", Config.notesDir + "/", "-maxdepth", "1", "-name", "*.org", "-newermt", "@" + since / 1000, "-print", "-quit"]);
  }
  function invalidate() {
    cache = {};
    since = Date.now();
  }

  // force skips the cache
  function fetch(force) {
    const k = key(gridStart);
    if (!open && !force)
      return;
    entries = cache[k] || {};
    if (!force && (cache[k] || loading && pending === k))
      return;
    pending = k;
    loading = true;
    error = "";
    watchdog.restart();
    run();
  }
  // a superseded run is killed and its exit starts the next, since exec on a running process mixes their output
  function run() {
    if (proc.running) {
      proc.stale = true;
      proc.signal(15);
      return;
    }
    proc.stale = false;
    proc.started = false;
    const rule = '(:path ("' + Config.notesDir + '/") :glob "*.org" :format "org-mode")';
    proc.exec(["cltpt", "agenda", "-r", rule, "--from", pending, "--to", key(addDays(gridStart, 42)), "--style", "json", "--include-done"]);
  }

  function ingest(text) {
    const out = {};
    function walk(nodes) {
      for (const n of nodes || []) {
        if (n.title !== undefined && n.begin) {
          const k = n.begin.slice(0, 10);
          (out[k] = out[k] || []).push(n);
        }
        walk(n.children);
      }
    }
    walk(JSON.parse(text));
    for (const k in out)
      out[k].sort((a, b) => a.done - b.done || b.all_day - a.all_day || a.begin.localeCompare(b.begin));
    return out;
  }

  function finish(err) {
    loading = false;
    error = err;
    watchdog.stop();
  }

  // open at login, not on every hot reload
  PersistentProperties {
    reloadableId: "calendar"
    property bool started: false
    onLoaded: {
      if (!started) {
        started = true;
        root.show();
      }
    }
  }

  // pick up edits and roll today over while open
  Timer {
    interval: 5 * 60 * 1000
    running: root.open
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: changes
    stdout: StdioCollector {
      onStreamFinished: {
        if (text !== "")
          root.invalidate();
        root.fetch(text !== "");
      }
    }
  }

  Process {
    id: proc
    property bool stale: false
    property bool started: false
    onStarted: started = true
    // failed starts only emit runningChanged. deferred past the exit's output
    onRunningChanged: Qt.callLater(() => {
      if (proc.running || !root.loading)
        return;
      if (proc.stale)
        root.run();
      else if (!proc.started)
        root.finish("cltpt not found");
    })
    stdout: StdioCollector {
      onStreamFinished: {
        if (proc.stale)
          return;
        try {
          const parsed = root.ingest(text);
          root.cache[root.pending] = parsed;
          root.entries = parsed;
          root.finish("");
        } catch (e) {
          root.finish("Couldn't read the agenda");
        }
      }
    }
    onExited: code => {
      if (code !== 0 && !proc.stale)
        root.finish("cltpt exited with code " + code);
    }
  }
  Timer {
    id: watchdog
    // a cold parse over a network share can take 20s
    interval: 60000
    onTriggered: {
      root.finish("cltpt didn't respond");
      proc.stale = true;
      proc.signal(9);
    }
  }

  readonly property var selectedEntries: entries[key(selected)] || []

  // widest time label, sizes the time column
  TextMetrics {
    id: timeWidth
    font.family: Theme.font
    font.pixelSize: Theme.fontSizeSmall
    text: "00:00–00:00"
  }

  function timeOf(e) {
    if (e.all_day)
      return "all day";
    const t = e.begin.slice(11, 16);
    return e.end ? t + "–" + e.end.slice(11, 16) : t;
  }
  function colorOf(e) {
    return e.done ? Theme.dim : e.type === "deadline" ? Theme.error : e.type === "scheduled" ? Theme.accent : Theme.info;
  }

  Popup {
    id: popup
    name: "calendar"
    onKeyPressed: event => {
      const k = event.key;
      if (k === Qt.Key_Left || k === Qt.Key_H)
        root.goTo(root.addDays(root.selected, -1));
      else if (k === Qt.Key_Right || k === Qt.Key_L)
        root.goTo(root.addDays(root.selected, 1));
      else if (k === Qt.Key_Up || k === Qt.Key_K)
        root.goTo(root.addDays(root.selected, -7));
      else if (k === Qt.Key_Down || k === Qt.Key_J)
        root.goTo(root.addDays(root.selected, 7));
      else if (k === Qt.Key_PageUp)
        root.moveMonth(-1);
      else if (k === Qt.Key_PageDown)
        root.moveMonth(1);
      else if (k === Qt.Key_T)
        root.goTo(new Date());
      else
        return;
      event.accepted = true;
    }

    Column {
      id: content
      width: parent.width
      spacing: 12

      Item {
        width: parent.width
        height: 36
        Column {
          anchors.left: parent.left
          anchors.leftMargin: 4
          anchors.verticalCenter: parent.verticalCenter
          Label {
            text: root.locale.standaloneMonthName(root.viewMonth)
            font.pixelSize: Theme.fontSize + 5
            font.bold: true
          }
          Caption {
            text: root.viewYear
          }
        }
        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2
          Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.loading
            name: "progress_activity"
            spinning: visible
            color: Theme.dim
          }
          PillButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.viewYear !== root.today.getFullYear() || root.viewMonth !== root.today.getMonth()
            text: "Today"
            onClicked: root.goTo(new Date())
          }
          IconButton {
            icon: "chevron_left"
            onClicked: root.moveMonth(-1)
          }
          IconButton {
            icon: "chevron_right"
            onClicked: root.moveMonth(1)
          }
        }
      }

      Column {
        width: parent.width
        spacing: 2

        Row {
          Repeater {
            model: 7
            Caption {
              required property int index
              width: content.width / 7
              horizontalAlignment: Text.AlignHCenter
              text: root.locale.dayName((root.firstDay + index) % 7, Locale.ShortFormat).slice(0, 2)
              font.bold: true
            }
          }
        }

        Grid {
          id: grid
          columns: 7

          WheelSteps {
            onStepped: steps => root.moveMonth(-steps)
          }

          Repeater {
            model: 42
            Item {
              id: cell
              required property int index
              readonly property date day: root.addDays(root.gridStart, index)
              readonly property bool inMonth: day.getMonth() === root.viewMonth
              readonly property bool isToday: root.sameDay(day, root.today)
              readonly property bool isSelected: root.sameDay(day, root.selected)
              readonly property var dayEntries: root.entries[root.key(day)] || []
              width: content.width / 7
              height: 42

              Rectangle {
                anchors.centerIn: parent
                width: 36
                height: 36
                radius: 18
                color: cell.isToday ? Theme.accent : cell.isSelected ? Theme.bg2 : cellMouse.containsMouse ? Theme.hover("transparent") : "transparent"
                border.width: cell.isSelected && cell.isToday ? 2 : 0
                border.color: Theme.fg
              }
              Label {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -3
                text: cell.day.getDate()
                color: cell.isToday ? Theme.accentFg : cell.inMonth ? Theme.fg : Theme.dim
                opacity: cell.inMonth ? 1 : 0.5
                font.bold: cell.isToday || cell.isSelected
              }
              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 9
                spacing: 3
                Repeater {
                  model: cell.dayEntries.slice(0, 3)
                  Rectangle {
                    required property var modelData
                    width: 4
                    height: 4
                    radius: 2
                    color: cell.isToday ? Theme.accentFg : root.colorOf(modelData)
                    // fade repeats so one-offs stand out
                    opacity: modelData.repeat ? 0.35 : 1
                  }
                }
              }
              MouseArea {
                id: cellMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.goTo(cell.day)
              }
            }
          }
        }
      }

      Divider {}

      Column {
        width: parent.width
        spacing: 6

        Label {
          leftPadding: 4
          text: root.sameDay(root.selected, root.today) ? "Today" : root.selected.toLocaleDateString(root.locale, "dddd, d MMMM")
          font.bold: true
        }

        EmptyState {
          visible: root.error !== ""
          icon: "error"
          text: root.error
        }
        EmptyState {
          visible: root.error === "" && !root.loading && root.selectedEntries.length === 0
          icon: "event_available"
          text: "Nothing scheduled"
        }

        ScrollColumn {
          id: agenda
          visible: root.selectedEntries.length > 0
          maxHeight: 240
          spacing: 4

          Repeater {
            model: root.selectedEntries
            Rectangle {
              id: entry
              required property var modelData
              width: agenda.width
              implicitHeight: entryText.implicitHeight + 16
              radius: 10
              color: Theme.bg1

              Rectangle {
                width: 4
                height: parent.height
                radius: 2
                color: root.colorOf(entry.modelData)
              }
              Caption {
                id: when
                x: 14
                y: 8
                width: timeWidth.width + 12
                text: root.timeOf(entry.modelData)
              }
              Column {
                id: entryText
                anchors.left: when.right
                anchors.right: parent.right
                anchors.rightMargin: 10
                y: 8
                spacing: 2
                Label {
                  width: parent.width
                  text: entry.modelData.title
                  wrapMode: Text.Wrap
                  color: entry.modelData.done ? Theme.dim : Theme.fg
                  font.strikeout: entry.modelData.done
                }
                Caption {
                  width: parent.width
                  visible: text !== ""
                  text: [entry.modelData.type === "deadline" ? "deadline" : "", entry.modelData.state || "", (entry.modelData.tags || []).map(t => "#" + t).join(" ")].filter(s => s !== "").join(" · ")
                  color: entry.modelData.type === "deadline" && !entry.modelData.done ? Theme.error : Theme.dim
                  elide: Text.ElideRight
                }
              }
            }
          }
        }
      }
    }
  }
}
