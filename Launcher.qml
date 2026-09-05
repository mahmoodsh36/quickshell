pragma Singleton
import Quickshell
import Quickshell.Widgets
import QtQuick

// fuzzy app launcher. Super+R (xremap), or qs ipc call launcher toggle.
// the popup title matches the float/pin/focus rules in hyprland.lua.
Singleton {
  id: root
  property bool open: false
  property string query: ""
  property int selected: 0

  function show() {
    query = "";
    selected = 0;
    input.text = "";
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

  // applications already excludes Hidden/NoDisplay entries
  property var apps: {
    DesktopEntries.applications.values;
    return DesktopEntries.applications.values;
  }

  function score(entry, q) {
    var name = (entry.name || "").toLowerCase();
    if (q === "")
      return 0;
    if (name.indexOf(q) === 0)
      return 0;
    if (name.indexOf(q) !== -1)
      return 1;
    var hay = ((entry.genericName || "") + " " + (entry.comment || "")).toLowerCase();
    return hay.indexOf(q) !== -1 ? 2 : -1;
  }

  property var filtered: {
    var q = query.trim().toLowerCase();
    var out = [];
    for (var i = 0; i < apps.length; i++) {
      var s = score(apps[i], q);
      if (s >= 0)
        out.push([s, (apps[i].name || "").toLowerCase(), apps[i]]);
    }
    out.sort(function(a, b) {
      return a[0] - b[0] || (a[1] < b[1] ? -1 : (a[1] > b[1] ? 1 : 0));
    });
    return out.slice(0, 9).map(function(x) {
      return x[2];
    });
  }

  property var current: filtered.length > 0 ? filtered[Math.min(selected, filtered.length - 1)] : null

  // execute() ignores runInTerminal, so terminal-only entries stay broken
  function launch(entry) {
    if (entry) {
      entry.execute();
      hide();
    }
  }

  FloatingWindow {
    title: "qs-launcher-popup"
    visible: root.open
    width: 520
    height: 20 + 44 + 8 + Math.max(root.filtered.length, 1) * 44
    color: "transparent"

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
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 15
            onTextChanged: {
              root.query = text;
              root.selected = 0;
            }
            onAccepted: root.launch(root.current)
            Keys.onPressed: event => {
              if (event.key === Qt.Key_Escape) {
                root.hide();
                event.accepted = true;
              } else if (event.key === Qt.Key_Down) {
                root.selected = Math.min(root.selected + 1, root.filtered.length - 1);
                event.accepted = true;
              } else if (event.key === Qt.Key_Up) {
                root.selected = Math.max(root.selected - 1, 0);
                event.accepted = true;
              }
            }
          }
        }

        Repeater {
          model: root.filtered
          Rectangle {
            required property var modelData
            required property int index
            property bool isCurrent: index === root.selected
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
                source: modelData.icon
                implicitSize: 24
              }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                Text {
                  text: modelData.name
                  color: isCurrent ? Theme.yellow : Theme.fg
                  font.family: Theme.font
                  font.pixelSize: Theme.fontSize
                  Behavior on color {
                    ColorAnimation {
                      duration: 120
                    }
                  }
                }
                Text {
                  visible: modelData.genericName !== ""
                  text: modelData.genericName
                  color: Theme.dim
                  font.family: Theme.font
                  font.pixelSize: 11
                }
              }
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true
              onEntered: root.selected = index
              onClicked: root.launch(modelData)
            }
          }
        }

        Text {
          visible: root.filtered.length === 0
          width: content.width
          height: 44
          verticalAlignment: Text.AlignVCenter
          horizontalAlignment: Text.AlignHCenter
          text: "no match"
          color: Theme.dim
          font.family: Theme.font
          font.pixelSize: Theme.fontSize
        }
      }
    }
  }
}
