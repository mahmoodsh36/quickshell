pragma Singleton
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

// quick settings panel. bar clicks, or qs ipc call cc toggle right.
Singleton {
  id: root
  readonly property bool open: popup.open
  // panel drops below the button that opened it
  property string side: "right"
  // main, wifi, bluetooth or notifications
  property string page: "main"

  function show(s) {
    side = s || "right";
    page = "main";
    Popups.open("cc");
    Brightness.refresh();
  }
  function hide() {
    Popups.close("cc");
  }
  function toggle(s) {
    if (open && (!s || side === s))
      hide();
    else
      show(s);
  }
  onOpenChanged: {
    if (!open)
      armed = "";
  }

  readonly property var btAdapter: Bluetooth.defaultAdapter
  readonly property bool btOn: !!btAdapter && btAdapter.enabled
  readonly property var btConnected: btAdapter ? Array.from(btAdapter.devices.values).filter(d => d.connected) : []

  // runs fn once the panel is unmapped, so it isn't captured or holding focus
  property var afterHide: null
  function launch(fn) {
    afterHide = fn;
    hide();
    if (!popup.backingWindowVisible)
      runAfterHide();
  }
  function runAfterHide() {
    const fn = afterHide;
    afterHide = null;
    if (fn)
      Qt.callLater(fn);
  }

  component Action: Column {
    id: action
    property alias icon: btn.icon
    property alias iconColor: btn.iconColor
    property string text
    signal clicked
    Layout.fillWidth: true
    spacing: 4
    IconButton {
      id: btn
      anchors.horizontalCenter: parent.horizontalCenter
      size: 40
      tint: Theme.bg1
      onClicked: action.clicked()
    }
    Caption {
      anchors.horizontalCenter: parent.horizontalCenter
      text: action.text
    }
  }

  component Tile: QuickTile {
    Layout.fillWidth: true
    Layout.preferredWidth: 1
  }

  component Level: RowLayout {
    id: level
    property alias icon: btn.icon
    property alias iconColor: btn.iconColor
    property alias interactive: btn.interactive
    property real value
    property bool muted: false
    signal iconClicked
    signal moved(real v)
    width: parent.width
    spacing: 8
    IconButton {
      id: btn
      onClicked: level.iconClicked()
    }
    Slider {
      Layout.fillWidth: true
      value: level.value
      opacity: level.muted ? 0.4 : 1
      onMoved: v => level.moved(v)
    }
    Label {
      Layout.preferredWidth: 36
      horizontalAlignment: Text.AlignRight
      text: Math.round(level.value * 100) + "%"
      color: Theme.dim
    }
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

  Popup {
    id: popup
    name: "cc"
    side: root.side
    onKeyPressed: event => {
      if (event.key === Qt.Key_Escape && root.page !== "main") {
        root.page = "main";
        event.accepted = true;
      }
    }
    onBackingWindowVisibleChanged: {
      if (!backingWindowVisible)
        root.runAfterHide();
    }

    Column {
      visible: root.page === "main"
      width: parent.width
      spacing: 14

      RowLayout {
        visible: Wifi.device !== null || root.btAdapter !== null
        width: parent.width
        spacing: 10
        Tile {
          visible: Wifi.device !== null
          icon: Networking.wifiEnabled ? "wifi" : "wifi_off"
          title: "Wi-Fi"
          subtitle: !Networking.wifiEnabled ? "Off" : Wifi.network ? Wifi.network.name : "Not connected"
          active: Networking.wifiEnabled
          onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
          onOpened: root.page = "wifi"
        }
        Tile {
          visible: root.btAdapter !== null
          icon: root.btOn ? (root.btConnected.length > 0 ? "bluetooth_connected" : "bluetooth") : "bluetooth_disabled"
          title: "Bluetooth"
          subtitle: !root.btOn ? "Off" : root.btConnected.length === 0 ? "On" : root.btConnected.length === 1 ? root.btConnected[0].name : root.btConnected.length + " devices"
          active: root.btOn
          onToggled: root.btAdapter.enabled = !root.btAdapter.enabled
          onOpened: root.page = "bluetooth"
        }
      }

      RowLayout {
        width: parent.width
        spacing: 10
        Tile {
          expandable: false
          icon: "nightlight"
          title: "Night light"
          subtitle: NightLight.active ? NightLight.temp + "K" : "Off"
          active: NightLight.active
          onToggled: NightLight.toggle()
        }
        Tile {
          icon: Persist.dnd ? "notifications_off" : "notifications"
          title: "Do not disturb"
          subtitle: Notifs.history.length === 0 ? "No notifications" : Notifs.history.length + " notification" + (Notifs.history.length === 1 ? "" : "s")
          active: Persist.dnd
          onToggled: Persist.dnd = !Persist.dnd
          onOpened: root.page = "notifications"
        }
      }

      MediaCard {
        width: parent.width
      }

      RowLayout {
        width: parent.width
        Action {
          icon: "apps"
          text: "Apps"
          onClicked: root.launch(() => Launcher.show("apps"))
        }
        Action {
          icon: "content_paste"
          text: "Clipboard"
          onClicked: root.launch(() => Launcher.show("clipboard"))
        }
        Action {
          icon: "screenshot_monitor"
          text: "Screen"
          onClicked: root.launch(() => Quickshell.execDetached(Config.screenshotCmd))
        }
        Action {
          icon: "screenshot_region"
          text: "Region"
          onClicked: root.launch(() => Quickshell.execDetached(Config.screenshotRegionCmd))
        }
        Action {
          icon: Recorder.active ? "stop_circle" : "videocam"
          iconColor: Recorder.active ? Theme.error : Theme.fg
          text: Recorder.active ? "Stop" : "Record"
          onClicked: root.launch(() => Recorder.toggle(false))
        }
        Action {
          visible: !Recorder.active
          icon: "crop_free"
          text: "Rec area"
          onClicked: root.launch(() => Recorder.toggle(true))
        }
      }

      Rectangle {
        visible: Audio.ok || Brightness.ok
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

          Level {
            visible: Audio.ok
            icon: Audio.icon
            iconColor: Audio.muted ? Theme.error : Theme.fg
            value: Audio.volume
            muted: Audio.muted
            onIconClicked: Audio.toggleMute()
            onMoved: v => Audio.setVolume(v)
          }

          Level {
            visible: Brightness.ok
            icon: "light_mode"
            interactive: false
            value: Brightness.value
            onMoved: v => Brightness.set(v)
          }
        }
      }

      RowLayout {
        width: parent.width
        spacing: 6
        PillButton {
          visible: root.armed === ""
          icon: "wallpaper"
          text: "Wallpaper"
          onClicked: {
            root.hide();
            WallpaperPicker.show();
          }
        }
        Label {
          visible: root.armed !== ""
          text: "Click again to " + (root.armed === "reboot" ? "restart" : "power off")
          color: Theme.error
          font.pixelSize: Theme.fontSizeSmall + 1
        }
        Item {
          Layout.fillWidth: true
        }
        IconButton {
          icon: "restart_alt"
          tint: root.armed === "reboot" ? Theme.error : Theme.bg1
          iconColor: root.armed === "reboot" ? Theme.bg : Theme.fg
          onClicked: root.power("reboot")
        }
        IconButton {
          icon: "power_settings_new"
          tint: root.armed === "poweroff" ? Theme.error : Theme.bg1
          iconColor: root.armed === "poweroff" ? Theme.bg : Theme.error
          onClicked: root.power("poweroff")
        }
      }
    }

    WifiPage {
      visible: root.page === "wifi"
      width: parent.width
      device: Wifi.device
      onBack: root.page = "main"
    }

    BluetoothPage {
      visible: root.page === "bluetooth"
      width: parent.width
      onBack: root.page = "main"
    }

    Column {
      visible: root.page === "notifications"
      width: parent.width
      spacing: 8

      PageHeader {
        title: "Notifications"
        onBack: root.page = "main"
        PillButton {
          visible: Notifs.history.length > 0
          text: "Clear"
          onClicked: Notifs.clear()
        }
      }
      EmptyState {
        visible: Notifs.history.length === 0
        icon: "notifications_none"
        text: "Nothing new"
      }
      ScrollColumn {
        id: notifList
        maxHeight: 480
        spacing: 8
        Repeater {
          model: Notifs.history
          NotifCard {
            required property var modelData
            notif: modelData
            width: notifList.width
          }
        }
      }
    }
  }
}
