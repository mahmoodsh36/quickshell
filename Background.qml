import Quickshell
import Quickshell.Wayland
import QtQuick

// draws Persist.wallpaper on every screen
Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData
      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.namespace: "quickshell-wallpaper"
      exclusionMode: ExclusionMode.Ignore
      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }
      color: Theme.bg

      // sourceSize keeps the decode at screen size; no cache so a replaced image is freed
      Crossfade {
        anchors.fill: parent
        source: Wallpapers.url(Persist.wallpaper)
        sourceSize: Qt.size(win.modelData.width, win.modelData.height)
        cache: false
        duration: 750
        fromScale: 1.05
      }
    }
  }
}
