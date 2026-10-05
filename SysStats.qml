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

  // fixed width so the bar doesn't jitter
  function fmtRate(bps) {
    var units = ["B", "K", "M", "G"];
    var i = 0;
    while (bps >= 1000 && i < units.length - 1) {
      bps /= 1024;
      i++;
    }
    var n = bps < 10 && i > 0 ? bps.toFixed(1) : Math.round(bps).toString();
    return (n + units[i]).padStart(5);
  }

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
