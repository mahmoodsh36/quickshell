import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

// a floating pill at the top center that morphs into activities and into the popup drawer
Scope {
  id: root

  readonly property var windows: islands.instances

  readonly property int barH: Theme.barHeight
  readonly property int gap: 6

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  // transient faces: "level" after a volume/brightness change, "notif" for a new notification
  property string flash: ""
  property string levelKind: "volume"
  property var notif: null
  property int seenPopups: 0

  function showFlash(kind) {
    flash = kind;
    flashTimer.interval = kind === "notif" ? 3200 : 1600;
    flashTimer.restart();
  }
  Timer {
    id: flashTimer
    onTriggered: root.flash = ""
  }
  // pipewire and the first backlight read report their values at startup
  Timer {
    id: settled
    property bool ready: false
    interval: 2000
    running: true
    onTriggered: ready = true
  }
  function level(kind) {
    if (!settled.ready || Popups.current !== "")
      return;
    levelKind = kind;
    showFlash("level");
  }
  Connections {
    target: Audio
    function onVolumeChanged() {
      root.level("volume");
    }
    function onMutedChanged() {
      root.level("volume");
    }
  }
  Connections {
    target: Brightness
    function onValueChanged() {
      root.level("brightness");
    }
  }
  Connections {
    target: Notifs
    function onPopupsChanged() {
      const n = Notifs.popups[0];
      if (Notifs.popups.length > root.seenPopups && n && n !== root.notif) {
        root.notif = n;
        if (Popups.current === "")
          root.showFlash("notif");
      }
      root.seenPopups = Notifs.popups.length;
    }
  }

  readonly property bool levelVolume: levelKind === "volume"
  readonly property real levelValue: levelVolume ? Audio.volume : Brightness.value
  readonly property bool levelMuted: levelVolume && Audio.muted

  component Part: Rectangle {
    id: part
    default property alias content: row.data
    property bool active: false
    signal clicked(var mouse)
    implicitWidth: row.implicitWidth + 12
    implicitHeight: 26
    radius: 13
    color: active ? Theme.bg2 : area.containsMouse ? Theme.bg1 : "transparent"
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
    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      onClicked: mouse => part.clicked(mouse)
    }
    Row {
      id: row
      anchors.centerIn: parent
      spacing: 5
    }
  }

  // a face of the pill; shown ones fade and scale in, the rest drift out
  component Face: Item {
    property bool shown: false
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.85
    visible: opacity > 0
    Behavior on opacity {
      NumberAnimation {
        duration: 200
        easing.type: Easing.OutCubic
      }
    }
    Behavior on scale {
      NumberAnimation {
        duration: 320
        easing.type: Easing.OutBack
      }
    }
  }

  Variants {
    id: islands
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData

      readonly property var target: Popups.screen || Focus.screen
      readonly property bool hosting: !!target && target.name === modelData.name
      readonly property int topGap: 6

      anchors {
        top: true
        left: true
        right: true
      }
      // the window covers the screen for the drawer but only reserves the pill
      exclusiveZone: topGap + root.barH
      implicitHeight: modelData.height
      color: "transparent"
      WlrLayershell.keyboardFocus: !(hosting && Popups.current !== "" && !Popups.peek) ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
      mask: Region {
        item: island
      }

      function opener(name) {
        if (name === "cc")
          return ControlCenter.side === "left" ? tunePart : statusPart;
        if (name === "sysinfo")
          return statsPart;
        if (name === "calendar")
          return clockPart;
        if (name === "weather")
          return weatherPart;
        if (name === "media")
          return mediaPart.visible ? mediaPart : clockPart;
        return null;
      }
      function centerOf(name) {
        const it = opener(name);
        if (!it || !it.visible)
          return win.width / 2;
        return it.mapToItem(win.contentItem, it.width / 2, 0).x;
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
        value: island.reveal > 0
      }
      Binding {
        when: win.hosting
        target: Popups
        property: "axis"
        value: "x"
      }
      onHostingChanged: claim()
      function claim() {
        if (hosting)
          Popups.locate = name => win.centerOf(name);
      }

      Component.onCompleted: {
        claim();
        drop.start();
      }

      // entrance: a dot drops in, then stretches into the pill
      ParallelAnimation {
        id: drop
        NumberAnimation {
          target: island
          property: "appear"
          to: 1
          duration: 380
          easing.type: Easing.OutBack
          easing.overshoot: 1.6
        }
        SequentialAnimation {
          PauseAnimation {
            duration: 200
          }
          PropertyAction {
            target: island
            property: "ready"
            value: true
          }
        }
      }
      // exit: shrinks back to a dot while rising and fading
      Connections {
        target: Style
        function onLeavingChanged() {
          if (!Style.leaving)
            return;
          drop.stop();
          island.ready = false;
          rise.start();
        }
      }
      NumberAnimation {
        id: rise
        target: island
        property: "appear"
        to: 0
        duration: Style.exitMs
        easing.type: Easing.InCubic
      }

      Rectangle {
        id: island
        readonly property Item page: win.hosting ? Popups.pages[Popups.current] || null : null
        property real fullH: 200
        Binding on fullH {
          when: island.page !== null
          value: island.page ? island.page.height + 32 : 0
          restoreMode: Binding.RestoreNone
        }
        property real reveal: page !== null ? 1 : 0
        Behavior on reveal {
          NumberAnimation {
            duration: 340
            easing.type: Easing.OutCubic
          }
        }

        property real appear: 0
        property bool ready: false
        readonly property bool drawer: page !== null
        // persistent activities hide while the drawer is out, there is no room beside the parts
        readonly property bool wide: ready && !drawer
        readonly property string face: !ready ? "" : drawer ? "rest" : root.flash || "rest"

        readonly property real restW: 2 * Math.max(leftGroup.implicitWidth, rightGroup.implicitWidth) + clockPart.implicitWidth + 2 * root.gap + 16
        readonly property real targetW: !ready ? root.barH : drawer ? Theme.popupWidth : face === "level" ? 280 : face === "notif" ? Math.min(380, Math.max(260, notifFace.implicitWidth)) : restW
        readonly property real targetH: !ready ? root.barH : drawer ? root.barH + fullH : face === "notif" ? 54 : root.barH

        // growing overshoots like a spring, shrinking settles without dipping below the pill
        function morph(anim, prop, to) {
          anim.stop();
          anim.to = to;
          anim.easing.overshoot = to > island[prop] ? (prop === "height" ? 0.8 : 1.4) : 0;
          anim.start();
        }
        onTargetWChanged: morph(wAnim, "width", targetW)
        onTargetHChanged: morph(hAnim, "height", targetH)
        NumberAnimation {
          id: wAnim
          target: island
          property: "width"
          duration: 480
          easing.type: Easing.OutBack
        }
        NumberAnimation {
          id: hAnim
          target: island
          property: "height"
          duration: 460
          easing.type: Easing.OutBack
        }

        width: root.barH
        height: root.barH
        x: Math.round((win.width - width) / 2)
        y: win.topGap - (1 - appear) * (root.barH + win.topGap + 4)
        opacity: Math.min(1, Math.max(0, appear))
        radius: Math.min(height / 2, 22)
        color: Theme.bg
        border.width: 1
        border.color: Theme.bg2
        clip: true

        // the bar strip, always at the top of the shape
        Item {
          id: strip
          width: parent.width
          height: root.barH

          Face {
            id: restFace
            anchors.fill: parent
            shown: island.face === "rest"

            Part {
              id: clockPart
              anchors.centerIn: parent
              active: Calendar.open
              onClicked: Calendar.toggle()
              Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "hh:mm")
                font.bold: true
              }
              Caption {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "ddd d")
              }
            }

            // both groups hug the clock so a growing pill reveals them instead of moving them
            Row {
              id: leftGroup
              anchors.right: clockPart.left
              anchors.rightMargin: root.gap
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2
              layoutDirection: Qt.RightToLeft

              Part {
                id: mediaPart
                readonly property var player: Media.player
                visible: island.wide && player !== null && player.isPlaying
                onClicked: mouse => {
                  if (mouse.button === Qt.RightButton)
                    player.next();
                  else if (mouse.button === Qt.MiddleButton)
                    player.togglePlaying();
                  else
                    MediaPanel.toggle();
                }
                ClippingRectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: 20
                  height: 20
                  radius: 10
                  color: Theme.bg2
                  NumberAnimation on rotation {
                    running: mediaPart.visible
                    from: 0
                    to: 360
                    duration: 9000
                    loops: Animation.Infinite
                  }
                  Image {
                    id: cover
                    anchors.fill: parent
                    source: mediaPart.player ? mediaPart.player.trackArtUrl : ""
                    sourceSize: Qt.size(40, 40)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                  }
                  Icon {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    name: "music_note"
                    size: 13
                    color: Theme.secondary
                  }
                }
                Label {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Math.min(implicitWidth, 130)
                  text: Media.title
                  elide: Text.ElideRight
                  color: Theme.secondary
                }
              }

              Item {
                id: wsBox
                readonly property int cell: 18
                property real head: 0
                property real tail: cell
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: BarState.wsCount * cell
                implicitHeight: cell

                // stretches like Rail's workspace indicator
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
                  x: wsBox.head
                  width: wsBox.tail - wsBox.head
                  height: wsBox.cell
                  radius: wsBox.cell / 2
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
                      height: wsBox.cell
                      Label {
                        anchors.centerIn: parent
                        visible: ws.isActive || wsMouse.containsMouse
                        text: ws.wsId
                        color: ws.isActive ? Theme.accentFg : Theme.accent
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                      }
                      Rectangle {
                        anchors.centerIn: parent
                        visible: !ws.isActive && !wsMouse.containsMouse
                        width: ws.isBusy ? 6 : 4
                        height: width
                        radius: width / 2
                        color: ws.isBusy ? Theme.fg : Theme.dim
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
            }

            Row {
              id: rightGroup
              anchors.left: clockPart.right
              anchors.leftMargin: root.gap
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2

              Part {
                id: weatherPart
                visible: Weather.ok
                active: WeatherPanel.open
                onClicked: WeatherPanel.toggle()
                WeatherIcon {
                  anchors.verticalCenter: parent.verticalCenter
                  size: 16
                }
                Label {
                  anchors.verticalCenter: parent.verticalCenter
                  text: Weather.temp + "°"
                }
              }

              Part {
                visible: island.wide && Recorder.active
                onClicked: Recorder.toggle()
                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: 8
                  height: 8
                  radius: 4
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
                Label {
                  anchors.verticalCenter: parent.verticalCenter
                  text: Math.floor(Recorder.elapsed / 60) + ":" + String(Recorder.elapsed % 60).padStart(2, "0")
                  color: Theme.error
                  font.pixelSize: Theme.fontSizeSmall
                }
              }

              Part {
                id: statsPart
                implicitWidth: 28
                active: SysInfo.open
                onClicked: SysInfo.toggle()
                Ring {
                  anchors.verticalCenter: parent.verticalCenter
                  implicitWidth: 20
                  implicitHeight: 20
                  thickness: 2.5
                  fill: Theme.info
                  value: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal : 0
                  Icon {
                    anchors.centerIn: parent
                    name: "memory"
                    size: 11
                    color: Theme.info
                  }
                }
              }

              Part {
                id: statusPart
                active: ControlCenter.open && ControlCenter.side === "right"
                onClicked: ControlCenter.toggle("right")
                WheelSteps {
                  onStepped: steps => Audio.step(steps * 0.05)
                }
                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: !Persist.dnd && Notifs.history.length > 0
                  width: 6
                  height: 6
                  radius: 3
                  color: Theme.accent
                }
                Icon {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: Persist.dnd
                  name: "notifications_off"
                  size: 15
                  color: Theme.dim
                }
                Icon {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: Wifi.device !== null
                  name: Wifi.icon
                  size: 15
                }
                Icon {
                  anchors.verticalCenter: parent.verticalCenter
                  name: Audio.icon
                  size: 15
                  color: Audio.muted ? Theme.error : Audio.ok ? Theme.fg : Theme.dim
                }
                Icon {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: BarState.hasBat
                  name: BarState.batIcon()
                  size: 15
                  rotation: 90
                  color: BarState.batLow ? Theme.error : BarState.charging ? Theme.success : Theme.fg
                }
              }

              Part {
                id: tunePart
                implicitWidth: 26
                active: ControlCenter.open && ControlCenter.side === "left"
                onClicked: ControlCenter.toggle("left")
                Icon {
                  name: "tune"
                  size: 16
                  color: Theme.accent
                }
              }
            }
          }

          Face {
            anchors.fill: parent
            shown: island.face === "level"

            Icon {
              id: levelIcon
              anchors.left: parent.left
              anchors.leftMargin: 14
              anchors.verticalCenter: parent.verticalCenter
              name: root.levelVolume ? Audio.icon : "light_mode"
              size: 16
              color: root.levelMuted ? Theme.error : Theme.accent
            }
            Meter {
              anchors.left: levelIcon.right
              anchors.right: levelPct.left
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              implicitHeight: 5
              value: root.levelValue
              opacity: root.levelMuted ? 0.4 : 1
            }
            Caption {
              id: levelPct
              anchors.right: parent.right
              anchors.rightMargin: 14
              anchors.verticalCenter: parent.verticalCenter
              width: 30
              horizontalAlignment: Text.AlignRight
              text: Math.round(root.levelValue * 100) + "%"
            }
          }
        }

        Face {
          id: notifFace
          shown: island.face === "notif"
          width: parent.width
          height: 54
          implicitWidth: notifText.x + Math.max(notifApp.implicitWidth, notifSummary.implicitWidth) + 22

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.flash = "";
              ControlCenter.show("right");
            }
          }
          Rectangle {
            id: notifBadge
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 16
            color: Theme.accent
            Icon {
              anchors.centerIn: parent
              name: "notifications"
              size: 18
              color: Theme.accentFg
            }
          }
          Column {
            id: notifText
            anchors.left: notifBadge.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Caption {
              id: notifApp
              width: parent.width
              elide: Text.ElideRight
              text: root.notif ? root.notif.appName : ""
            }
            Label {
              id: notifSummary
              width: parent.width
              elide: Text.ElideRight
              text: root.notif ? root.notif.summary : ""
              font.bold: true
            }
          }
        }

        Rectangle {
          x: 16
          y: root.barH
          width: parent.width - 32
          height: 1
          color: Theme.bg1
          opacity: island.reveal
        }

        // centered under the strip so pages stay put while the shape grows around them
        Item {
          id: stage
          x: (island.width - Theme.popupWidth) / 2
          y: root.barH
          width: Theme.popupWidth
          height: island.fullH
        }
      }
    }
  }
}
