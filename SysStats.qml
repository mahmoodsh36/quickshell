pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// read from procfs
Singleton {
  id: root
  property string mem: ".."
  property string load: ".."

  FileView {
    id: meminfo
    path: "/proc/meminfo"
    onLoaded: {
      var total = Number(/MemTotal:\s+(\d+)/.exec(text())[1]);
      var avail = Number(/MemAvailable:\s+(\d+)/.exec(text())[1]);
      root.mem = Math.round((total - avail) / total * 100) + "%";
    }
  }

  FileView {
    id: loadavg
    path: "/proc/loadavg"
    onLoaded: root.load = text().split(" ")[0]
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: {
      meminfo.reload();
      loadavg.reload();
    }
  }
}
