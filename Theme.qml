pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// every widget reads Theme.*, so switching repaints with no reload.
Singleton {
  id: root

  readonly property var themeNames: ["gruvbox", "tokyonight"]

  readonly property var palettes: {
    "gruvbox": {
      "bg": "#282828", "bg1": "#3c3836", "bg2": "#504945",
      "fg": "#ebdbb2", "dim": "#928374",
      "yellow": "#fabd2f", "orange": "#fe8019", "green": "#b8bb26",
      "red": "#fb4934", "blue": "#83a598", "aqua": "#8ec07c"
    },
    "tokyonight": {
      "bg": "#1a1b26", "bg1": "#24283b", "bg2": "#414868",
      "fg": "#c0caf5", "dim": "#565f89",
      "yellow": "#e0af68", "orange": "#ff9e64", "green": "#9ece6a",
      "red": "#f7768e", "blue": "#7aa2f7", "aqua": "#7dcfff"
    }
  }

  // state lives beside the config, not in it: the config dir is a
  // read-only nix store path, and home-manager must not own this file
  // either (it would reset the theme on every rebuild).
  FileView {
    id: stateFile
    path: Quickshell.env("HOME") + "/.config/quickshell/shell-state.json"
    blockLoading: true
    watchChanges: true
    // missing file on first run is the normal case, not an error
    printErrors: false
    onFileChanged: reload()
    JsonAdapter {
      id: state
      property string theme: "gruvbox"
    }
  }

  property alias themeName: state.theme

  readonly property var palette: palettes.hasOwnProperty(themeName) ? palettes[themeName] : palettes["gruvbox"]

  readonly property color bg: palette.bg
  readonly property color bg1: palette.bg1
  readonly property color bg2: palette.bg2
  readonly property color fg: palette.fg
  readonly property color dim: palette.dim
  readonly property color yellow: palette.yellow
  readonly property color orange: palette.orange
  readonly property color green: palette.green
  readonly property color red: palette.red
  readonly property color blue: palette.blue
  readonly property color aqua: palette.aqua

  function setTheme(name) {
    if (palettes.hasOwnProperty(name)) {
      state.theme = name;
      stateFile.writeAdapter();
    } else {
      console.warn("unknown theme: " + name + " (want " + themeNames.join(" ") + ")");
    }
  }

  function nextTheme() {
    setTheme(themeNames[(themeNames.indexOf(themeName) + 1) % themeNames.length]);
  }

  readonly property int barHeight: 34
  readonly property int radius: 6
  readonly property string font: "monospace"
  readonly property int fontSize: 13
}
