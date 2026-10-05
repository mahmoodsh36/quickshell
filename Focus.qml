pragma Singleton
import Quickshell
import Quickshell.Hyprland

// screen with keyboard focus, the first one outside hyprland
Singleton {
  readonly property var screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) || Quickshell.screens[0]
}
