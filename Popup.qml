import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

// a bar popup. its page lives in its own window under the top bar, or in the rail's drawer
Scope {
  id: root
  required property string name
  property string side: "right"
  readonly property bool open: Popups.current === name
  readonly property bool docked: Style.docked
  default property alias content: body.data
  // false once nothing of it is on screen, so a launch from it isn't captured
  readonly property bool mapped: docked ? page.visible || Popups.drawerShown : win.backingWindowVisible
  // unaccepted escape closes the popup
  signal keyPressed(var event)

  Component.onCompleted: {
    Popups.register(name, page);
    page.fade = open ? 1 : 0;
  }

  // the window is pinned to a screen at open so it doesn't jump while focus wanders
  onOpenChanged: {
    if (open)
      win.screen = Focus.screen;
    win.visible = open && !docked;
    if (docked) {
      enter.stop();
      leave.stop();
      (open ? enter : leave).start();
    }
    if (open)
      page.forceActiveFocus();
  }
  onDockedChanged: {
    enter.stop();
    leave.stop();
    page.fade = open ? 1 : 0;
    page.slide = 0;
    win.visible = open && !docked;
    if (open)
      Qt.callLater(() => page.forceActiveFocus());
  }

  HyprlandFocusGrab {
    active: !root.docked && win.visible
    windows: [win].concat(Array.from(Popups.barWindows))
    onCleared: Popups.close(root.name)
  }

  FocusScope {
    id: page
    // rail only, animated on switches
    property real fade: 1
    property real slide: 0

    parent: root.docked ? Popups.stage : frame
    x: 16 + (Popups.axis === "x" ? slide : 0)
    y: 16 + (Popups.axis === "y" ? slide : 0)
    width: Theme.popupWidth - 32
    height: body.implicitHeight
    opacity: root.docked ? fade : 1
    scale: root.docked ? 0.96 + 0.04 * fade : 1
    transformOrigin: Popups.axis === "x" ? (Popups.dir < 0 ? Item.Right : Item.Left) : (Popups.dir < 0 ? Item.Bottom : Item.Top)
    visible: opacity > 0
    focus: true
    Keys.onPressed: event => {
      root.keyPressed(event);
      if (!event.accepted && event.key === Qt.Key_Escape) {
        Popups.close(root.name);
        event.accepted = true;
      }
    }

    Column {
      id: body
      width: parent.width
    }
  }

  // the new page rises in from where the drawer is heading, the old one drifts off the other way
  ParallelAnimation {
    id: enter
    NumberAnimation {
      target: page
      property: "fade"
      from: 0
      to: 1
      duration: 280
      easing.type: Easing.OutCubic
    }
    NumberAnimation {
      target: page
      property: "slide"
      from: Popups.dir * 40
      to: 0
      duration: 420
      easing.type: Easing.OutQuint
    }
  }
  ParallelAnimation {
    id: leave
    NumberAnimation {
      target: page
      property: "fade"
      to: 0
      duration: 160
      easing.type: Easing.InQuad
    }
    NumberAnimation {
      target: page
      property: "slide"
      to: -Popups.dir * 40
      duration: 220
      easing.type: Easing.InCubic
    }
  }

  PanelWindow {
    id: win
    visible: false
    WlrLayershell.keyboardFocus: BarState.hasGrab ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive
    anchors {
      top: true
      left: root.side === "left"
      right: root.side === "right"
    }
    margins {
      top: Theme.popupTop
      left: root.side === "left" ? Theme.popupMargin : 0
      right: root.side === "right" ? Theme.popupMargin : 0
    }
    // ignore the bar reservation so margins measure from the screen edge
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Theme.popupWidth
    implicitHeight: page.height + 32
    color: "transparent"

    Rectangle {
      id: frame
      anchors.fill: parent
      color: Theme.bg
      border.width: 1
      border.color: Theme.bg2
      radius: 20
    }
  }
}
