pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// wf-recorder, toggled from xremap. region asks slurp for an area first.
Singleton {
  id: root
  readonly property bool active: proc.running
  property string file: ""
  property real startedAt: 0
  property int elapsed: 0

  function toggle(region) {
    if (proc.running) {
      // SIGINT lets wf-recorder finalize the file
      proc.signal(2);
      return;
    }
    file = Quickshell.env("HOME") + "/data/videos/recs/" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss") + ".mp4";
    proc.exec(["sh", "-c", 'mkdir -p "$(dirname "$1")"; if [ -n "$2" ]; then g=$(slurp) || exit 1; fi; exec wf-recorder ${g:+-g "$g"} -f "$1"', "sh", file, region ? "1" : ""]);
  }

  Process {
    id: proc
    onStarted: {
      root.startedAt = Date.now();
      root.elapsed = 0;
    }
    onExited: code => {
      if (code === 0)
        Quickshell.execDetached(["notify-send", "-a", "Recorder", "Recording saved", root.file]);
    }
  }

  Timer {
    running: root.active
    interval: 1000
    repeat: true
    onTriggered: root.elapsed = (Date.now() - root.startedAt) / 1000
  }
}
