import Quickshell
import Quickshell.Hyprland
import Quickshell.Networking
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
  // upower reports 0..1
  property int batPct: hasBat ? Math.round(bat.percentage * 100) : 0
  property bool charging: hasBat && bat.state === UPowerDeviceState.Charging

  function batIcon() {
    if (charging)
      return "battery_charging_full";
    return batPct >= 95 ? "battery_full" : "battery_" + Math.round(batPct / 100 * 6) + "_bar";
  }
  function wifiIcon() {
    var net = ControlCenter.wifiNetwork;
    if (!Networking.wifiEnabled)
      return "wifi_off";
    if (!net)
      return "signal_wifi_0_bar";
    var s = net.signalStrength;
    return s > 0.75 ? "signal_wifi_4_bar" : s > 0.5 ? "network_wifi_3_bar" : s > 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar";
  }

  component Pill: Rectangle {
    id: pill
    default property alias content: row.data
    // its popup is open
    property bool active: false
    signal clicked
    visible: row.implicitWidth > 0
    implicitWidth: row.implicitWidth + 16
    implicitHeight: 26
    radius: 13
    color: active || pillMouse.containsMouse ? Theme.bg2 : Theme.bg1
    border.width: active ? 1 : 0
    border.color: Theme.accent
    Behavior on color {
      ColorAnimation {
        duration: 120
      }
    }
    MouseArea {
      id: pillMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: pill.clicked()
    }
    Row {
      id: row
      anchors.centerIn: parent
      spacing: 6
    }
  }

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

        Pill {
          active: ControlCenter.open && ControlCenter.side === "left"
          onClicked: ControlCenter.toggle("left")
          Icon {
            name: "tune"
            color: Theme.accent
          }
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

        Row {
          spacing: 2
          Icon {
            name: "memory"
            size: 14
            color: Theme.blue
            anchors.verticalCenter: parent.verticalCenter
          }
          Label {
            text: SysStats.mem
            color: Theme.blue
            rightPadding: 6
          }
          Icon {
            name: "speed"
            size: 14
            color: Theme.blue
            anchors.verticalCenter: parent.verticalCenter
          }
          Label {
            text: SysStats.load
            color: Theme.blue
          }
        }

        Row {
          spacing: 2
          Icon {
            name: "arrow_downward"
            size: 14
            color: Theme.green
            anchors.verticalCenter: parent.verticalCenter
          }
          Label {
            text: SysStats.down
            color: Theme.green
          }
          Icon {
            name: "arrow_upward"
            size: 14
            color: Theme.yellow
            anchors.verticalCenter: parent.verticalCenter
          }
          Label {
            text: SysStats.up
            color: Theme.yellow
          }
        }

        Pill {
          active: ControlCenter.open && ControlCenter.side === "right"
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
          Icon {
            visible: ControlCenter.wifiDevice !== null
            name: root.wifiIcon()
            size: 16
          }
          Icon {
            visible: ControlCenter.btOn
            name: ControlCenter.btConnected.length > 0 ? "bluetooth_connected" : "bluetooth"
            size: 16
          }
          Icon {
            visible: Audio.ok
            name: Audio.muted ? "volume_off" : Audio.volume < 0.5 ? "volume_down" : "volume_up"
            size: 16
            color: Audio.muted ? Theme.red : Theme.fg
          }
          Label {
            visible: Audio.ok && !Audio.muted
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(Audio.volume * 100) + "%"
          }
          Icon {
            visible: root.hasBat
            name: root.batIcon()
            size: 16
            rotation: 90
            color: root.batPct < 20 && !root.charging ? Theme.red : Theme.fg
          }
          Label {
            visible: root.hasBat
            anchors.verticalCenter: parent.verticalCenter
            text: root.batPct + "%"
            color: root.batPct < 20 && !root.charging ? Theme.red : Theme.fg
          }
        }

        Pill {
          active: Calendar.open
          onClicked: Calendar.toggle()
          Icon {
            name: "calendar_month"
            size: 16
            color: Calendar.open ? Theme.accent : Theme.fg
          }
          Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "ddd d MMM  hh:mm")
          }
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
