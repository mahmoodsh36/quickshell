pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// cltpt agenda as a month view. clock click, or qs ipc call calendar toggle.
Singleton {
  id: root
  property bool open: false
  property var barWindows: []

  property int viewYear: 0
  property int viewMonth: 0
  property date selected: new Date()
  property date today: new Date()

  readonly property var locale: Qt.locale()
  readonly property int firstDay: locale.firstDayOfWeek % 7
  // always 6 rows so the height stays fixed
  readonly property date gridStart: {
    var first = new Date(viewYear, viewMonth, 1);
    return addDays(first, -((first.getDay() - firstDay + 7) % 7));
  }

  // yyyy-mm-dd -> entries
  property var entries: ({})
  property var cache: ({})
  property bool loading: false
  property string error: ""
  property string pending: ""

  readonly property string notesDir: Quickshell.env("NOTES_DIR") || Quickshell.env("HOME") + "/brain/notes"

  function show() {
    ControlCenter.hide();
    today = new Date();
    cache = {};
    goTo(today);
    open = true;
    fetch(true);
  }
  function hide() {
    open = false;
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
    var d = new Date(viewYear, viewMonth + n, 1);
    // clamp to the month's last day
    var last = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
    goTo(new Date(d.getFullYear(), d.getMonth(), Math.min(selected.getDate(), last)));
  }

  // force skips the cache
  function fetch(force) {
    var k = key(gridStart);
    if (!open && !force)
      return;
    entries = cache[k] || {};
    if (cache[k] && !force)
      return;
    pending = k;
    loading = true;
    error = "";
    var rule = '(:path ("' + notesDir + '/") :glob "*.org" :format "org-mode")';
    proc.exec(["cltpt", "agenda", "-r", rule, "--from", k, "--to", key(addDays(gridStart, 42)), "--style", "json", "--include-done"]);
    watchdog.restart();
  }

  function ingest(text) {
    var out = {};
    function walk(nodes) {
      for (var n of nodes || []) {
        if (n.title !== undefined && n.begin) {
          var k = n.begin.slice(0, 10);
          (out[k] = out[k] || []).push(n);
        }
        walk(n.children);
      }
    }
    walk(JSON.parse(text));
    for (var k in out)
      out[k].sort((a, b) => a.done - b.done || b.all_day - a.all_day || a.begin.localeCompare(b.begin));
    return out;
  }

  // open at login
  Component.onCompleted: show()

  // refetch and roll today over while open
  Timer {
    interval: 5 * 60 * 1000
    running: root.open
    repeat: true
    onTriggered: {
      root.today = new Date();
      root.cache = {};
      root.fetch(true);
    }
  }

  Process {
    id: proc
    property string forKey: ""
    onStarted: forKey = root.pending
    // failed starts only emit runningChanged. deferred past a superseded run's exit
    onRunningChanged: Qt.callLater(() => {
      if (!proc.running && proc.forKey !== root.pending && root.loading) {
        root.loading = false;
        root.error = "cltpt not found";
        watchdog.stop();
      }
    })
    stdout: StdioCollector {
      onStreamFinished: {
        if (proc.forKey !== root.pending)
          return;
        try {
          var parsed = root.ingest(text);
          root.cache[proc.forKey] = parsed;
          root.entries = parsed;
          root.error = "";
        } catch (e) {
          root.error = "Couldn't read the agenda";
        }
        root.loading = false;
        watchdog.stop();
      }
    }
    onExited: code => {
      if (code !== 0 && proc.forKey === root.pending) {
        root.error = "cltpt exited with code " + code;
        root.loading = false;
        watchdog.stop();
      }
    }
  }
  Timer {
    id: watchdog
    interval: 20000
    onTriggered: {
      root.loading = false;
      root.error = "cltpt didn't respond";
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
    var t = e.begin.slice(11, 16);
    return e.end ? t + "–" + e.end.slice(11, 16) : t;
  }
  function colorOf(e) {
    return e.done ? Theme.dim : e.type === "deadline" ? Theme.red : e.type === "scheduled" ? Theme.accent : Theme.blue;
  }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: panel
      required property var modelData
      screen: modelData
      visible: root.open && (Hyprland.focusedMonitor ? modelData.name === Hyprland.focusedMonitor.name : true)
      focusable: true
      anchors {
        top: true
        right: true
      }
      margins {
        top: Theme.barHeight + 6
        right: 8
      }
      exclusionMode: ExclusionMode.Ignore
      implicitWidth: 360
      implicitHeight: content.implicitHeight + 32
      color: "transparent"

      onVisibleChanged: {
        if (visible)
          frame.forceActiveFocus();
      }

      HyprlandFocusGrab {
        active: panel.visible
        windows: [panel].concat(Array.from(root.barWindows))
        onCleared: root.hide()
      }

      Rectangle {
        id: frame
        anchors.fill: parent
        color: Theme.bg
        border.width: 1
        border.color: Theme.bg2
        radius: 20
        focus: true

        Keys.onPressed: event => {
          var k = event.key;
          if (k === Qt.Key_Escape)
            root.hide();
          else if (k === Qt.Key_Left || k === Qt.Key_H)
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
          anchors.fill: parent
          anchors.margins: 16
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
              Label {
                text: root.viewYear
                color: Theme.dim
                font.pixelSize: Theme.fontSizeSmall
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
                Label {
                  required property int index
                  width: content.width / 7
                  horizontalAlignment: Text.AlignHCenter
                  text: root.locale.dayName((root.firstDay + index) % 7, Locale.ShortFormat).slice(0, 2)
                  color: Theme.dim
                  font.pixelSize: Theme.fontSizeSmall
                  font.bold: true
                }
              }
            }

            Grid {
              id: grid
              columns: 7

              WheelHandler {
                property real acc: 0
                onWheel: event => {
                  acc += event.angleDelta.y;
                  var steps = Math.trunc(acc / 120);
                  if (steps !== 0) {
                    acc -= steps * 120;
                    root.moveMonth(-steps);
                  }
                }
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
                    color: cell.isToday ? Theme.bg : cell.inMonth ? Theme.fg : Theme.dim
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
                        color: cell.isToday ? Theme.bg : root.colorOf(modelData)
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

          Rectangle {
            width: parent.width
            height: 1
            color: Theme.bg2
          }

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

            Flickable {
              visible: root.selectedEntries.length > 0
              width: parent.width
              height: Math.min(contentHeight, 240)
              contentHeight: agenda.implicitHeight
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              Column {
                id: agenda
                width: parent.width
                spacing: 4

                Repeater {
                  model: root.selectedEntries
                  Rectangle {
                    id: entry
                    required property var modelData
                    readonly property var e: modelData
                    width: agenda.width
                    implicitHeight: entryText.implicitHeight + 16
                    radius: 10
                    color: Theme.bg1

                    Rectangle {
                      x: 0
                      width: 4
                      height: parent.height
                      radius: 2
                      color: root.colorOf(entry.e)
                    }
                    Label {
                      id: when
                      x: 14
                      y: 8
                      width: timeWidth.width + 12
                      text: root.timeOf(entry.e)
                      color: Theme.dim
                      font.pixelSize: Theme.fontSizeSmall
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
                        text: entry.e.title
                        wrapMode: Text.Wrap
                        color: entry.e.done ? Theme.dim : Theme.fg
                        font.strikeout: entry.e.done
                      }
                      Label {
                        width: parent.width
                        visible: text !== ""
                        text: [entry.e.type === "deadline" ? "deadline" : "", entry.e.state || "", (entry.e.tags || []).map(t => "#" + t).join(" ")].filter(s => s !== "").join(" · ")
                        color: entry.e.type === "deadline" && !entry.e.done ? Theme.red : Theme.dim
                        font.pixelSize: Theme.fontSizeSmall
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
    }
  }
}
