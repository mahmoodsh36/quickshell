pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// read from procfs
Singleton {
  id: root
  property string mem: ".."
  property string load: ".."
  property string down: ".."
  property string up: ".."
  property var lastNet: null
  // bytes, for the sysinfo popup
  property real memUsed: 0
  property real memTotal: 0
  property real swapUsed: 0
  property real swapTotal: 0

  function fmtSize(b) {
    var units = ["B", "K", "M", "G", "T"];
    var i = 0;
    while (b >= 1000 && i < units.length - 1) {
      b /= 1024;
      i++;
    }
    return (b < 10 && i > 0 ? b.toFixed(1) : Math.round(b).toString()) + units[i];
  }
  // fixed width so the bar doesn't jitter
  function fmtRate(bps) {
    return fmtSize(bps).padStart(5);
  }

  FileView {
    id: meminfo
    path: "/proc/meminfo"
    onLoaded: {
      var kb = k => Number(new RegExp(k + ":\\s+(\\d+)").exec(text())[1]) * 1024;
      root.memTotal = kb("MemTotal");
      root.memUsed = root.memTotal - kb("MemAvailable");
      root.swapTotal = kb("SwapTotal");
      root.swapUsed = root.swapTotal - kb("SwapFree");
      root.mem = Math.round(root.memUsed / root.memTotal * 100) + "%";
    }
  }

  FileView {
    id: loadavg
    path: "/proc/loadavg"
    onLoaded: root.load = text().split(" ")[0]
  }

  FileView {
    id: netdev
    path: "/proc/net/dev"
    onLoaded: {
      var rx = 0, tx = 0;
      for (var line of text().split("\n").slice(2)) {
        var m = /^\s*([^:]+):\s*(\d+)(?:\s+\d+){7}\s+(\d+)/.exec(line);
        // skip loopback and virtual bridges/veths, they'd double count
        if (!m || /^(lo|veth|docker|br-|virbr)/.test(m[1]))
          continue;
        rx += Number(m[2]);
        tx += Number(m[3]);
      }
      var now = Date.now();
      if (root.lastNet) {
        var dt = (now - root.lastNet.t) / 1000;
        root.down = root.fmtRate(Math.max(0, rx - root.lastNet.rx) / dt);
        root.up = root.fmtRate(Math.max(0, tx - root.lastNet.tx) / dt);
      }
      root.lastNet = {
        t: now,
        rx: rx,
        tx: tx
      };
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: netdev.reload()
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
