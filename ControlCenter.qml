pragma Singleton
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

// quick settings panel. bar clicks, or qs ipc call cc toggle right.
Singleton {
  id: root
  property bool open: false
  // panel drops below the button that opened it
  property string side: "right"
  // in the focus grab so bar clicks don't close the panel
  property var barWindows: []

  function show(s) {
    side = s || "right";
    open = true;
    brightProc.exec(["brightnessctl", "-m", "-c", "backlight"]);
  }
  function hide() {
    open = false;
    armed = "";
  }
  function toggle(s) {
    if (open && (!s || side === s))
      hide();
    else
      show(s);
  }

  property bool hasWifi: Array.from(Networking.devices.values).some(d => d.type === DeviceType.Wifi)
  property var btAdapter: Bluetooth.defaultAdapter

  // no change events, so read on open
  property real bright: 0
  property bool brightOk: false
  property real brightDrag: -1

  Process {
    id: brightProc
    stdout: StdioCollector {
      // -m prints device,class,current,percent,max
      onStreamFinished: {
        var f = text.trim().split("\n")[0].split(",");
        root.brightOk = f.length >= 5 && Number(f[4]) > 0;
        if (root.brightOk)
          root.bright = Number(f[2]) / Number(f[4]);
        root.brightDrag = -1;
      }
    }
  }

  function setBright(v) {
    brightProc.exec(["sh", "-c", "brightnessctl -q -c backlight s \"$1\"; brightnessctl -m -c backlight", "sh", Math.round(v * 100) + "%"]);
  }

  property string armed: ""
  function power(action) {
    if (armed === action) {
      Quickshell.execDetached(["systemctl", action]);
      armed = "";
    } else {
      armed = action;
      disarm.restart();
    }
  }
  Timer {
    id: disarm
    interval: 3000
    onTriggered: root.armed = ""
  }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: panel
      required property var modelData
      screen: modelData
      // one panel on the focused screen; everywhere when Hyprland is absent
      visible: root.open && (Hyprland.focusedMonitor ? modelData.name === Hyprland.focusedMonitor.name : true)
      focusable: true
      anchors {
        top: true
        left: root.side === "left"
        right: root.side === "right"
      }
      margins {
        top: Theme.barHeight + 4
        left: root.side === "left" ? 8 : 0
        right: root.side === "right" ? 8 : 0
      }
      // ignore the bar reservation so margins measure from the screen edge
      exclusionMode: ExclusionMode.Ignore
      implicitWidth: 300
      implicitHeight: content.implicitHeight + 24
      color: "transparent"

      onVisibleChanged: {
        if (visible)
          frame.forceActiveFocus();
      }

      HyprlandFocusGrab {
        active: panel.visible
        windows: [panel].concat(Array.from(root.barWindows))
        onCleared: root.hide()
      }

      Rectangle {
        id: frame
        anchors.fill: parent
        color: Theme.bg
        border.width: 1
        border.color: Theme.bg2
        radius: 8
        focus: true
        Keys.onEscapePressed: root.hide()

        Column {
          id: content
          anchors.fill: parent
          anchors.margins: 12
          spacing: 10

          RowLayout {
            visible: Audio.ok
            width: content.width
            spacing: 8
            Label {
              text: "♪"
              color: Theme.green
            }
            Slider {
              Layout.fillWidth: true
              value: Audio.volume
              onMoved: v => Audio.setVolume(v)
            }
            Label {
              text: Audio.muted ? "MUTE" : Math.round(Audio.volume * 100) + "%"
              color: Audio.muted ? Theme.red : Theme.fg
              clickable: true
              onClicked: Audio.toggleMute()
            }
          }

          RowLayout {
            visible: root.brightOk
            width: content.width
            spacing: 8
            Label {
              text: "☀"
              color: Theme.yellow
            }
            Slider {
              id: brightSlider
              Layout.fillWidth: true
              value: root.brightDrag >= 0 ? root.brightDrag : root.bright
              onMoved: v => root.brightDrag = v
              onReleased: v => root.setBright(v)
            }
            Label {
              text: Math.round(brightSlider.value * 100) + "%"
            }
          }

          RowLayout {
            visible: root.hasWifi
            width: content.width
            spacing: 8
            Label {
              Layout.fillWidth: true
              text: "WIFI " + (Networking.wifiEnabled ? "on" : "off")
              color: Theme.blue
            }
            Toggle {
              checked: Networking.wifiEnabled
              onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }
          }

          RowLayout {
            visible: root.btAdapter !== null
            width: content.width
            spacing: 8
            Label {
              Layout.fillWidth: true
              text: "BT " + (root.btAdapter && root.btAdapter.enabled ? "on" : "off")
              color: Theme.blue
            }
            Toggle {
              checked: root.btAdapter !== null && root.btAdapter.enabled
              onToggled: root.btAdapter.enabled = !root.btAdapter.enabled
            }
          }

          Label {
            width: content.width
            text: "THEME " + Theme.themeName
            color: Theme.blue
            clickable: true
            onClicked: Theme.nextTheme()
          }

          RowLayout {
            width: content.width
            spacing: 8
            Label {
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
              text: root.armed === "reboot" ? "REBOOT?" : "REBOOT"
              color: root.armed === "reboot" ? Theme.yellow : Theme.dim
              clickable: true
              onClicked: root.power("reboot")
            }
            Label {
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
              text: root.armed === "poweroff" ? "OFF?" : "OFF"
              color: root.armed === "poweroff" ? Theme.yellow : Theme.red
              clickable: true
              onClicked: root.power("poweroff")
            }
          }
        }
      }
    }
  }
}
