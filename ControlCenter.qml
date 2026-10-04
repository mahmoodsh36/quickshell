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
  // main, wifi or bluetooth
  property string page: "main"
  // in the focus grab so bar clicks don't close the panel
  property var barWindows: []

  function show(s) {
    Calendar.hide();
    side = s || "right";
    page = "main";
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

  readonly property var wifiDevice: Array.from(Networking.devices.values).find(d => d.type === DeviceType.Wifi) || null
  readonly property var wifiNetwork: wifiDevice ? Array.from(wifiDevice.networks.values).find(n => n.connected) || null : null
  readonly property var btAdapter: Bluetooth.defaultAdapter
  readonly property bool btOn: !!btAdapter && btAdapter.enabled
  readonly property var btConnected: btAdapter ? Array.from(btAdapter.devices.values).filter(d => d.connected) : []

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
        top: Theme.barHeight + 6
        left: root.side === "left" ? 8 : 0
        right: root.side === "right" ? 8 : 0
      }
      // ignore the bar reservation so margins measure from the screen edge
      exclusionMode: ExclusionMode.Ignore
      implicitWidth: 360
      implicitHeight: content.implicitHeight + 32
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
        radius: 20
        focus: true
        Keys.onEscapePressed: {
          if (root.page !== "main")
            root.page = "main";
          else
            root.hide();
        }

        Item {
          id: content
          anchors.fill: parent
          anchors.margins: 16
          implicitHeight: root.page === "wifi" ? wifiPage.implicitHeight : root.page === "bluetooth" ? btPage.implicitHeight : mainPage.implicitHeight

          Column {
            id: mainPage
            visible: root.page === "main"
            width: parent.width
            spacing: 14

            RowLayout {
              visible: root.wifiDevice !== null || root.btAdapter !== null
              width: parent.width
              spacing: 10
              QuickTile {
                visible: root.wifiDevice !== null
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: Networking.wifiEnabled ? "wifi" : "wifi_off"
                title: "Wi-Fi"
                subtitle: !Networking.wifiEnabled ? "Off" : root.wifiNetwork ? root.wifiNetwork.name : "Not connected"
                active: Networking.wifiEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                onOpened: root.page = "wifi"
              }
              QuickTile {
                visible: root.btAdapter !== null
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: root.btOn ? (root.btConnected.length > 0 ? "bluetooth_connected" : "bluetooth") : "bluetooth_disabled"
                title: "Bluetooth"
                subtitle: !root.btOn ? "Off" : root.btConnected.length === 0 ? "On" : root.btConnected.length === 1 ? root.btConnected[0].name : root.btConnected.length + " devices"
                active: root.btOn
                onToggled: root.btAdapter.enabled = !root.btAdapter.enabled
                onOpened: root.page = "bluetooth"
              }
            }

            Rectangle {
              visible: Audio.ok || root.brightOk
              width: parent.width
              implicitHeight: sliders.implicitHeight + 16
              radius: 16
              color: Theme.bg1

              Column {
                id: sliders
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 8
                anchors.rightMargin: 14

                RowLayout {
                  visible: Audio.ok
                  width: parent.width
                  spacing: 8
                  IconButton {
                    icon: Audio.muted ? "volume_off" : Audio.volume < 0.01 ? "volume_mute" : Audio.volume < 0.5 ? "volume_down" : "volume_up"
                    iconColor: Audio.muted ? Theme.red : Theme.fg
                    onClicked: Audio.toggleMute()
                  }
                  Slider {
                    Layout.fillWidth: true
                    value: Audio.volume
                    opacity: Audio.muted ? 0.4 : 1
                    onMoved: v => Audio.setVolume(v)
                  }
                  Label {
                    Layout.preferredWidth: 36
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(Audio.volume * 100) + "%"
                    color: Theme.dim
                  }
                }

                RowLayout {
                  visible: root.brightOk
                  width: parent.width
                  spacing: 8
                  IconButton {
                    icon: "light_mode"
                    interactive: false
                  }
                  Slider {
                    id: brightSlider
                    Layout.fillWidth: true
                    value: root.brightDrag >= 0 ? root.brightDrag : root.bright
                    onMoved: v => root.brightDrag = v
                    onReleased: v => root.setBright(v)
                  }
                  Label {
                    Layout.preferredWidth: 36
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(brightSlider.value * 100) + "%"
                    color: Theme.dim
                  }
                }
              }
            }

            RowLayout {
              width: parent.width
              spacing: 6
              PillButton {
                visible: root.armed === ""
                icon: "palette"
                text: Theme.themeName
                onClicked: Theme.nextTheme()
              }
              Label {
                visible: root.armed !== ""
                text: "Click again to " + (root.armed === "reboot" ? "restart" : "power off")
                color: Theme.red
                font.pixelSize: Theme.fontSizeSmall + 1
              }
              Item {
                Layout.fillWidth: true
              }
              IconButton {
                icon: "restart_alt"
                tint: root.armed === "reboot" ? Theme.red : Theme.bg1
                iconColor: root.armed === "reboot" ? Theme.bg : Theme.fg
                onClicked: root.power("reboot")
              }
              IconButton {
                icon: "power_settings_new"
                tint: root.armed === "poweroff" ? Theme.red : Theme.bg1
                iconColor: root.armed === "poweroff" ? Theme.bg : Theme.red
                onClicked: root.power("poweroff")
              }
            }
          }

          WifiPage {
            id: wifiPage
            visible: root.page === "wifi"
            width: parent.width
            device: root.wifiDevice
            onBack: root.page = "main"
          }

          BluetoothPage {
            id: btPage
            visible: root.page === "bluetooth"
            width: parent.width
            onBack: root.page = "main"
          }
        }
      }
    }
  }
}
