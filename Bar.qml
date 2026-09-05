import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Scope {
  id: root

  // hyprland state; .count/.values access keeps these bindings reactive
  property var wsIds: {
    Hyprland.workspaces.count;
    var out = [];
    var vals = Hyprland.workspaces.values;
    for (var i = 0; i < vals.length; i++)
      if (vals[i].id > 0)
        out.push(vals[i].id);
    return out;
  }
  property int focusedWs: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
  property string winTitle: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""

  function occupied(id) {
    return root.wsIds.indexOf(id) !== -1;
  }

  // spawned processes inherit little PATH under uwsm, so set it explicitly
  function spawn(cmd) {
    Quickshell.execDetached(["sh", "-c", "PATH=\"$HOME/.nix-profile/bin:$HOME/.local/bin:/run/current-system/sw/bin:/usr/bin:/bin\" " + cmd]);
  }

  // volume state lives in the control center poll, quickshell pipewire
  // reads go stale on unbound nodes
  property real vol: ControlCenter.volSet >= 0 ? ControlCenter.volSet : ControlCenter.volVal
  property bool muted: ControlCenter.muted
  property bool volOk: ControlCenter.volOk

  property bool hasBat: UPower.displayDevice ? UPower.displayDevice.isLaptopBattery : false
  property int batPct: root.hasBat ? Math.round(UPower.displayDevice.percentage) : 0

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData

      anchors {
        top: true
        left: true
        right: true
      }
      implicitHeight: Theme.barHeight
      color: "transparent"

      Rectangle {
        anchors.fill: parent
        color: Theme.bg

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          spacing: 8

          // control center (launcher lives on Super+R)
          Text {
            text: "⚙"
            color: Theme.yellow
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 2
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: ControlCenter.toggle("left")
            }
          }

          // workspaces, click to switch
          Item {
            implicitWidth: wsRow.width
            implicitHeight: 24

            Rectangle {
              property Item target: root.focusedWs > 0 ? wsRepeater.itemAt(root.focusedWs - 1) : null
              visible: target !== null
              x: target ? target.x : 0
              width: target ? target.width : 26
              height: 24
              radius: Theme.radius
              color: Theme.yellow
              Behavior on x {
                NumberAnimation {
                  duration: 200
                  easing.type: Easing.OutCubic
                }
              }
              Behavior on width {
                NumberAnimation {
                  duration: 200
                  easing.type: Easing.OutCubic
                }
              }
            }

            Row {
              id: wsRow
              Repeater {
                id: wsRepeater
                model: 10
                Rectangle {
                  required property int index
                  property int wsId: index + 1
                  property bool isActive: root.focusedWs === wsId
                  property bool isBusy: root.occupied(wsId)
                  property bool hovered: false
                  implicitWidth: 26
                  implicitHeight: 24
                  color: "transparent"
                  Text {
                    anchors.centerIn: parent
                    text: parent.wsId
                    color: parent.isActive ? Theme.bg : (parent.hovered ? Theme.yellow : (parent.isBusy ? Theme.fg : Theme.dim))
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: parent.isActive
                    Behavior on color {
                      ColorAnimation {
                        duration: 150
                      }
                    }
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: parent.hovered = true
                    onExited: parent.hovered = false
                    onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + parent.wsId + " })")
                  }
                }
              }
            }
          }

          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.winTitle
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
          }

          Text {
            text: "MEM " + SysStats.mem + "  LOAD " + SysStats.load
            color: Theme.blue
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
          }

          Text {
            visible: root.volOk
            text: "♪ " + (root.muted ? "MUTE" : Math.round(root.vol * 100) + "%")
            color: root.muted ? Theme.red : Theme.green
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton
              onClicked: ControlCenter.toggle("right")
              onWheel: wheel => {
                var step = wheel.angleDelta.y > 0 ? "5%+" : "5%-";
                root.spawn("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + step);
              }
            }
          }

          // battery, hidden on desktops without one
          Text {
            visible: root.hasBat
            text: "BAT " + root.batPct + "%"
            color: root.batPct < 20 ? Theme.red : Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: ControlCenter.toggle("right")
            }
          }

          Text {
            text: Qt.formatDateTime(clock.date, "ddd d MMM  hh:mm")
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
          }

          Repeater {
            model: SystemTray.items
            IconImage {
              required property var modelData
              source: modelData.icon
              implicitSize: 16
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                  if (mouse.button === Qt.RightButton)
                    parent.modelData.secondaryActivate();
                  else
                    parent.modelData.activate();
                }
              }
            }
          }

          }

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: 1
          color: Theme.bg1
        }
      }
    }
  }
}
