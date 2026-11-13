pragma Singleton
import Quickshell
import Quickshell.Wayland
import QtQuick

// volume and brightness overlay, skipped while the control center or the island shows the level
Singleton {
  id: root
  property string kind: "volume"
  property bool shown: false

  function show(k) {
    if (!settled.ready || ControlCenter.open || Style.shown === "island")
      return;
    kind = k;
    shown = true;
    hideTimer.restart();
  }

  // pipewire and the first backlight read report their values at startup
  Timer {
    id: settled
    property bool ready: false
    interval: 2000
    running: true
    onTriggered: ready = true
  }
  Timer {
    id: hideTimer
    interval: 1500
    onTriggered: root.shown = false
  }

  Connections {
    target: Audio
    function onVolumeChanged() {
      root.show("volume");
    }
    function onMutedChanged() {
      root.show("volume");
    }
  }
  Connections {
    target: Brightness
    function onValueChanged() {
      root.show("brightness");
    }
  }

  readonly property bool isVolume: kind === "volume"
  readonly property real value: isVolume ? Audio.volume : Brightness.value
  readonly property bool muted: isVolume && Audio.muted

  // a pill above the bottom edge, or with the rail a vertical gauge sliding out of it
  readonly property bool vertical: Style.rail

  PanelWindow {
    screen: Focus.screen
    visible: card.opacity > 0
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors.bottom: !root.vertical
    anchors.left: root.vertical && !Style.railRight
    anchors.right: Style.railRight
    margins.bottom: 80
    margins.left: Theme.railWidth + 8
    margins.right: Theme.railWidth + 8
    implicitWidth: root.vertical ? 52 : 280
    implicitHeight: root.vertical ? 240 : 48
    color: "transparent"
    // click-through
    mask: Region {}

    Rectangle {
      id: card
      width: parent.width
      height: parent.height
      radius: width < height ? width / 2 : height / 2
      color: Theme.bg
      border.width: 1
      border.color: Theme.bg2
      opacity: root.shown ? 1 : 0
      x: root.vertical && !root.shown ? (Style.railRight ? 24 : -24) : 0
      Behavior on opacity {
        NumberAnimation {
          duration: 150
        }
      }
      Behavior on x {
        NumberAnimation {
          duration: 260
          easing.type: Easing.OutCubic
        }
      }

      Item {
        anchors.fill: parent
        visible: !root.vertical

        Icon {
          id: glyph
          anchors.left: parent.left
          anchors.leftMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          name: root.isVolume ? Audio.icon : "light_mode"
          color: root.muted ? Theme.error : Theme.fg
        }
        Meter {
          anchors.left: glyph.right
          anchors.right: pct.left
          anchors.leftMargin: 12
          anchors.rightMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          value: root.value
          opacity: root.muted ? 0.4 : 1
        }
        Label {
          id: pct
          anchors.right: parent.right
          anchors.rightMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          width: 36
          horizontalAlignment: Text.AlignRight
          text: Math.round(root.value * 100) + "%"
          color: Theme.dim
        }
      }

      Item {
        anchors.fill: parent
        visible: root.vertical

        Caption {
          id: vpct
          anchors.top: parent.top
          anchors.topMargin: 14
          anchors.horizontalCenter: parent.horizontalCenter
          text: Math.round(root.value * 100)
        }
        Rectangle {
          id: track
          anchors.top: vpct.bottom
          anchors.bottom: vglyph.top
          anchors.margins: 8
          anchors.horizontalCenter: parent.horizontalCenter
          width: 8
          radius: 4
          color: Theme.bg2
          opacity: root.muted ? 0.4 : 1
          Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Math.max(width, parent.height * Math.min(1, Math.max(0, root.value)))
            radius: parent.radius
            color: Theme.accent
            Behavior on height {
              NumberAnimation {
                duration: 120
              }
            }
          }
        }
        Icon {
          id: vglyph
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 14
          anchors.horizontalCenter: parent.horizontalCenter
          name: root.isVolume ? Audio.icon : "light_mode"
          color: root.muted ? Theme.error : Theme.fg
        }
      }
    }
  }
}
