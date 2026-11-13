pragma Singleton
import Quickshell
import QtQuick

// which desktop layout is live. a switch first lets the old bar play its exit (leaving), then
// swaps shown so the new one loads and plays its entrance
Singleton {
  id: root
  readonly property var names: ["top", "rail", "rail-right", "island", "dock"]
  readonly property var labels: ({ "top": "Top bar", "rail": "Rail", "rail-right": "Right rail", "island": "Island", "dock": "Dock" })
  readonly property var icons: ({ "top": "web_asset", "rail": "view_sidebar", "rail-right": "right_panel_open", "island": "toast", "dock": "dock_to_bottom" })
  readonly property string current: names.includes(Persist.style) ? Persist.style : names[0]
  readonly property int exitMs: 260

  property string shown: current
  readonly property bool leaving: shown !== current
  onCurrentChanged: swap.restart()
  Timer {
    id: swap
    interval: root.exitMs
    onTriggered: root.shown = root.current
  }

  readonly property bool rail: shown === "rail" || shown === "rail-right"
  readonly property bool railRight: shown === "rail-right"
  // every style but the top bar hosts popups in its own drawer, see Popups.stage
  readonly property bool docked: shown !== "top"

  function set(name) {
    if (names.includes(name))
      Persist.style = name;
  }
  function cycle() {
    set(names[(names.indexOf(current) + 1) % names.length]);
  }
}
