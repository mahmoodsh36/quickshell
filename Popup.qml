import Quickshell
import Quickshell.Hyprland
import QtQuick

PanelWindow {
  id: win
  required property string name
  property string side: "right"
  readonly property bool open: Popups.current === name
  default property alias content: body.data
  // unaccepted escape closes the popup
  signal keyPressed(var event)

  // pinned at open so it doesn't jump screens while focus wanders
  visible: false
  onOpenChanged: {
    if (win.open)
      win.screen = Focus.screen;
    win.visible = win.open;
  }
  onVisibleChanged: {
    if (win.visible)
      frame.forceActiveFocus();
  }

  focusable: true
  anchors {
    top: true
    left: win.side === "left"
    right: win.side === "right"
  }
  margins {
    top: Theme.popupTop
    left: win.side === "left" ? Theme.popupMargin : 0
    right: win.side === "right" ? Theme.popupMargin : 0
  }
  // ignore the bar reservation so margins measure from the screen edge
  exclusionMode: ExclusionMode.Ignore
  implicitWidth: Theme.popupWidth
  implicitHeight: body.implicitHeight + 32
  color: "transparent"

  HyprlandFocusGrab {
    active: win.visible
    windows: [win].concat(Array.from(Popups.barWindows))
    onCleared: Popups.close(win.name)
  }

  Rectangle {
    id: frame
    anchors.fill: parent
    color: Theme.bg
    border.width: 1
    border.color: Theme.bg2
    radius: 20
    focus: true
    Keys.onPressed: event => {
      win.keyPressed(event);
      if (!event.accepted && event.key === Qt.Key_Escape) {
        Popups.close(win.name);
        event.accepted = true;
      }
    }

    Column {
      id: body
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 16
    }
  }
}
