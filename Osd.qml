pragma Singleton
import Quickshell
import Quickshell.Wayland
import QtQuick

// volume and brightness overlay, skipped while the control center shows the same sliders
Singleton {
  id: root
  property string kind: "volume"
  property bool shown: false

  function show(k) {
    if (!settled.ready || ControlCenter.open)
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

  PanelWindow {
    screen: Focus.screen
    visible: card.opacity > 0
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors.bottom: true
    margins.bottom: 80
    implicitWidth: 280
    implicitHeight: 48
    color: "transparent"
    // click-through
    mask: Region {}

    Rectangle {
      id: card
      anchors.fill: parent
      radius: height / 2
      color: Theme.bg
      border.width: 1
      border.color: Theme.bg2
      opacity: root.shown ? 1 : 0
      Behavior on opacity {
        NumberAnimation {
          duration: 150
        }
      }

      Icon {
        id: glyph
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        name: !root.isVolume ? "light_mode" : root.muted ? "volume_off" : root.value < 0.5 ? "volume_down" : "volume_up"
        color: root.muted ? Theme.red : Theme.fg
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
  }
}
