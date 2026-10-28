import Quickshell
import Quickshell.Bluetooth
import QtQuick

Column {
  id: page
  property var adapter: Bluetooth.defaultAdapter
  signal back

  property string openAddr: ""
  // by address, the row moves lists once paired
  property var connectWhenPaired: ({})

  function pairAndConnect(d) {
    connectWhenPaired[d.address] = true;
    d.pair();
  }
  function maybeConnect(d) {
    if (d.paired && connectWhenPaired[d.address]) {
      delete connectWhenPaired[d.address];
      d.trusted = true;
      d.connect();
    }
  }

  readonly property bool on: !!adapter && adapter.enabled
  readonly property var devices: adapter ? Array.from(adapter.devices.values) : []
  readonly property var paired: devices.filter(d => d.paired || d.bonded).sort((a, b) => b.connected - a.connected || a.name.localeCompare(b.name))
  // nameless devices are mostly beacons
  readonly property var available: devices.filter(d => !d.paired && !d.bonded && d.deviceName !== "")

  function iconFor(d) {
    var i = d.icon || "";
    if (i.startsWith("audio-head"))
      return "headphones";
    if (i.startsWith("audio"))
      return "speaker";
    if (i === "input-mouse")
      return "mouse";
    if (i === "input-keyboard")
      return "keyboard";
    if (i === "input-gaming")
      return "sports_esports";
    if (i === "phone")
      return "smartphone";
    if (i === "computer")
      return "computer";
    return "bluetooth";
  }

  function status(d) {
    if (d.pairing)
      return "Pairing…";
    if (d.state === BluetoothDeviceState.Connecting)
      return "Connecting…";
    if (d.state === BluetoothDeviceState.Disconnecting)
      return "Disconnecting…";
    if (d.connected)
      return "Connected" + (d.batteryAvailable ? " · " + Math.round(d.battery * 100) + "%" : "");
    return d.paired || d.bonded ? "Paired" : "";
  }

  onVisibleChanged: {
    if (!visible)
      openAddr = "";
  }

  Binding {
    target: page.adapter
    when: !!page.adapter
    property: "discovering"
    value: ControlCenter.open && page.visible && page.on
  }

  spacing: 8

  PageHeader {
    title: "Bluetooth"
    onBack: page.back()
    Icon {
      anchors.verticalCenter: parent.verticalCenter
      visible: page.on && page.adapter.discovering
      name: "progress_activity"
      spinning: visible
      color: Theme.dim
    }
    Toggle {
      anchors.verticalCenter: parent.verticalCenter
      checked: page.on
      onToggled: page.adapter.enabled = !page.adapter.enabled
    }
  }

  EmptyState {
    visible: !page.on
    icon: "bluetooth_disabled"
    text: "Bluetooth is off"
  }

  component Section: Label {
    leftPadding: 8
    topPadding: 4
    color: Theme.dim
    font.pixelSize: Theme.fontSizeSmall
    font.bold: true
    font.letterSpacing: 1
  }

  component DeviceRow: ListRow {
    id: row
    required property var modelData
    readonly property var dev: modelData
    readonly property bool known: dev.paired || dev.bonded

    icon: page.iconFor(dev)
    title: dev.name || dev.deviceName || dev.address
    subtitle: page.status(dev)
    highlighted: dev.connected
    busy: dev.pairing || dev.state === BluetoothDeviceState.Connecting || dev.state === BluetoothDeviceState.Disconnecting
    trailingIcon: known ? "more_horiz" : ""
    trailingInteractive: known
    expanded: page.openAddr === dev.address
    onTrailingClicked: page.openAddr = expanded ? "" : dev.address
    onClicked: {
      if (dev.connected) {
        page.openAddr = expanded ? "" : dev.address;
      } else if (known) {
        dev.connect();
      } else {
        page.pairAndConnect(dev);
      }
    }
    Component.onCompleted: page.maybeConnect(dev)

    Connections {
      target: row.dev
      function onPairedChanged() {
        page.maybeConnect(row.dev);
      }
    }

    Row {
      spacing: 8
      PillButton {
        text: row.dev.connected ? "Disconnect" : "Connect"
        filled: !row.dev.connected
        accent: Theme.accent
        onClicked: {
          page.openAddr = "";
          if (row.dev.connected)
            row.dev.disconnect();
          else
            row.dev.connect();
        }
      }
      PillButton {
        text: "Forget"
        accent: Theme.red
        onClicked: {
          page.openAddr = "";
          row.dev.forget();
        }
      }
    }
  }

  Flickable {
    visible: page.on
    width: parent.width
    height: Math.min(contentHeight, 380)
    contentHeight: list.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: list
      width: parent.width
      spacing: 2

      Section {
        visible: page.paired.length > 0
        text: "PAIRED"
      }
      Repeater {
        model: page.paired
        DeviceRow {}
      }

      Section {
        text: "AVAILABLE"
      }
      Repeater {
        model: page.available
        DeviceRow {}
      }
      EmptyState {
        visible: page.available.length === 0
        icon: "bluetooth_searching"
        text: "Looking for devices…"
      }
    }
  }
}
