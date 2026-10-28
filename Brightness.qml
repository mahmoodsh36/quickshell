pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// backlight via brightnessctl. sysfs has no change events, so writes update value optimistically.
Singleton {
  id: root
  property real value: 0
  property bool ok: false
  // latest unwritten target, so key repeat collapses into one write
  property real pending: -1

  function refresh() {
    if (!proc.running)
      proc.exec(["brightnessctl", "-m", "-c", "backlight"]);
  }
  function set(v) {
    value = Math.min(1, Math.max(0.01, v));
    pending = value;
    flush();
  }
  function step(d) {
    set(value + d);
  }
  function flush() {
    if (proc.running || pending < 0)
      return;
    proc.exec(["sh", "-c", "brightnessctl -q -c backlight s \"$1\" && brightnessctl -m -c backlight", "sh", Math.round(pending * 100) + "%"]);
    pending = -1;
  }

  Component.onCompleted: refresh()

  Process {
    id: proc
    onRunningChanged: {
      if (!running)
        root.flush();
    }
    stdout: StdioCollector {
      // -m prints device,class,current,percent,max
      onStreamFinished: {
        var f = text.trim().split("\n")[0].split(",");
        root.ok = f.length >= 5 && Number(f[4]) > 0;
        if (root.ok && root.pending < 0)
          root.value = Number(f[2]) / Number(f[4]);
      }
    }
  }
}
