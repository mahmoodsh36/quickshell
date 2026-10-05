pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// system details popup, opened from the bar's stats pill. polls only while open.
Singleton {
  id: root
  property bool open: false
  property var barWindows: []

  property string host: ""
  property string kernel: ""
  property real uptime: 0
  property var loads: []
  property int cpu: -1
  property var lastCpu: null
  property real temp: -1
  property var disks: []
  property var procs: []

  function show() {
    ControlCenter.hide();
    Calendar.hide();
    lastCpu = null;
    open = true;
    refresh();
  }
  function hide() {
    open = false;
  }
  function toggle() {
    if (open)
      hide();
    else
      show();
  }

  function refresh() {
    stat.reload();
    uptimeFile.reload();
    loadavg.reload();
    if (!probe.running)
      probe.running = true;
  }

  function fmtUptime(s) {
    var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
    return d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "m" : m + "m";
  }
  function levelColor(frac) {
    return frac >= 0.9 ? Theme.red : frac >= 0.75 ? Theme.orange : Theme.accent;
  }

  FileView {
    path: "/proc/sys/kernel/hostname"
    onLoaded: root.host = text().trim()
  }
  FileView {
    path: "/proc/sys/kernel/osrelease"
    onLoaded: root.kernel = text().trim()
  }
  FileView {
    id: uptimeFile
    path: "/proc/uptime"
    onLoaded: root.uptime = Number(text().split(" ")[0])
  }
  FileView {
    id: loadavg
    path: "/proc/loadavg"
    onLoaded: root.loads = text().split(" ").slice(0, 3)
  }
  FileView {
    id: stat
    path: "/proc/stat"
    onLoaded: {
      var f = text().split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
      var total = f.reduce((a, b) => a + b, 0);
      // idle + iowait
      var idle = f[3] + f[4];
      if (root.lastCpu && total > root.lastCpu.total)
        root.cpu = Math.round(100 * (1 - (idle - root.lastCpu.idle) / (total - root.lastCpu.total)));
      root.lastCpu = {
        total: total,
        idle: idle
      };
    }
  }

  // temps, disks, and top's second sample (the first is averaged since boot)
  Process {
    id: probe
    environment: ({
        LC_ALL: "C"
      })
    command: ["sh", "-c", `
      echo @temp
      for h in /sys/class/hwmon/hwmon*; do
        n=$(cat $h/name 2>/dev/null)
        for t in $h/temp*_input; do [ -r "$t" ] && echo "$n $(cat $t)"; done
      done
      echo @df
      df -P -T -B1 -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs -x ramfs | tail -n +2
      echo @top
      top -b -n 2 -d 1 -o %CPU -w 512 | awk '/^ *PID/ { n++; next } n == 2 && NF' | head -n 6
    `]
    stdout: StdioCollector {
      onStreamFinished: root.ingest(text)
    }
  }

  function ingest(out) {
    var sec = {};
    var cur = null;
    for (var line of out.split("\n")) {
      if (line.startsWith("@"))
        sec[cur = line.slice(1)] = [];
      else if (cur && line.trim() !== "")
        sec[cur].push(line.trim());
    }

    // prefer the cpu package sensor, else the hottest
    var best = -1, hottest = -1;
    for (var l of sec.temp || []) {
      var [name, v] = l.split(" ");
      v = Number(v) / 1000;
      hottest = Math.max(hottest, v);
      if (best < 0 && /^(coretemp|k10temp|zenpower|cpu_thermal)$/.test(name))
        best = v;
    }
    temp = best >= 0 ? best : hottest;

    // bind mounts and subvolumes show the same device again
    var seen = {};
    var ds = [];
    for (var l of sec.df || []) {
      var f = l.split(/\s+/);
      if (f.length < 7 || seen[f[0]] || f[6].startsWith("/nix/store"))
        continue;
      seen[f[0]] = true;
      ds.push({
        mount: f.slice(6).join(" "),
        type: f[1],
        size: Number(f[2]),
        used: Number(f[3])
      });
    }
    disks = ds;

    // PID USER PR NI VIRT RES SHR S %CPU %MEM TIME+ COMMAND
    procs = (sec.top || []).map(l => l.split(/\s+/)).filter(f => f.length >= 12 && f[11] !== "top").slice(0, 5).map(f => ({
          name: f.slice(11).join(" "),
          cpu: Number(f[8]),
          mem: Number(f[9])
        }));
  }

  Timer {
    interval: 2000
    running: root.open
    repeat: true
    onTriggered: root.refresh()
  }

  component Meter: Rectangle {
    id: meter
    property real value: 0
    height: 6
    radius: 3
    color: Theme.bg2
    Rectangle {
      width: Math.max(6, meter.width * Math.min(1, meter.value))
      height: meter.height
      radius: 3
      color: root.levelColor(meter.value)
      Behavior on width {
        NumberAnimation {
          duration: 200
        }
      }
    }
  }

  // label, right-aligned value, meter
  component Stat: Column {
    id: st
    property string icon
    property string title
    property string detail
    property real value: -1
    width: parent.width
    spacing: 6
    Item {
      width: parent.width
      height: 18
      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Icon {
          anchors.verticalCenter: parent.verticalCenter
          name: st.icon
          size: 16
          color: Theme.dim
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: st.title
          elide: Text.ElideMiddle
        }
      }
      Label {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: st.detail
        color: Theme.dim
        font.pixelSize: Theme.fontSizeSmall
      }
    }
    Meter {
      visible: st.value >= 0
      width: parent.width
      value: Math.max(0, st.value)
    }
  }

  component Section: Label {
    leftPadding: 4
    color: Theme.dim
    font.pixelSize: Theme.fontSizeSmall
    font.bold: true
  }

  component Divider: Rectangle {
    width: parent.width
    height: 1
    color: Theme.bg2
  }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: panel
      required property var modelData
      screen: modelData
      visible: root.open && (Hyprland.focusedMonitor ? modelData.name === Hyprland.focusedMonitor.name : true)
      focusable: true
      anchors {
        top: true
        right: true
      }
      margins {
        top: Theme.barHeight + 6
        right: 8
      }
      exclusionMode: ExclusionMode.Ignore
      implicitWidth: 360
      implicitHeight: content.implicitHeight + 32
      color: "transparent"

      onVisibleChanged: {
        if (visible)
          frame.forceActiveFocus();
      }

      HyprlandFocusGrab {
        active: panel.visible
        windows: [panel].concat(Array.from(root.barWindows))
        onCleared: root.hide()
      }

      Rectangle {
        id: frame
        anchors.fill: parent
        color: Theme.bg
        border.width: 1
        border.color: Theme.bg2
        radius: 20
        focus: true
        Keys.onEscapePressed: root.hide()

        Column {
          id: content
          anchors.fill: parent
          anchors.margins: 16
          spacing: 12

          Column {
            leftPadding: 4
            Label {
              text: root.host
              font.pixelSize: Theme.fontSize + 5
              font.bold: true
            }
            Label {
              text: "linux " + root.kernel + " · up " + root.fmtUptime(root.uptime)
              color: Theme.dim
              font.pixelSize: Theme.fontSizeSmall
            }
          }

          Divider {}

          Stat {
            icon: "developer_board"
            title: "CPU " + (root.cpu >= 0 ? root.cpu + "%" : "..")
            detail: (root.temp >= 0 ? Math.round(root.temp) + "°C  " : "") + "load " + root.loads.join(" ")
            value: root.cpu >= 0 ? root.cpu / 100 : 0
          }
          Stat {
            icon: "memory"
            title: "Memory"
            detail: SysStats.fmtSize(SysStats.memUsed) + " / " + SysStats.fmtSize(SysStats.memTotal)
            value: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal : 0
          }
          Stat {
            visible: SysStats.swapTotal > 0
            icon: "swap_horiz"
            title: "Swap"
            detail: SysStats.fmtSize(SysStats.swapUsed) + " / " + SysStats.fmtSize(SysStats.swapTotal)
            value: SysStats.swapUsed / Math.max(1, SysStats.swapTotal)
          }
          Stat {
            icon: "swap_vert"
            title: "↓" + SysStats.down.trim() + "/s  ↑" + SysStats.up.trim() + "/s"
            detail: SysStats.lastNet ? "since boot ↓" + SysStats.fmtSize(SysStats.lastNet.rx) + " ↑" + SysStats.fmtSize(SysStats.lastNet.tx) : ""
          }

          Divider {}
          Section {
            text: "DISKS"
          }

          Repeater {
            model: root.disks
            Stat {
              required property var modelData
              icon: "hard_drive"
              title: modelData.mount
              detail: SysStats.fmtSize(modelData.used) + " / " + SysStats.fmtSize(modelData.size) + "  " + modelData.type
              value: modelData.used / Math.max(1, modelData.size)
            }
          }

          Divider {
            visible: root.procs.length > 0
          }
          Section {
            visible: root.procs.length > 0
            text: "TOP PROCESSES"
          }

          Column {
            width: parent.width
            spacing: 4
            Repeater {
              model: root.procs
              Item {
                required property var modelData
                width: parent.width
                height: 18
                Label {
                  anchors.left: parent.left
                  anchors.leftMargin: 4
                  anchors.right: nums.left
                  anchors.rightMargin: 8
                  text: modelData.name
                  elide: Text.ElideRight
                }
                Label {
                  id: nums
                  anchors.right: parent.right
                  text: (modelData.cpu.toFixed(1) + "%").padStart(6) + (modelData.mem.toFixed(1) + "%").padStart(7)
                  color: Theme.dim
                  font.pixelSize: Theme.fontSizeSmall
                }
              }
            }
          }
        }
      }
    }
  }
}
