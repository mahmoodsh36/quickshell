pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

// fuzzy app launcher. Super+R (xremap), or qs ipc call launcher toggle.
Singleton {
  id: root
  property bool open: false
  property string query: ""
  property int selected: 0
  readonly property string terminal: "wezterm"

  function show() {
    input.text = "";
    var name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
    window.screen = Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0];
    open = true;
    input.forceActiveFocus();
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

  function score(entry, q) {
    var name = (entry.name || "").toLowerCase();
    if (name.startsWith(q))
      return 0;
    if (name.includes(q))
      return 1;
    var hay = [entry.genericName, entry.comment].concat(Array.from(entry.keywords || [])).join(" ").toLowerCase();
    return hay.includes(q) ? 2 : -1;
  }

  // applications already excludes Hidden/NoDisplay entries
  property var filtered: {
    var q = query.trim().toLowerCase();
    return Array.from(DesktopEntries.applications.values)
      .map(e => ({ s: score(e, q), name: (e.name || "").toLowerCase(), e: e }))
      .filter(x => x.s >= 0)
      .sort((a, b) => a.s - b.s || a.name.localeCompare(b.name))
      .slice(0, 9)
      .map(x => x.e);
  }

  property var current: filtered.length > 0 ? filtered[Math.min(selected, filtered.length - 1)] : null

  // execute() ignores runInTerminal
  function launch(entry) {
    if (!entry)
      return;
    if (entry.runInTerminal) {
      var ctx = { command: [terminal, "start", "--"].concat(Array.from(entry.command)) };
      if (entry.workingDirectory)
        ctx.workingDirectory = entry.workingDirectory;
      Quickshell.execDetached(ctx);
    } else {
      entry.execute();
    }
    hide();
  }

  function move(d) {
    selected = Math.max(0, Math.min(selected + d, filtered.length - 1));
  }

  PanelWindow {
    id: window
    visible: root.open
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 520
    implicitHeight: content.implicitHeight + 20
    color: "transparent"

    HyprlandFocusGrab {
      active: window.visible
      windows: [window]
      onCleared: root.hide()
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.bg
      border.width: 1
      border.color: Theme.bg2
      radius: 8

      Column {
        id: content
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Rectangle {
          width: content.width
          height: 44
          radius: Theme.radius
          color: Theme.bg1
          TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            focus: true
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 15
            onTextChanged: {
              root.query = text;
              root.selected = 0;
            }
            onAccepted: root.launch(root.current)
            Keys.onPressed: event => {
              var ctrl = event.modifiers & Qt.ControlModifier;
              if (event.key === Qt.Key_Escape)
                root.hide();
              else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && event.key === Qt.Key_N))
                root.move(1);
              else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && event.key === Qt.Key_P))
                root.move(-1);
              else
                return;
              event.accepted = true;
            }
          }
        }

        Repeater {
          model: root.filtered
          Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool isCurrent: index === root.selected
            width: content.width
            height: 40
            radius: Theme.radius
            color: isCurrent ? Theme.bg1 : "transparent"
            Row {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              spacing: 10
              IconImage {
                anchors.verticalCenter: parent.verticalCenter
                source: Quickshell.iconPath(row.modelData.icon, true)
                implicitSize: 24
              }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                Label {
                  text: row.modelData.name
                  color: row.isCurrent ? Theme.yellow : Theme.fg
                  Behavior on color {
                    ColorAnimation {
                      duration: 120
                    }
                  }
                }
                Label {
                  visible: text !== ""
                  text: row.modelData.genericName
                  color: Theme.dim
                  font.pixelSize: Theme.fontSizeSmall
                }
              }
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true
              onEntered: root.selected = row.index
              onClicked: root.launch(row.modelData)
            }
          }
        }

        Label {
          visible: root.filtered.length === 0
          width: content.width
          height: 44
          verticalAlignment: Text.AlignVCenter
          horizontalAlignment: Text.AlignHCenter
          text: "no match"
          color: Theme.dim
        }
      }
    }
  }
}
