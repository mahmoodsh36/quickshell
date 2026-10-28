pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// wlsunset with day and night pinned to one temperature, so it stays warm until stopped
Singleton {
  id: root
  property alias active: proc.running
  property int temp: 4000

  function toggle() {
    active = !active;
  }

  Process {
    id: proc
    command: ["wlsunset", "-t", String(root.temp), "-T", String(root.temp + 1)]
  }
}
