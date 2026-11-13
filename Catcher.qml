import Quickshell
import Quickshell.Wayland
import QtQuick

// closes a pinned popup on outside clicks while Popups.catching. a transparent layer per screen
// that stays mapped, so the bars (mapped later) stack above it; only its input region changes,
// so it never redraws, unlike growing the bar window over the screen
Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData
      readonly property bool active: Popups.catching && (Popups.screen || Focus.screen)?.name === modelData.name

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "quickshell-catcher"
      color: "transparent"
      mask: Region {
        item: win.active ? area : null
      }

      MouseArea {
        id: area
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: Popups.close(Popups.current)
      }
    }
  }
}
