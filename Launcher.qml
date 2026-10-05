pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

// fuzzy app launcher and clipboard history. Super+R and Super+Shift+V (xremap), or qs ipc call launcher.
Singleton {
  id: root
  property bool open: false
  // apps or clipboard
  property string mode: "apps"
  property string query: ""
  property int selected: 0
  readonly property string terminal: "wezterm"
  // cliphist list lines, "id\tpreview"
  property var clips: []

  function show(m) {
    mode = m || "apps";
    input.text = "";
    window.screen = Focus.screen;
    open = true;
    input.forceActiveFocus();
    if (mode === "clipboard")
      clipList.running = true;
  }
  function hide() {
    open = false;
  }
  function toggle(m) {
    if (open && mode === (m || "apps"))
      hide();
    else
      show(m);
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

  property var clipMatches: {
    var q = query.trim().toLowerCase();
    return clips.filter(c => c.toLowerCase().includes(q)).slice(0, 9);
  }

  property var matches: mode === "clipboard" ? clipMatches : filtered
  property var current: matches.length > 0 ? matches[Math.min(selected, matches.length - 1)] : null

  // execute() ignores runInTerminal
  function launch(entry) {
    if (!entry)
      return;
    if (mode === "clipboard") {
      Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", entry]);
    } else if (entry.runInTerminal) {
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
    selected = Math.max(0, Math.min(selected + d, matches.length - 1));
  }

  function forget(clip) {
    if (clip)
      Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "sh", clip]);
    clips = clips.filter(c => c !== clip);
  }

  Process {
    id: clipList
    command: ["cliphist", "list"]
    stdout: StdioCollector {
      onStreamFinished: root.clips = text.split("\n").filter(l => l !== "")
    }
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
              else if (event.key === Qt.Key_Delete && root.mode === "clipboard")
                root.forget(root.current);
              else
                return;
              event.accepted = true;
            }
          }
        }

        Repeater {
          model: root.matches
          Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool isCurrent: index === root.selected
            readonly property bool isClip: root.mode === "clipboard"
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
                visible: !row.isClip
                anchors.verticalCenter: parent.verticalCenter
                source: row.isClip ? "" : Quickshell.iconPath(row.modelData.icon, true)
                implicitSize: 24
              }
              Icon {
                visible: row.isClip
                anchors.verticalCenter: parent.verticalCenter
                name: "content_paste"
                color: Theme.dim
              }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 34
                Label {
                  width: parent.width
                  elide: Text.ElideRight
                  text: row.isClip ? row.modelData.split("\t").slice(1).join(" ") : row.modelData.name
                  color: row.isCurrent ? Theme.yellow : Theme.fg
                  Behavior on color {
                    ColorAnimation {
                      duration: 120
                    }
                  }
                }
                Label {
                  visible: text !== ""
                  text: row.isClip ? "" : row.modelData.genericName || ""
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
          visible: root.matches.length === 0
          width: content.width
          height: 44
          verticalAlignment: Text.AlignVCenter
          horizontalAlignment: Text.AlignHCenter
          text: root.mode === "clipboard" && root.clips.length === 0 ? "clipboard history is empty" : "no match"
          color: Theme.dim
        }
      }
    }
  }
}
