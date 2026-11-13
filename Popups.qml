pragma Singleton
import Quickshell
import QtQuick

// owns which bar popup is open, so opening one closes the others
Singleton {
  property string current: ""
  // join each popup's focus grab so bar clicks don't dismiss it
  property var barWindows: []

  // docked styles: the bar hosting the drawer binds stage, drawerShown, locate and axis while it
  // hosts. stage is what pages are parented into, screen is where it opens
  property Item stage: null
  property var screen: null
  // drawer still on screen, possibly collapsing
  property bool drawerShown: false
  property var pages: ({})
  // set by the rail: name -> y of what opens it, so a switch slides the way the drawer travels
  property var locate: null
  // -1 up, 1 down, 0 when opening from or closing to nothing
  property int dir: 0
  // the bar's long axis, pages slide along it on switches
  property string axis: "y"
  // opened by hovering, outside clicks pass through; any click on the bar or drawer pins it
  property bool peek: false
  // set before a show() so the open lands as a peek without a catcher flicker
  property bool peekNext: false
  // Catcher takes outside clicks then: niri has no focus grab, and hyprland's would block
  // hover on the docked bar
  readonly property bool catching: current !== "" && !peek && (Style.docked || !BarState.hasGrab)

  function register(name, page) {
    const p = Object.assign({}, pages);
    p[name] = page;
    pages = p;
  }

  function open(name) {
    if (current === "") {
      screen = Focus.screen;
      dir = 0;
    } else if (name !== current) {
      dir = Style.docked && locate ? Math.sign(locate(name) - locate(current)) : 1;
    }
    peek = peekNext;
    peekNext = false;
    current = name;
  }
  function pin() {
    peek = false;
  }
  function close(name) {
    if (current === name) {
      dir = 0;
      peek = false;
      current = "";
    }
  }
}
