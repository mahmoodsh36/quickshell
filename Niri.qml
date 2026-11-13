pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// niri's workspaces and windows from its json event stream; idle outside niri
Singleton {
  id: root
  readonly property bool active: !!Quickshell.env("NIRI_SOCKET")

  // sorted by output, then index
  property var workspaces: []
  property var windows: []
  readonly property var focusedWorkspace: workspaces.find(w => w.is_focused) || null
  readonly property string focusedOutput: focusedWorkspace ? focusedWorkspace.output || "" : ""
  readonly property var focusedWindow: windows.find(w => w.is_focused) || null

  function action(args) {
    Quickshell.execDetached(["niri", "msg", "action"].concat(args));
  }

  function patch(list, match, change) {
    return list.map(x => match(x) ? Object.assign({}, x, change(x)) : x);
  }

  function handle(line) {
    let ev;
    try {
      ev = JSON.parse(line);
    } catch (e) {
      return;
    }
    const kind = Object.keys(ev)[0], e = ev[kind];
    if (kind === "WorkspacesChanged") {
      workspaces = e.workspaces.sort((a, b) => (a.output || "").localeCompare(b.output || "") || a.idx - b.idx);
    } else if (kind === "WorkspaceActivated") {
      const ws = workspaces.find(w => w.id === e.id);
      if (!ws)
        return;
      workspaces = workspaces.map(w => Object.assign({}, w, w.output === ws.output ? { is_active: w.id === e.id } : {}, e.focused ? { is_focused: w.id === e.id } : {}));
    } else if (kind === "WorkspaceActiveWindowChanged") {
      workspaces = patch(workspaces, w => w.id === e.workspace_id, () => ({ active_window_id: e.active_window_id }));
    } else if (kind === "WindowsChanged") {
      windows = e.windows.sort((a, b) => a.id - b.id);
    } else if (kind === "WindowOpenedOrChanged") {
      const w = e.window;
      const rest = windows.filter(x => x.id !== w.id).map(x => w.is_focused && x.is_focused ? Object.assign({}, x, { is_focused: false }) : x);
      windows = rest.concat([w]).sort((a, b) => a.id - b.id);
    } else if (kind === "WindowClosed") {
      windows = windows.filter(x => x.id !== e.id);
    } else if (kind === "WindowFocusChanged") {
      windows = windows.map(x => x.is_focused === (x.id === e.id) ? x : Object.assign({}, x, { is_focused: x.id === e.id }));
    }
  }

  Process {
    id: stream
    running: root.active
    command: ["niri", "msg", "--json", "event-stream"]
    stdout: SplitParser {
      onRead: line => root.handle(line)
    }
    // the stream ends when niri restarts or reloads oddly, reconnect
    onRunningChanged: {
      if (!running && root.active)
        reconnect.start();
    }
  }
  Timer {
    id: reconnect
    interval: 1000
    onTriggered: stream.running = true
  }
}
