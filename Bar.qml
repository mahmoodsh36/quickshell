import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Scope {
  id: root

  readonly property var windows: bars.instances

  property bool entered: false
  property real presence: entered && !Style.leaving ? 1 : 0
  Behavior on presence {
    NumberAnimation {
      duration: Style.exitMs
      easing.type: Easing.InOutCubic
    }
  }
  Component.onCompleted: entered = true

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
      exclusiveZone: Theme.barHeight
      implicitHeight: Theme.barHeight
      color: "transparent"

      Rectangle {
        id: slab
        width: parent.width
        height: Theme.barHeight
        color: Theme.bg
        transform: Translate {
          y: -(1 - root.presence) * slab.height
        }

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
              property Item target: wsRepeater.count > 0 && BarState.focusedWs > 0 ? wsRepeater.itemAt(BarState.focusedWs - 1) : null
              visible: target !== null
              x: target ? target.x : 0
              width: target ? target.width : 26
              height: 24
              radius: Theme.radius
              color: Theme.accent
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
                model: BarState.wsCount
                Item {
                  id: ws
                  required property int index
                  readonly property int wsId: index + 1
                  readonly property bool isActive: BarState.focusedWs === wsId
                  readonly property bool isBusy: BarState.wsIds.includes(wsId)
                  implicitWidth: 26
                  implicitHeight: 24
                  Label {
                    anchors.centerIn: parent
                    text: ws.wsId
                    color: ws.isActive ? Theme.accentFg : (wsMouse.containsMouse ? Theme.accent : (ws.isBusy ? Theme.fg : Theme.dim))
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
                    onClicked: BarState.focusWs(ws.wsId)
                  }
                }
              }
            }
          }

          Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: BarState.winTitle
            color: Theme.dim
          }

          Pill {
            visible: Recorder.active
            onClicked: Recorder.toggle()
            Icon {
              name: "radio_button_checked"
              size: 16
              color: Theme.error
            }
            Label {
              anchors.verticalCenter: parent.verticalCenter
              text: Math.floor(Recorder.elapsed / 60) + ":" + String(Recorder.elapsed % 60).padStart(2, "0")
              color: Theme.error
            }
          }

          Pill {
            visible: Media.player !== null
            onClicked: Media.player.togglePlaying()
            Icon {
              name: Media.player && Media.player.isPlaying ? "pause" : "music_note"
              size: 16
              color: Theme.secondary
            }
            Label {
              anchors.verticalCenter: parent.verticalCenter
              width: Math.min(implicitWidth, 220)
              text: Media.artist ? Media.title + " · " + Media.artist : Media.title
              elide: Text.ElideRight
            }
          }

          Pill {
            active: SysInfo.open
            onClicked: SysInfo.toggle()
            Row {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2
              Icon {
                name: "memory"
                size: 14
                color: Theme.info
                anchors.verticalCenter: parent.verticalCenter
              }
              Label {
                text: SysStats.mem
                color: Theme.info
                rightPadding: 6
              }
              Icon {
                name: "speed"
                size: 14
                color: Theme.info
                anchors.verticalCenter: parent.verticalCenter
              }
              Label {
                text: SysStats.load
                color: Theme.info
              }
            }
            Row {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2
              Icon {
                name: "arrow_downward"
                size: 14
                color: Theme.success
                anchors.verticalCenter: parent.verticalCenter
              }
              Label {
                text: SysStats.down
                color: Theme.success
              }
              Icon {
                name: "arrow_upward"
                size: 14
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
              }
              Label {
                text: SysStats.up
                color: Theme.accent
              }
            }
          }

          Pill {
            active: ControlCenter.open && ControlCenter.side === "right"
            onClicked: ControlCenter.toggle("right")
            WheelSteps {
              onStepped: steps => Audio.step(steps * 0.05)
            }
            Icon {
              visible: Persist.dnd || Notifs.history.length > 0
              name: Persist.dnd ? "notifications_off" : "notifications_unread"
              size: 16
              color: Persist.dnd ? Theme.dim : Theme.accent
            }
            Icon {
              visible: Wifi.device !== null
              name: Wifi.icon
              size: 16
            }
            Icon {
              visible: ControlCenter.btOn
              name: ControlCenter.btConnected.length > 0 ? "bluetooth_connected" : "bluetooth"
              size: 16
            }
            Icon {
              visible: Audio.ok
              name: Audio.icon
              size: 16
              color: Audio.muted ? Theme.error : Theme.fg
            }
            Label {
              visible: Audio.ok && !Audio.muted
              anchors.verticalCenter: parent.verticalCenter
              text: Math.round(Audio.volume * 100) + "%"
            }
            Icon {
              visible: BarState.hasBat
              name: BarState.batIcon()
              size: 16
              rotation: 90
              color: BarState.batLow ? Theme.error : Theme.fg
            }
            Label {
              visible: BarState.hasBat
              anchors.verticalCenter: parent.verticalCenter
              text: BarState.batPct + "%"
              color: BarState.batLow ? Theme.error : Theme.fg
            }
          }

          Pill {
            visible: Weather.ok
            active: WeatherPanel.open
            onClicked: WeatherPanel.toggle()
            WeatherIcon {
              size: 16
            }
            Label {
              anchors.verticalCenter: parent.verticalCenter
              text: Weather.temp + "°"
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
                  const item = trayIcon.modelData;
                  if (mouse.button === Qt.MiddleButton) {
                    item.secondaryActivate();
                  } else if (item.hasMenu && (mouse.button === Qt.RightButton || item.onlyMenu)) {
                    const p = trayIcon.mapToItem(null, 0, trayIcon.height);
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
}
