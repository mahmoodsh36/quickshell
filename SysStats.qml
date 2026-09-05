pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// mem/load polled from procfs so the bar needs no extra daemons
Singleton {
  id: root
  property string mem: ".."
  property string load: ".."

  Process {
    id: proc
    command: ["sh", "-c", "echo \"$(free | awk '/^Mem:/{printf \"%d\", $3/$2*100}') $(cut -d' ' -f1 /proc/loadavg)\""]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        var parts = this.text.trim().split(" ");
        if (parts.length >= 2) {
          root.mem = parts[0] + "%";
          root.load = parts[1];
        }
      }
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: proc.running = true
  }
}
