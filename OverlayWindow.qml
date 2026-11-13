import Quickshell
import Quickshell.Wayland
import QtQuick

// once used, parks in the background layer (empty, click through, unfocused) instead of unmapping:
// a remap rebuilds the window's graphics context, which costs 100ms or more per open on virgl.
// parked windows keep their buffers; Config.keepWindows off unmaps instead.
// content should hide itself while !active
PanelWindow {
  id: win
  property bool active: false
  property int activeLayer: WlrLayer.Overlay
  property int activeFocus: WlrKeyboardFocus.Exclusive
  property bool used: active
  // two frames were committed since activating (the first may have been in flight), so the layer
  // and focus changes have landed. gate focus grabs on it: hyprland clears one made while parked
  readonly property bool settled: swaps >= 2
  property int swaps: 0
  onActiveChanged: {
    if (active && Config.keepWindows)
      used = true;
    swaps = 0;
  }
  Connections {
    target: win.active && !win.settled ? win.contentItem.Window.window : null
    function onFrameSwapped() {
      win.swaps++;
    }
  }

  visible: used
  // a layer change while unmapped is lost on the first map, so it only parks once used
  WlrLayershell.layer: active || !used ? activeLayer : WlrLayer.Background
  WlrLayershell.keyboardFocus: active ? activeFocus : WlrKeyboardFocus.None
  mask: active ? null : parked
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"

  Region {
    id: parked
  }
}
