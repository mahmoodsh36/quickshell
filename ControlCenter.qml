pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// quick settings panel. bar clicks, or qs ipc call cc toggle right.
Singleton {
  id: root
  property bool open: false

  // panel drops below the button that opened it
  property string side: "right"

  function show(s) {
    side = s || "right";
    open = true;
    poll.running = true;
  }
  function hide() {
    open = false;
  }
  function toggle(s) {
    if (open && (!s || side === s))
      hide();
    else
      show(s);
  }

  // spawned processes inherit little PATH under uwsm, so set it explicitly
  function spawn(cmd) {
    Quickshell.execDetached(["sh", "-c", "PATH=\"$HOME/.nix-profile/bin:$HOME/.local/bin:/run/current-system/sw/bin:/usr/bin:/bin\" " + cmd]);
  }

  // audio state polled via wpctl: quickshell pipewire reads go stale on
  // unbound nodes (e.g. the vm dummy output), so wpctl owns both directions
  property real volVal: 0
  property bool volOk: false
  property real volSet: -1
  property bool muted: false

  // polled system state: enabled/disabled/none (none hides the row)
  property string wifi: "none"
  property string bt: "none"
  property real brightVal: 0
  property bool brightOk: false
  property real brightSet: -1

  Process {
    id: poll
    command: ["sh", "-c", "echo \"WIFI $(nmcli -t -f TYPE device status 2>/dev/null | grep -qx wifi && nmcli -t -f WIFI g 2>/dev/null || echo none)\"; echo \"BT $(bluetoothctl list 2>/dev/null | grep -q . && { bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo on || echo off; } || echo none)\"; echo \"BRIGHT $(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%' || echo none)\"; echo \"VOL $(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{ print $2, $3 }' || echo none)\""]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = this.text.trim().split("\n");
        for (var i = 0; i < lines.length; i++) {
          var p = lines[i].trim().split(" ");
          if (p[0] === "WIFI" && p[1])
            root.wifi = p[1];
          else if (p[0] === "BT" && p[1])
            root.bt = p[1];
          else if (p[0] === "BRIGHT")
            if (p[1] && p[1] !== "none") {
              root.brightVal = parseInt(p[1], 10) / 100;
              root.brightOk = true;
              root.brightSet = -1;
            } else {
              root.brightOk = false;
            }
          else if (p[0] === "VOL")
            if (p[1] && p[1] !== "none") {
              root.volVal = parseFloat(p[1]);
              root.volOk = true;
              root.volSet = -1;
              root.muted = p[2] === "[MUTED]";
            } else {
              root.volOk = false;
            }
        }
      }
    }
  }

  Timer {
    interval: 5000
    // always, the bar reads these values too
    running: true
    repeat: true
    onTriggered: poll.running = true
  }

  component Slider: Item {
    property real value: 0
    signal moved(real v)
    signal released(real v)
    function clamp(x) {
      return Math.min(1, Math.max(0, x));
    }
    implicitHeight: 24
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: 6
      radius: 3
      color: Theme.bg2
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width * parent.value
      height: 6
      radius: 3
      color: Theme.yellow
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      x: parent.width * parent.value - 7
      width: 14
      height: 14
      radius: 7
      color: Theme.fg
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onPressed: mouse => parent.moved(parent.clamp(mouse.x / parent.width))
      onPositionChanged: mouse => {
        if (pressed)
          parent.moved(parent.clamp(mouse.x / parent.width));
      }
      onReleased: mouse => parent.released(parent.clamp(mouse.x / parent.width))
    }
  }

  component Toggle: Rectangle {
    property bool checked: false
    signal toggled()
    implicitWidth: 52
    implicitHeight: 24
    radius: 12
    color: checked ? Theme.green : Theme.bg2
    Behavior on color {
      ColorAnimation {
        duration: 150
      }
    }
    Text {
      anchors.centerIn: parent
      text: parent.checked ? "ON" : "OFF"
      color: Theme.bg
      font.family: Theme.font
      font.pixelSize: 11
      font.bold: true
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: parent.toggled()
    }
  }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen: modelData
      // one panel on the focused screen; everywhere when Hyprland is absent
      visible: root.open && (Hyprland.focusedMonitor ? modelData.name === Hyprland.focusedMonitor.name : true)
      // Esc to close needs focusable: panels ignore keyboard focus unless
      // asked (layer-shell keyboardFocus), and Keys cannot attach to the
      // window itself, so a hidden text field holds focus instead.
      focusable: true
      TextInput {
        id: keyGrabber
        width: 0
        height: 0
        opacity: 0
        Keys.onPressed: event => {
          if (event.key === Qt.Key_Escape) {
            root.hide();
            event.accepted = true;
          }
        }
      }
      onVisibleChanged: {
        if (visible)
          keyGrabber.forceActiveFocus();
      }
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

      Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.width: 1
        border.color: Theme.bg2
        radius: 8

        Column {
          id: content
          anchors.fill: parent
          anchors.margins: 12
          spacing: 10

          // volume, hidden when wpctl sees no sink
          RowLayout {
            visible: root.volOk
            width: content.width
            spacing: 8
            Text {
              text: "♪"
              color: Theme.green
              font.family: Theme.font
              font.pixelSize: Theme.fontSize
            }
            Slider {
              Layout.fillWidth: true
              value: root.volSet >= 0 ? root.volSet : root.volVal
              onMoved: v => root.volSet = v
              onReleased: v => {
                root.spawn("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + Math.round(v * 100) + "%");
                poll.running = true;
              }
            }
            Text {
              text: root.muted ? "MUTE" : Math.round((root.volSet >= 0 ? root.volSet : root.volVal) * 100) + "%"
              color: root.muted ? Theme.red : Theme.fg
              font.family: Theme.font
              font.pixelSize: Theme.fontSize
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.spawn("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle");
                  poll.running = true;
                }
              }
            }
          }

          // brightness, hidden without a backlight (desktops, VMs)
          RowLayout {
            visible: root.brightOk
            width: content.width
            spacing: 8
            Text {
              text: "☀"
              color: Theme.yellow
              font.family: Theme.font
              font.pixelSize: Theme.fontSize
            }
            Slider {
              Layout.fillWidth: true
              value: root.brightSet >= 0 ? root.brightSet : root.brightVal
              onMoved: v => root.brightSet = v
              onReleased: v => root.spawn("brightnessctl s " + Math.round(v * 100) + "%")
            }
            Text {
              text: Math.round((root.brightSet >= 0 ? root.brightSet : root.brightVal) * 100) + "%"
              color: Theme.fg
              font.family: Theme.font
              font.pixelSize: Theme.fontSize
            }
          }

          RowLayout {
            visible: root.wifi !== "none"
            width: content.width
            spacing: 8
            Text {
              Layout.fillWidth: true
              text: "WIFI " + root.wifi
              color: Theme.blue
              font.family: Theme.font
              font.pixelSize: Theme.fontSize
            }
            Toggle {
              checked: root.wifi === "enabled"
              onToggled: {
                root.spawn("nmcli radio wifi " + (root.wifi === "enabled" ? "off" : "on"));
                poll.running = true;
              }
            }
          }

          RowLayout {
            visible: root.bt !== "none"
            width: content.width
            spacing: 8
            Text {
              Layout.fillWidth: true
              text: "BT " + root.bt
              color: Theme.blue
              font.family: Theme.font
              font.pixelSize: Theme.fontSize
            }
            Toggle {
              checked: root.bt === "on"
              onToggled: {
                root.spawn("bluetoothctl power " + (root.bt === "on" ? "off" : "on"));
                poll.running = true;
              }
            }
          }

          // theme, click cycles the palette
          RowLayout {
            width: content.width
            spacing: 8
            Text {
              Layout.fillWidth: true
              text: "THEME " + Theme.themeName
              color: Theme.blue
              font.family: Theme.font
              font.pixelSize: Theme.fontSize
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Theme.nextTheme()
              }
            }
          }

          RowLayout {
            width: content.width
            spacing: 8
            Text {
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
              text: "REBOOT"
              color: Theme.dim
              font.family: Theme.font
              font.pixelSize: Theme.fontSize
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.spawn("systemctl reboot")
              }
            }
            Text {
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
              text: "OFF"
              color: Theme.red
              font.family: Theme.font
              font.pixelSize: Theme.fontSize
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.spawn("systemctl poweroff")
              }
            }
          }
        }
      }
    }
  }
}
