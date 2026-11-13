import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes

// vertical bar on a screen edge, its popups open in the drawer below
Scope {
  id: root
  // mirrored onto the right edge
  property bool right: false
  readonly property var windows: rails.instances

  property bool entered: false
  property real presence: entered && !Style.leaving ? 1 : 0
  Behavior on presence {
    NumberAnimation {
      duration: Style.exitMs
      easing.type: Easing.InOutCubic
    }
  }
  Component.onCompleted: entered = true

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
  readonly property var next: Calendar.todayEntries.length > 0 ? Calendar.nextEntry(clock.date) : null

  component RailButton: Rectangle {
    id: btn
    default property alias content: col.data
    property bool active: false
    // opens this button's popup; set to make it peek on hover
    property var reveal: null
    signal clicked(var mouse)
    Layout.alignment: Qt.AlignHCenter
    implicitWidth: Theme.railWidth - 12
    implicitHeight: col.implicitHeight + 14
    radius: 14
    color: active ? Theme.bg2 : area.containsMouse ? Theme.bg1 : "transparent"
    border.width: active && !Popups.peek ? 1 : 0
    border.color: Theme.accent
    scale: area.pressed ? 0.92 : 1
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
    Column {
      id: col
      anchors.centerIn: parent
      spacing: 4
    }
    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      onClicked: mouse => {
        if (btn.active && Popups.peek && mouse.button === Qt.LeftButton)
          Popups.pin();
        else
          btn.clicked(mouse);
      }
      onContainsMouseChanged: {
        if (containsMouse && btn.reveal)
          hoverDelay.restart();
        else
          hoverDelay.stop();
      }
    }
    // a pinned popup is never replaced by hovering
    Timer {
      id: hoverDelay
      interval: 350
      onTriggered: {
        if (!btn.active && (Popups.current === "" || Popups.peek)) {
          Popups.peekNext = true;
          btn.reveal();
        }
      }
    }
  }

  // concave fillet joining the drawer to the rail, flipped per joint and side
  component Ear: Shape {
    id: ear
    property real size: 18
    property bool flipX: false
    property bool flipY: false
    property color fill: Theme.bg
    width: size
    height: size
    preferredRendererType: Shape.CurveRenderer
    transform: Scale {
      origin.x: ear.size / 2
      origin.y: ear.size / 2
      xScale: ear.flipX ? -1 : 1
      yScale: ear.flipY ? -1 : 1
    }
    ShapePath {
      fillColor: ear.fill
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

  Variants {
    id: rails
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData

      // the drawer only shows on the screen the popup was opened on
      readonly property var target: Popups.screen || Focus.screen
      readonly property bool hosting: !!target && target.name === modelData.name
      // x of the rail's edge facing the screen
      readonly property real inner: root.right ? width - Theme.railWidth : Theme.railWidth
      readonly property real outward: root.right ? 1 : -1

      anchors {
        top: true
        bottom: true
        left: !root.right
        right: root.right
      }
      // the window is wide enough for the drawer but only reserves the rail
      exclusiveZone: Theme.railWidth
      implicitWidth: Theme.railWidth + Theme.popupWidth + 24
      color: "transparent"
      WlrLayershell.keyboardFocus: !(hosting && Popups.current !== "" && !Popups.peek) ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
      mask: Region {
        item: railBox
        Region {
          item: drawer
        }
        Region {
          item: fly.visible ? fly : null
        }
      }

      function opener(name) {
        if (name === "cc")
          return ControlCenter.side === "left" ? tuneBtn : statusBtn;
        if (name === "sysinfo")
          return statsBtn;
        if (name === "calendar")
          return clockBtn;
        if (name === "media")
          return mediaBtn;
        if (name === "weather")
          return weatherBtn;
        return null;
      }
      // in window coordinates; the y reads keep it live when the column relayouts
      function centerOf(name) {
        const it = opener(name);
        if (!it || !it.visible)
          return height / 2;
        return column.y + it.y + it.height / 2;
      }

      onHostingChanged: claim()
      Component.onCompleted: claim()
      function claim() {
        if (hosting)
          Popups.locate = name => win.centerOf(name);
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
        value: "y"
      }

      // workspace preview flyout: the hovered id, and the one shown (held while it fades)
      property int wsHover: 0
      property int previewWs: 0
      onWsHoverChanged: {
        if (wsHover > 0 && previewWs > 0)
          previewWs = wsHover;
        else if (wsHover > 0)
          wsOpen.restart();
        else {
          wsOpen.stop();
          wsClose.restart();
        }
      }
      Timer {
        id: wsOpen
        interval: 300
        onTriggered: win.previewWs = win.wsHover
      }
      Timer {
        id: wsClose
        interval: 250
        onTriggered: {
          if (win.wsHover === 0 && !flyHover.hovered)
            win.previewWs = 0;
        }
      }

      // a peek closes once the pointer leaves the rail and drawer
      Timer {
        interval: 350
        running: win.hosting && Popups.peek && !winHover.hovered
        onTriggered: Popups.close(Popups.current)
      }

      Item {
        id: body
        anchors.fill: parent
        transform: Translate {
          x: (1 - root.presence) * win.outward * (Theme.railWidth + 40)
        }

        HoverHandler {
          id: winHover
        }

        // the rail, drawer and ears: the mask for the frosted wallpaper and its tint. sources stay
        // visible and are hidden by their ShaderEffectSource, since a hidden layer can go stale
        Item {
          id: surface
          anchors.fill: parent

          Rectangle {
            x: root.right ? win.inner : 0
            width: Theme.railWidth
            height: parent.height
            color: Theme.bg
          }
          Rectangle {
            x: drawer.x
            y: drawer.y
            width: drawer.width
            height: drawer.height
            color: Theme.bg
            topLeftRadius: root.right ? 22 : 0
            bottomLeftRadius: root.right ? 22 : 0
            topRightRadius: root.right ? 0 : 22
            bottomRightRadius: root.right ? 0 : 22
          }
          Ear {
            flipX: root.right
            x: root.right ? win.inner + 1 - size : win.inner - 1
            y: drawer.y - size
            size: Math.min(18, drawer.width)
          }
          Ear {
            flipX: root.right
            flipY: true
            x: root.right ? win.inner + 1 - size : win.inner - 1
            y: drawer.y + drawer.height
            size: Math.min(18, drawer.width)
          }
        }

        // the wallpaper under this window, decoded small since it is blurred anyway
        Item {
          id: wallSlice
          anchors.fill: parent
          Image {
            id: wall
            x: root.right ? win.width - win.modelData.width : 0
            width: win.modelData.width
            height: win.modelData.height
            source: Wallpapers.url(Persist.wallpaper)
            sourceSize: Qt.size(win.modelData.width / 4, win.modelData.height / 4)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
          }
        }
        ShaderEffectSource {
          id: wallTex
          anchors.fill: parent
          visible: false
          sourceItem: wallSlice
          hideSource: true
        }
        MultiEffect {
          anchors.fill: parent
          visible: wall.status === Image.Ready
          source: wallTex
          // padding would stretch the mask past the shapes it cuts out
          autoPaddingEnabled: false
          blurEnabled: true
          blur: 1
          blurMax: 48
          saturation: 0.2
          maskEnabled: true
          maskSource: surfaceTex
        }
        ShaderEffectSource {
          id: surfaceTex
          anchors.fill: parent
          sourceItem: surface
          hideSource: true
          opacity: wall.status === Image.Ready ? 0.8 : 1
        }

        Item {
          id: railBox
          x: root.right ? win.inner : 0
          width: Theme.railWidth
          height: parent.height

          Rectangle {
            x: root.right ? 0 : parent.width - 1
            width: 1
            height: parent.height
            color: Theme.bg1
            opacity: 0.6
          }

          // points at whatever opened the drawer and rides along with it
          Rectangle {
            x: root.right ? parent.width - 3 : 0
            y: drawer.center - height / 2
            width: 3
            height: 22
            radius: 1.5
            color: Theme.accent
            opacity: drawer.reveal
            Behavior on y {
              enabled: drawer.reveal > 0
              NumberAnimation {
                duration: 450
                easing.type: Easing.OutBack
              }
            }
          }

          ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 6

            RailButton {
              id: tuneBtn
              active: ControlCenter.open && ControlCenter.side === "left"
              reveal: () => ControlCenter.show("left")
              onClicked: ControlCenter.toggle("left")
              Icon {
                name: "tune"
                size: 20
                color: Theme.accent
              }
            }

            Rectangle {
              Layout.alignment: Qt.AlignHCenter
              implicitWidth: 20
              implicitHeight: 1
              color: Theme.bg2
            }

            // the indicator's edges move at different speeds, so it stretches toward the target and catches up
            Item {
              id: wsBox
              readonly property int cell: 30
              property real head: 0
              property real tail: cell
              Layout.alignment: Qt.AlignHCenter
              implicitWidth: 36
              implicitHeight: BarState.wsCount * cell

              function follow(animate) {
                const i = BarState.focusedWs - 1;
                if (i < 0)
                  return;
                const t = i * cell, down = t > head;
                headAnim.stop();
                tailAnim.stop();
                if (!animate) {
                  head = t;
                  tail = t + cell;
                  return;
                }
                headAnim.to = t;
                tailAnim.to = t + cell;
                headAnim.duration = down ? 420 : 180;
                tailAnim.duration = down ? 180 : 420;
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
                onStepped: steps => BarState.focusWs(BarState.focusedWs - steps)
              }

              Rectangle {
                visible: BarState.focusedWs > 0
                x: 3
                y: wsBox.head
                width: 30
                height: wsBox.tail - wsBox.head
                radius: 15
                color: Theme.accent
              }

              Column {
                Repeater {
                  model: BarState.wsCount
                  Item {
                    id: ws
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property bool isActive: BarState.focusedWs === wsId
                    readonly property bool isBusy: BarState.wsIds.includes(wsId)
                    width: 36
                    height: wsBox.cell
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
                      onContainsMouseChanged: {
                        if (containsMouse)
                          win.wsHover = ws.wsId;
                        else if (win.wsHover === ws.wsId)
                          win.wsHover = 0;
                      }
                    }
                  }
                }
              }
            }

            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              Label {
                id: title
                anchors.centerIn: parent
                width: parent.height - 24
                rotation: root.right ? 90 : -90
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: BarState.winTitle
                color: Theme.dim
                font.pixelSize: Theme.fontSizeSmall
                Behavior on text {
                  SequentialAnimation {
                    NumberAnimation {
                      target: title
                      property: "opacity"
                      to: 0
                      duration: 90
                    }
                    PropertyAction {}
                    NumberAnimation {
                      target: title
                      property: "opacity"
                      to: 1
                      duration: 160
                    }
                  }
                }
              }
            }

            RailButton {
              visible: Recorder.active
              onClicked: Recorder.toggle()
              Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 10
                height: 10
                radius: 5
                color: Theme.error
                SequentialAnimation on opacity {
                  running: Recorder.active
                  loops: Animation.Infinite
                  NumberAnimation {
                    to: 0.25
                    duration: 700
                    easing.type: Easing.InOutSine
                  }
                  NumberAnimation {
                    to: 1
                    duration: 700
                    easing.type: Easing.InOutSine
                  }
                }
              }
              Caption {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.floor(Recorder.elapsed / 60) + ":" + String(Recorder.elapsed % 60).padStart(2, "0")
                color: Theme.error
              }
            }

            RailButton {
              id: mediaBtn
              readonly property var player: Media.player
              visible: player !== null
              active: MediaPanel.open
              reveal: () => MediaPanel.show()
              onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                  player.next();
                else if (mouse.button === Qt.MiddleButton)
                  player.togglePlaying();
                else
                  MediaPanel.toggle();
              }
              Ring {
                anchors.horizontalCenter: parent.horizontalCenter
                fill: Theme.secondary
                value: mediaBtn.player && mediaBtn.player.lengthSupported && mediaBtn.player.length > 0 ? mediaBtn.player.position / mediaBtn.player.length : 0
                ClippingRectangle {
                  anchors.centerIn: parent
                  width: 24
                  height: 24
                  radius: 12
                  color: Theme.bg2
                  NumberAnimation on rotation {
                    running: mediaBtn.player !== null
                    paused: running && !(mediaBtn.player && mediaBtn.player.isPlaying)
                    from: 0
                    to: 360
                    duration: 9000
                    loops: Animation.Infinite
                  }
                  Image {
                    id: cover
                    anchors.fill: parent
                    source: mediaBtn.player ? mediaBtn.player.trackArtUrl : ""
                    sourceSize: Qt.size(48, 48)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                  }
                  Icon {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    name: "music_note"
                    size: 14
                    color: Theme.secondary
                  }
                }
              }
            }

            RailButton {
              id: statsBtn
              active: SysInfo.open
              reveal: () => SysInfo.show()
              onClicked: SysInfo.toggle()
              Ring {
                anchors.horizontalCenter: parent.horizontalCenter
                fill: Theme.info
                value: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal : 0
                Icon {
                  anchors.centerIn: parent
                  name: "memory"
                  size: 15
                  color: Theme.info
                }
              }
              Caption {
                anchors.horizontalCenter: parent.horizontalCenter
                text: SysStats.load
                color: Theme.info
                font.pixelSize: Theme.fontSizeSmall - 1
              }
            }

            RailButton {
              id: statusBtn
              active: ControlCenter.open && ControlCenter.side === "right"
              reveal: () => ControlCenter.show("right")
              onClicked: ControlCenter.toggle("right")
              WheelSteps {
                onStepped: steps => Audio.step(steps * 0.05)
              }
              Icon {
                id: bell
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Persist.dnd || Notifs.history.length > 0
                name: Persist.dnd ? "notifications_off" : "notifications_unread"
                size: 16
                color: Persist.dnd ? Theme.dim : Theme.accent
              }
              Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Wifi.device !== null
                name: Wifi.icon
                size: 16
              }
              Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: ControlCenter.btOn
                name: ControlCenter.btConnected.length > 0 ? "bluetooth_connected" : "bluetooth"
                size: 16
              }
              Ring {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Audio.ok
                value: Audio.muted ? 0 : Audio.volume
                fill: Theme.fg
                Icon {
                  anchors.centerIn: parent
                  name: Audio.icon
                  size: 15
                  color: Audio.muted ? Theme.error : Theme.fg
                }
              }
              Ring {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: BarState.hasBat
                value: BarState.batPct / 100
                fill: BarState.batLow ? Theme.error : BarState.charging ? Theme.success : Theme.fg
                Label {
                  anchors.centerIn: parent
                  text: BarState.charging ? "" : BarState.batPct
                  font.pixelSize: 10
                  font.bold: true
                }
                Icon {
                  anchors.centerIn: parent
                  visible: BarState.charging
                  name: "bolt"
                  size: 15
                  color: Theme.success
                }
              }
            }

            RailButton {
              id: clockBtn
              active: Calendar.open
              reveal: () => Calendar.show()
              onClicked: Calendar.toggle()
              Column {
                anchors.horizontalCenter: parent.horizontalCenter
                Label {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: Qt.formatDateTime(clock.date, "hh")
                  font.pixelSize: Theme.fontSize + 4
                  font.bold: true
                }
                Label {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: Qt.formatDateTime(clock.date, "mm")
                  font.pixelSize: Theme.fontSize + 4
                  font.bold: true
                  color: Theme.accent
                }
              }
              Caption {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "ddd d")
                font.pixelSize: Theme.fontSizeSmall - 1
              }
              // fills over the last two hours before the next event today
              Ring {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.next !== null && root.next.minutes <= 120
                implicitWidth: 30
                implicitHeight: 30
                value: root.next ? 1 - root.next.minutes / 120 : 0
                fill: root.next && root.next.minutes <= 10 ? Theme.warning : Theme.tertiary
                Label {
                  anchors.centerIn: parent
                  text: !root.next ? "" : root.next.minutes < 60 ? Math.ceil(root.next.minutes) + "m" : Math.floor(root.next.minutes / 60) + "h"
                  font.pixelSize: 9
                  font.bold: true
                }
              }
            }

            RailButton {
              id: weatherBtn
              visible: Weather.ok
              active: WeatherPanel.open
              reveal: () => WeatherPanel.show()
              onClicked: WeatherPanel.toggle()
              WeatherIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 20
              }
              Caption {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Weather.temp + "°"
                color: Theme.fg
              }
            }

            Column {
              Layout.alignment: Qt.AlignHCenter
              visible: SystemTray.items.values.length > 0
              spacing: 8
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
                        const p = trayIcon.mapToItem(null, root.right ? 0 : trayIcon.width, 0);
                        item.display(win, p.x, p.y);
                      } else {
                        item.activate();
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // a new notification sends rings out of the bell
        Item {
          id: pulse
          readonly property point at: statusBtn.mapToItem(body, statusBtn.width / 2, bell.visible ? bell.y + 7 + bell.height / 2 : statusBtn.height / 2)
          x: at.x
          y: at.y
          property int seen: Notifs.popups.length
          Connections {
            target: Notifs
            function onPopupsChanged() {
              if (Notifs.popups.length > pulse.seen)
                ripple.restart();
              pulse.seen = Notifs.popups.length;
            }
          }
          ParallelAnimation {
            id: ripple
            SequentialAnimation {
              RotationAnimation {
                target: bell
                to: 18
                duration: 80
              }
              RotationAnimation {
                target: bell
                to: -14
                duration: 120
              }
              RotationAnimation {
                target: bell
                to: 8
                duration: 110
              }
              RotationAnimation {
                target: bell
                to: 0
                duration: 120
              }
            }
            Wave {
              target: ringA
            }
            Wave {
              target: ringB
              delay: 180
            }
          }
          component Wave: SequentialAnimation {
            id: wave
            property Item target
            property int delay: 0
            PauseAnimation {
              duration: wave.delay
            }
            ParallelAnimation {
              NumberAnimation {
                target: wave.target
                property: "scale"
                from: 0.3
                to: 3.2
                duration: 900
                easing.type: Easing.OutCubic
              }
              NumberAnimation {
                target: wave.target
                property: "opacity"
                from: 0.9
                to: 0
                duration: 900
                easing.type: Easing.InQuad
              }
            }
          }
          component Ring2: Rectangle {
            x: -width / 2
            y: -height / 2
            width: 28
            height: 28
            radius: 14
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
            opacity: 0
          }
          Ring2 {
            id: ringA
          }
          Ring2 {
            id: ringB
          }
        }

        // the shared popup drawer, one surface for every popup so switching reshapes it
        Item {
          id: drawer
          readonly property Item page: win.hosting ? Popups.pages[Popups.current] || null : null
          // held while collapsing, so it closes in place
          property real fullH: 200
          property real center: 0
          Binding on fullH {
            when: drawer.page !== null
            value: drawer.page ? drawer.page.height + 32 : 0
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

          readonly property real margin: 10
          x: root.right ? win.inner + 1 - width : win.inner - 1
          y: Math.max(margin, Math.min(win.height - fullH - margin, center - fullH / 2))
          width: (Theme.popupWidth + 1) * reveal
          height: fullH
          visible: reveal > 0
          clip: true
          // only animate moves while it is out, a fresh open lands in place
          Behavior on y {
            enabled: drawer.reveal > 0
            NumberAnimation {
              duration: 460
              easing.type: Easing.OutBack
              easing.overshoot: 0.9
            }
          }
          Behavior on height {
            enabled: drawer.reveal > 0
            NumberAnimation {
              duration: 380
              easing.type: Easing.OutCubic
            }
          }

          PointHandler {
            onActiveChanged: {
              if (active && Popups.peek)
                Popups.pin();
            }
          }

          // pinned to the drawer's moving edge so pages slide out with it
          Item {
            id: stage
            x: root.right ? 0 : drawer.width - Theme.popupWidth
            width: Theme.popupWidth
            height: drawer.height
          }
        }

        // windows on the hovered workspace
        Rectangle {
          id: fly
          property int wsId: 0
          Binding on wsId {
            when: win.previewWs > 0
            value: win.previewWs
            restoreMode: Binding.RestoreNone
          }
          readonly property var toplevels: BarState.windows.filter(w => w.wsId === fly.wsId)
          property real shown: win.previewWs > 0 ? 1 : 0
          Behavior on shown {
            NumberAnimation {
              duration: 200
              easing.type: Easing.OutCubic
            }
          }
          property real center: 0
          Binding on center {
            when: win.previewWs > 0
            value: column.y + wsBox.y + (win.previewWs - 0.5) * wsBox.cell
            restoreMode: Binding.RestoreNone
          }
          Behavior on center {
            enabled: fly.shown > 0
            NumberAnimation {
              duration: 220
              easing.type: Easing.OutCubic
            }
          }

          visible: shown > 0
          opacity: shown
          width: 240
          height: flyCol.implicitHeight + 20
          x: (root.right ? win.inner - width - 8 : win.inner + 8) + (1 - shown) * win.outward * 14
          y: Math.max(8, center - height / 2)
          radius: 14
          color: Theme.bg
          border.width: 1
          border.color: Theme.bg2

          HoverHandler {
            id: flyHover
            onHoveredChanged: {
              if (!hovered)
                wsClose.restart();
            }
          }

          Column {
            id: flyCol
            x: 10
            y: 10
            width: parent.width - 20
            spacing: 2
            Caption {
              leftPadding: 4
              bottomPadding: 4
              text: "Workspace " + fly.wsId
              font.bold: true
            }
            Caption {
              visible: fly.toplevels.length === 0
              leftPadding: 4
              text: "Empty"
            }
            Repeater {
              model: fly.toplevels
              Rectangle {
                id: winRow
                required property var modelData
                readonly property string appId: modelData.appId
                readonly property var entry: appId ? DesktopEntries.heuristicLookup(appId) : null
                width: flyCol.width
                height: 32
                radius: 8
                color: rowMouse.containsMouse ? Theme.bg1 : "transparent"
                Row {
                  anchors.fill: parent
                  anchors.leftMargin: 6
                  spacing: 8
                  IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 18
                    visible: !!winRow.entry
                    source: winRow.entry ? Quickshell.iconPath(winRow.entry.icon, true) : ""
                  }
                  Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !winRow.entry
                    name: "web_asset"
                    size: 18
                    color: Theme.dim
                  }
                  Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 40
                    elide: Text.ElideRight
                    text: winRow.modelData.title || winRow.appId
                    color: winRow.modelData.focused ? Theme.accent : Theme.fg
                  }
                }
                MouseArea {
                  id: rowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    BarState.focusWindow(winRow.modelData.address);
                    win.previewWs = 0;
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
