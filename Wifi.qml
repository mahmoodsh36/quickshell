pragma Singleton
import Quickshell
import Quickshell.Networking
import QtQuick

Singleton {
  id: root
  readonly property var device: Array.from(Networking.devices.values).find(d => d.type === DeviceType.Wifi) || null
  readonly property var network: device ? Array.from(device.networks.values).find(n => n.connected) || null : null
  readonly property string icon: Networking.wifiEnabled ? signalIcon(root.network ? root.network.signalStrength : 0) : "wifi_off"

  function signalIcon(s) {
    return s > 0.75 ? "signal_wifi_4_bar" : s > 0.5 ? "network_wifi_3_bar" : s > 0.25 ? "network_wifi_2_bar" : s > 0.05 ? "network_wifi_1_bar" : "signal_wifi_0_bar";
  }
}
