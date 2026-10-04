import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Scope {
  id: root

  readonly property var windows: bars.instances

  // special workspaces have negative ids
  property var wsIds: Array.from(Hyprland.workspaces.values).map(w => w.id).filter(id => id > 0)
  property int focusedWs: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
  // 1..5 always, higher ones while in use
  property int wsCount: Math.max(5, focusedWs, ...wsIds)
  property string winTitle: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""

  property var bat: UPower.displayDevice
  property bool hasBat: bat !== null && bat.isLaptopBattery
  property int batPct: hasBat ? Math.round(bat.percentage) : 0
  property bool charging: hasBat && bat.state === UPowerDeviceState.Charging

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Variants {
    id: bars
    model: Quickshell.screens

    PanelWindow {
      id: bar
      required property var modelData
      screen: modelData

      anchors {
        top: true
        left: true
        right: true
      }
      implicitHeight: Theme.barHeight
      color: Theme.bg

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        Label {
          text: "⚙"
          color: Theme.yellow
          font.pixelSize: Theme.fontSize + 2
          clickable: true
          onClicked: ControlCenter.toggle("left")
        }

        Item {
          implicitWidth: wsRow.width
          implicitHeight: 24

          Rectangle {
            // count dep, itemAt isn't reactive
            property Item target: wsRepeater.count > 0 && root.focusedWs > 0 ? wsRepeater.itemAt(root.focusedWs - 1) : null
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
          }

          Row {
            id: wsRow
            Repeater {
              id: wsRepeater
              model: root.wsCount
              Item {
                id: ws
                required property int index
                readonly property int wsId: index + 1
                readonly property bool isActive: root.focusedWs === wsId
                readonly property bool isBusy: root.wsIds.includes(wsId)
                implicitWidth: 26
                implicitHeight: 24
                Label {
                  anchors.centerIn: parent
                  text: ws.wsId
                  color: ws.isActive ? Theme.bg : (wsMouse.containsMouse ? Theme.yellow : (ws.isBusy ? Theme.fg : Theme.dim))
                  font.bold: ws.isActive
                  Behavior on color {
                    ColorAnimation {
                      duration: 150
                    }
                  }
                }
                MouseArea {
                  id: wsMouse
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  hoverEnabled: true
                  onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + ws.wsId + " })")
                }
              }
            }
          }
        }

        Label {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          text: root.winTitle
          color: Theme.dim
        }

        Label {
          text: "MEM " + SysStats.mem + "  LOAD " + SysStats.load
          color: Theme.blue
        }

        Label {
          visible: Audio.ok
          text: "♪ " + (Audio.muted ? "MUTE" : Math.round(Audio.volume * 100) + "%")
          color: Audio.muted ? Theme.red : Theme.green
          clickable: true
          onClicked: ControlCenter.toggle("right")
          WheelHandler {
            // one step per 120, touchpads send small deltas
            property real acc: 0
            onWheel: event => {
              acc += event.angleDelta.y;
              var steps = Math.trunc(acc / 120);
              if (steps !== 0) {
                acc -= steps * 120;
                Audio.setVolume(Audio.volume + steps * 0.05);
              }
            }
          }
        }

        Label {
          visible: root.hasBat
          text: "BAT " + root.batPct + "%" + (root.charging ? "+" : "")
          color: root.batPct < 20 && !root.charging ? Theme.red : Theme.fg
          clickable: true
          onClicked: ControlCenter.toggle("right")
        }

        Label {
          text: Qt.formatDateTime(clock.date, "ddd d MMM  hh:mm")
        }

        Repeater {
          model: SystemTray.items
          IconImage {
            id: trayIcon
            required property var modelData
            source: modelData.icon
            implicitSize: 16
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
              onClicked: mouse => {
                var item = trayIcon.modelData;
                if (mouse.button === Qt.MiddleButton) {
                  item.secondaryActivate();
                } else if (item.hasMenu && (mouse.button === Qt.RightButton || item.onlyMenu)) {
                  var p = trayIcon.mapToItem(null, 0, trayIcon.height);
                  item.display(bar, p.x, p.y);
                } else {
                  item.activate();
                }
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
