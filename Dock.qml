import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

// floating dock at the bottom of each screen, popups rise out of it
Scope {
  id: root

  readonly property var windows: docks.instances

  // one entry per toplevel, shared by every screen
  readonly property var wins: {
    const out = [];
    for (const w of BarState.windows)
      if (w.appId !== "")
        out.push({ appId: w.appId, address: w.address, active: w.focused });
    return out;
  }
  // delegates are keyed by this, so focus changes don't rebuild the icons
  readonly property string sig: {
    const ids = [];
    for (const w of wins)
      if (!ids.includes(w.appId))
        ids.push(w.appId);
    return ids.join("\n");
  }
  property var apps: []
  onSigChanged: apps = sig === "" ? [] : sig.split("\n")
  Component.onCompleted: apps = sig === "" ? [] : sig.split("\n")

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  // concave fillet joining the drawer to the dock
  component Ear: Shape {
    id: ear
    property real size: 18
    property bool mirror: false
    width: size
    height: size
    preferredRendererType: Shape.CurveRenderer
    transform: Scale {
      origin.x: ear.size / 2
      xScale: ear.mirror ? -1 : 1
    }
    ShapePath {
      fillColor: Theme.bg
      strokeWidth: -1
      startX: 0
      startY: 0
      PathLine {
        x: 0
        y: ear.size
      }
      PathLine {
        x: ear.size
        y: ear.size
      }
      PathArc {
        x: 0
        y: 0
        radiusX: ear.size
        radiusY: ear.size
      }
    }
  }

  component DockButton: Rectangle {
    id: btn
    default property alias content: row.data
    property bool active: false
    signal clicked(var mouse)
    implicitWidth: row.implicitWidth + 18
    implicitHeight: 40
    radius: 14
    color: active ? Theme.bg2 : area.containsMouse ? Theme.bg1 : "transparent"
    border.width: active ? 1 : 0
    border.color: Theme.accent
    scale: area.pressed ? 0.94 : 1
    Behavior on color {
      ColorAnimation {
        duration: 150
      }
    }
    Behavior on scale {
      NumberAnimation {
        duration: 120
        easing.type: Easing.OutCubic
      }
    }
    Row {
      id: row
      anchors.centerIn: parent
      spacing: 6
    }
    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      onClicked: mouse => btn.clicked(mouse)
    }
  }

  component Sep: Rectangle {
    width: 1
    height: 24
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    color: Theme.bg2
  }

  Variants {
    id: docks
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData

      readonly property int dockH: 58
      readonly property int gap: 8
      readonly property int dockRadius: 22
      readonly property int ear: 18

      readonly property var target: Popups.screen || Focus.screen
      readonly property bool hosting: !!target && target.name === modelData.name

      // 0 while off screen, bound to the style swap
      property bool loaded: false
      property real presence: 0
      Behavior on presence {
        NumberAnimation {
          duration: 340
          easing.type: Easing.OutCubic
        }
      }
      Binding {
        target: win
        property: "presence"
        value: win.loaded && !Style.leaving ? 1 : 0
      }

      anchors {
        bottom: true
        left: true
        right: true
      }
      exclusiveZone: dockH + gap
      implicitHeight: Math.min(modelData.height, 900)
      color: "transparent"
      WlrLayershell.keyboardFocus: !(hosting && Popups.current !== "" && !Popups.peek) ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
      mask: Region {
        item: dock
        Region {
          item: drawer
        }
        Region {
          item: earL
        }
        Region {
          item: earR
        }
      }

      function opener(name) {
        if (name === "cc")
          return ControlCenter.side === "left" ? tuneBtn : statusBtn;
        if (name === "sysinfo")
          return statsBtn;
        if (name === "calendar")
          return clockBtn;
        if (name === "weather")
          return weatherBtn;
        return null;
      }
      // in holder coordinates; the reads keep it live when the row relayouts
      function centerOf(name) {
        const it = opener(name);
        if (!it || !it.visible)
          return holder.width / 2;
        return dock.x + row.x + it.x + it.width / 2;
      }

      Binding {
        when: win.hosting
        target: Popups
        property: "stage"
        value: stage
      }
      Binding {
        when: win.hosting
        target: Popups
        property: "drawerShown"
        value: drawer.visible
      }
      Binding {
        when: win.hosting
        target: Popups
        property: "axis"
        value: "x"
      }
      onHostingChanged: claim()
      Component.onCompleted: {
        loaded = true;
        claim();
      }
      function claim() {
        if (hosting)
          Popups.locate = name => win.centerOf(name);
      }

      Item {
        id: holder
        width: parent.width
        height: parent.height
        // slides below the screen edge, taking an open drawer along
        y: (1 - win.presence) * (win.dockH + win.gap + (drawer.visible ? drawer.height : 0) + 8)

        Rectangle {
          id: dock
          width: row.implicitWidth + 24
          height: win.dockH
          x: (holder.width - width) / 2
          y: holder.height - win.gap - height
          radius: win.dockRadius
          color: Theme.bg

          Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            DockButton {
              id: tuneBtn
              anchors.verticalCenter: parent.verticalCenter
              active: ControlCenter.open && ControlCenter.side === "left"
              onClicked: ControlCenter.toggle("left")
              Icon {
                name: "tune"
                size: 20
                color: Theme.accent
              }
            }

            // stretches like Rail's workspace indicator
            Item {
              id: wsBox
              readonly property int cell: 28
              property real head: 0
              property real tail: cell
              anchors.verticalCenter: parent.verticalCenter
              implicitWidth: BarState.wsCount * cell
              width: implicitWidth
              height: 40

              function follow(animate) {
                const i = BarState.focusedWs - 1;
                if (i < 0)
                  return;
                const t = i * cell, fwd = t > head;
                headAnim.stop();
                tailAnim.stop();
                if (!animate) {
                  head = t;
                  tail = t + cell;
                  return;
                }
                headAnim.to = t;
                tailAnim.to = t + cell;
                headAnim.duration = fwd ? 420 : 180;
                tailAnim.duration = fwd ? 180 : 420;
                headAnim.start();
                tailAnim.start();
              }
              Component.onCompleted: follow(false)
              Connections {
                target: BarState
                function onFocusedWsChanged() {
                  wsBox.follow(true);
                }
              }
              NumberAnimation {
                id: headAnim
                target: wsBox
                property: "head"
                easing.type: Easing.OutCubic
              }
              NumberAnimation {
                id: tailAnim
                target: wsBox
                property: "tail"
                easing.type: Easing.OutCubic
              }
              WheelSteps {
                anyAxis: true
                onStepped: steps => BarState.focusWs(BarState.focusedWs - steps)
              }

              Rectangle {
                visible: BarState.focusedWs > 0
                x: wsBox.head + 1
                y: (parent.height - height) / 2
                width: wsBox.tail - wsBox.head - 2
                height: 26
                radius: 13
                color: Theme.accent
              }

              Row {
                Repeater {
                  model: BarState.wsCount
                  Item {
                    id: ws
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property bool isActive: BarState.focusedWs === wsId
                    readonly property bool isBusy: BarState.wsIds.includes(wsId)
                    width: wsBox.cell
                    height: wsBox.height
                    Label {
                      anchors.centerIn: parent
                      visible: ws.isActive || ws.isBusy || wsMouse.containsMouse
                      text: ws.wsId
                      color: ws.isActive ? Theme.accentFg : wsMouse.containsMouse ? Theme.accent : Theme.fg
                      font.bold: ws.isActive
                      Behavior on color {
                        ColorAnimation {
                          duration: 150
                        }
                      }
                    }
                    Rectangle {
                      anchors.centerIn: parent
                      visible: !ws.isActive && !ws.isBusy && !wsMouse.containsMouse
                      width: 5
                      height: 5
                      radius: 2.5
                      color: Theme.dim
                    }
                    MouseArea {
                      id: wsMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: BarState.focusWs(ws.wsId)
                    }
                  }
                }
              }
            }

            Sep {}

            // running apps, grouped by appId; icons swell toward the pointer
            Item {
              id: appsBox
              readonly property int slot: 42
              property real hoverX: hv.hovered ? hv.point.position.x : -1000
              anchors.verticalCenter: parent.verticalCenter
              visible: root.apps.length > 0
              width: root.apps.length * slot
              height: win.dockH - 8

              HoverHandler {
                id: hv
              }

              Row {
                Repeater {
                  model: root.apps
                  Item {
                    id: app
                    required property string modelData
                    required property int index
                    readonly property var group: root.wins.filter(w => w.appId === modelData)
                    readonly property bool focused: group.some(w => w.active)
                    readonly property var entry: DesktopEntries.heuristicLookup(modelData)
                    readonly property string iconSrc: entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
                    readonly property real near: Math.max(0, Math.cos(Math.min(Math.abs(appsBox.hoverX - (x + width / 2)) / 84, 1) * Math.PI / 2))
                    width: appsBox.slot
                    height: appsBox.height

                    Item {
                      id: face
                      width: 28
                      height: 28
                      x: (parent.width - width) / 2
                      y: parent.height - 14 - height
                      transformOrigin: Item.Bottom
                      scale: 1 + 0.45 * app.near
                      Behavior on scale {
                        NumberAnimation {
                          duration: 110
                          easing.type: Easing.OutCubic
                        }
                      }
                      Image {
                        id: img
                        anchors.fill: parent
                        visible: status === Image.Ready
                        source: app.iconSrc
                        sourceSize: Qt.size(56, 56)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                      }
                      Rectangle {
                        anchors.fill: parent
                        visible: !img.visible
                        radius: 9
                        color: Theme.bg2
                        Label {
                          anchors.centerIn: parent
                          text: app.modelData.length > 0 ? app.modelData.split(".").pop().charAt(0).toUpperCase() : "?"
                          font.bold: true
                          color: Theme.accent
                        }
                      }
                    }

                    Rectangle {
                      anchors.horizontalCenter: parent.horizontalCenter
                      y: parent.height - 9
                      height: 4
                      width: app.focused ? 14 : 4
                      radius: 2
                      color: app.focused ? Theme.accent : Theme.dim
                      Behavior on width {
                        NumberAnimation {
                          duration: 200
                          easing.type: Easing.OutCubic
                        }
                      }
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        const g = app.group;
                        if (g.length === 0)
                          return;
                        const i = g.findIndex(w => w.active);
                        BarState.focusWindow(g[(i + 1) % g.length].address);
                      }
                    }
                  }
                }
              }
            }

            Sep {
              visible: root.apps.length > 0
            }

            DockButton {
              id: statsBtn
              anchors.verticalCenter: parent.verticalCenter
              active: SysInfo.open
              onClicked: SysInfo.toggle()
              Ring {
                width: 28
                height: 28
                fill: Theme.info
                value: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal : 0
                Icon {
                  anchors.centerIn: parent
                  name: "memory"
                  size: 14
                  color: Theme.info
                }
              }
            }

            DockButton {
              id: statusBtn
              anchors.verticalCenter: parent.verticalCenter
              active: ControlCenter.open && ControlCenter.side === "right"
              onClicked: ControlCenter.toggle("right")
              WheelSteps {
                parent: statusBtn
                anyAxis: true
                onStepped: steps => Audio.step(steps * 0.05)
              }
              Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: Persist.dnd || Notifs.history.length > 0
                name: Persist.dnd ? "notifications_off" : "notifications_unread"
                size: 16
                color: Persist.dnd ? Theme.dim : Theme.accent
              }
              Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: Wifi.device !== null
                name: Wifi.icon
                size: 16
              }
              Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: ControlCenter.btOn
                name: ControlCenter.btConnected.length > 0 ? "bluetooth_connected" : "bluetooth"
                size: 16
              }
              Ring {
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                visible: Audio.ok
                value: Audio.muted ? 0 : Audio.volume
                fill: Theme.fg
                Icon {
                  anchors.centerIn: parent
                  name: Audio.icon
                  size: 14
                  color: Audio.muted ? Theme.error : Theme.fg
                }
              }
              Ring {
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                visible: BarState.hasBat
                value: BarState.batPct / 100
                fill: BarState.batLow ? Theme.error : BarState.charging ? Theme.success : Theme.fg
                Label {
                  anchors.centerIn: parent
                  text: BarState.charging ? "" : BarState.batPct
                  font.pixelSize: 9
                  font.bold: true
                }
                Icon {
                  anchors.centerIn: parent
                  visible: BarState.charging
                  name: "bolt"
                  size: 14
                  color: Theme.success
                }
              }
            }

            DockButton {
              id: weatherBtn
              anchors.verticalCenter: parent.verticalCenter
              visible: Weather.ok
              active: WeatherPanel.open
              onClicked: WeatherPanel.toggle()
              Row {
                spacing: 4
                WeatherIcon {
                  anchors.verticalCenter: parent.verticalCenter
                  size: 18
                }
                Label {
                  anchors.verticalCenter: parent.verticalCenter
                  text: Weather.temp + "°"
                }
              }
            }

            DockButton {
              id: clockBtn
              anchors.verticalCenter: parent.verticalCenter
              active: Calendar.open
              onClicked: Calendar.toggle()
              Column {
                Label {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: Qt.formatDateTime(clock.date, "hh:mm")
                  font.bold: true
                }
                Caption {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: Qt.formatDateTime(clock.date, "ddd d")
                  font.pixelSize: Theme.fontSizeSmall - 1
                }
              }
            }
          }
        }

        // the popup drawer, as in Rail
        Item {
          id: drawer
          readonly property Item page: win.hosting ? Popups.pages[Popups.current] || null : null
          property real fullH: 200
          property real center: 0
          Binding on fullH {
            when: drawer.page !== null
            value: drawer.page ? Math.min(drawer.page.height + 32, holder.height - win.dockH - win.gap - 12) : 0
            restoreMode: Binding.RestoreNone
          }
          Binding on center {
            when: drawer.page !== null
            value: drawer.page ? win.centerOf(Popups.current) : 0
            restoreMode: Binding.RestoreNone
          }

          property real reveal: page !== null ? 1 : 0
          Behavior on reveal {
            NumberAnimation {
              duration: 340
              easing.type: Easing.OutCubic
            }
          }

          readonly property real edge: win.dockRadius + win.ear
          readonly property real lo: Math.max(10, dock.x + edge)
          readonly property real hi: Math.min(holder.width - width - 10, dock.x + dock.width - edge - width)
          width: Theme.popupWidth
          height: fullH * reveal
          x: hi < lo ? (holder.width - width) / 2 : Math.max(lo, Math.min(hi, center - width / 2))
          y: dock.y + 1 - height
          visible: reveal > 0
          clip: true
          Behavior on x {
            enabled: drawer.reveal > 0
            NumberAnimation {
              duration: 460
              easing.type: Easing.OutBack
              easing.overshoot: 0.9
            }
          }
          Behavior on fullH {
            enabled: drawer.reveal > 0
            NumberAnimation {
              duration: 380
              easing.type: Easing.OutCubic
            }
          }

          Rectangle {
            anchors.fill: parent
            color: Theme.bg
            topLeftRadius: 22
            topRightRadius: 22
          }

          // pinned to the drawer's moving top edge so pages rise with it
          Item {
            id: stage
            width: Theme.popupWidth
            height: drawer.fullH
          }
        }

        Ear {
          id: earL
          visible: drawer.visible
          mirror: true
          size: Math.min(win.ear, drawer.height)
          x: drawer.x - size
          y: dock.y + 1 - size
        }
        Ear {
          id: earR
          visible: drawer.visible
          size: Math.min(win.ear, drawer.height)
          x: drawer.x + drawer.width
          y: dock.y + 1 - size
        }
      }
    }
  }
}
