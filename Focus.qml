pragma Singleton
import Quickshell
import Quickshell.Hyprland

// screen with keyboard focus, the first one when the compositor doesn't say
Singleton {
  readonly property string name: Niri.active ? Niri.focusedOutput : Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
  readonly property var screen: Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0]
}
