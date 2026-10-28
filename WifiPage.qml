import Quickshell
import Quickshell.Networking
import QtQuick

Column {
  id: page
  property var device: null
  signal back

  // expanded row, mode is "pw" or "menu"
  property string openName: ""
  property string openMode: ""
  property string errorName: ""
  property string errorText: ""

  readonly property var enterprise: [WifiSecurityType.Wpa2Eap, WifiSecurityType.WpaEap, WifiSecurityType.Leap, WifiSecurityType.DynamicWep]
  readonly property var networks: device ? Array.from(device.networks.values).filter(n => n.name !== "").sort((a, b) => b.connected - a.connected || b.known - a.known || b.signalStrength - a.signalStrength) : []

  function open(net, mode) {
    var same = openName === net.name && openMode === mode;
    openName = same ? "" : net.name;
    openMode = same ? "" : mode;
  }
  function close() {
    openName = "";
    openMode = "";
  }

  function needsPassword(net) {
    return net.security !== WifiSecurityType.Open && net.security !== WifiSecurityType.Owe;
  }

  function activate(net) {
    errorName = "";
    if (net.connected)
      open(net, "menu");
    else if (enterprise.includes(net.security))
      fail(net, "Enterprise network, use nmtui");
    else if (!net.known && needsPassword(net))
      open(net, "pw");
    else {
      close();
      net.connect();
    }
  }

  function submit(net, psk) {
    if (psk === "")
      return;
    errorName = "";
    close();
    net.connectWithPsk(psk);
  }

  function fail(net, text) {
    errorName = net.name;
    errorText = text;
  }

  function onFailed(net, reason) {
    if (reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout || reason === ConnectionFailReason.WifiClientFailed) {
      fail(net, "Wrong password, try again");
      openName = net.name;
      openMode = "pw";
    } else {
      fail(net, "Couldn't connect");
    }
  }

  function signalIcon(s) {
    return s > 0.75 ? "signal_wifi_4_bar" : s > 0.5 ? "network_wifi_3_bar" : s > 0.25 ? "network_wifi_2_bar" : s > 0.05 ? "network_wifi_1_bar" : "signal_wifi_0_bar";
  }

  onVisibleChanged: {
    if (!visible) {
      close();
      errorName = "";
    }
  }

  Binding {
    target: page.device
    when: page.device !== null
    property: "scannerEnabled"
    value: ControlCenter.open && page.visible && Networking.wifiEnabled
  }

  spacing: 8

  PageHeader {
    title: "Wi-Fi"
    onBack: page.back()
    Toggle {
      anchors.verticalCenter: parent.verticalCenter
      checked: Networking.wifiEnabled
      onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
    }
  }

  EmptyState {
    visible: !Networking.wifiEnabled
    icon: "wifi_off"
    text: "Wi-Fi is off"
  }

  EmptyState {
    visible: Networking.wifiEnabled && page.networks.length === 0
    icon: "progress_activity"
    spinning: visible
    text: "Looking for networks…"
  }

  Flickable {
    visible: Networking.wifiEnabled && page.networks.length > 0
    width: parent.width
    height: Math.min(contentHeight, 360)
    contentHeight: list.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: list
      width: parent.width
      spacing: 2

      Repeater {
        model: page.networks

        ListRow {
          id: row
          required property var modelData
          readonly property var net: modelData
          readonly property bool failed: page.errorName === net.name
          readonly property bool connecting: net.state === ConnectionState.Connecting || net.stateChanging

          icon: page.signalIcon(net.signalStrength)
          title: net.name
          highlighted: net.connected
          busy: connecting
          subtitle: failed ? page.errorText : connecting ? "Connecting…" : net.connected ? "Connected" : net.known ? "Saved" : page.enterprise.includes(net.security) ? "Enterprise" : page.needsPassword(net) ? "Secured" : "Open"
          subtitleColor: failed ? Theme.red : Theme.dim
          trailingIcon: net.connected || net.known ? "more_horiz" : page.needsPassword(net) ? "lock" : ""
          trailingInteractive: net.connected || net.known
          expanded: page.openName === net.name
          onClicked: page.activate(net)
          onTrailingClicked: page.open(net, "menu")

          Connections {
            target: row.net
            function onConnectionFailed(reason) {
              page.onFailed(row.net, reason);
            }
          }

          Rectangle {
            visible: page.openMode === "pw"
            width: parent.width
            height: 36
            radius: 10
            color: Theme.bg
            border.width: 1
            border.color: pw.activeFocus ? Theme.accent : Theme.bg2

            TextInput {
              id: pw
              property bool reveal: false
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 36
              verticalAlignment: TextInput.AlignVCenter
              echoMode: reveal ? TextInput.Normal : TextInput.Password
              color: Theme.fg
              font.family: Theme.font
              font.pixelSize: Theme.fontSize
              clip: true
              Keys.onReturnPressed: page.submit(row.net, text)
              Keys.onEnterPressed: page.submit(row.net, text)
              Keys.onEscapePressed: page.close()
              onVisibleChanged: {
                text = "";
                reveal = false;
                if (visible)
                  forceActiveFocus();
              }
            }
            Label {
              anchors.left: parent.left
              anchors.leftMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              visible: pw.text === ""
              text: "Password"
              color: Theme.dim
            }
            IconButton {
              anchors.right: parent.right
              anchors.rightMargin: 3
              anchors.verticalCenter: parent.verticalCenter
              size: 30
              icon: pw.reveal ? "visibility_off" : "visibility"
              iconColor: Theme.dim
              onClicked: pw.reveal = !pw.reveal
            }
          }

          Row {
            spacing: 8
            PillButton {
              visible: page.openMode === "pw"
              text: "Connect"
              filled: true
              accent: Theme.accent
              onClicked: page.submit(row.net, pw.text)
            }
            PillButton {
              visible: page.openMode === "menu" && !row.net.connected
              text: "Connect"
              filled: true
              accent: Theme.accent
              onClicked: page.activate(row.net)
            }
            PillButton {
              visible: page.openMode === "menu" && row.net.connected
              text: "Disconnect"
              onClicked: {
                page.close();
                row.net.disconnect();
              }
            }
            PillButton {
              visible: page.openMode === "menu" && row.net.known
              text: "Forget"
              accent: Theme.red
              onClicked: {
                page.close();
                row.net.forget();
              }
            }
            PillButton {
              visible: page.openMode === "pw"
              text: "Cancel"
              onClicked: page.close()
            }
          }
        }
      }
    }
  }
}
