pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// every widget reads Theme.*, so a new wallpaper repaints with no reload
Singleton {
  id: root

  // used until a wallpaper has been rendered
  readonly property var fallback: {
    "bg": "#282828", "bg1": "#3c3836", "bg2": "#504945",
    "fg": "#ebdbb2", "dim": "#928374",
    "accent": "#fabd2f", "accentFg": "#282828",
    "secondary": "#8ec07c", "tertiary": "#d3869b",
    "error": "#fb4934", "warning": "#fe8019", "success": "#b8bb26", "info": "#83a598"
  }

  property var generated: null

  // the watcher can't attach before apply.sh first creates the dir, so reload explicitly too
  Connections {
    target: Wallpapers
    function onApplied(ok: bool): void {
      if (ok)
        colorsFile.reload();
    }
  }

  FileView {
    id: colorsFile
    path: Config.themeDir + "/colors.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        root.generated = JSON.parse(text());
      } catch (e) {
        console.warn("bad generated palette: " + e);
      }
    }
    // a wallpaper chosen but never rendered, e.g. on a fresh state dir
    onLoadFailed: err => {
      if (err === FileViewError.FileNotFound)
        Wallpapers.apply();
    }
  }

  // per key, so a partial generated file never leaves a role unset
  readonly property var palette: Object.assign({}, fallback, generated)

  // one fade drives every role; a switch mid fade starts from what is on screen
  readonly property var roles: Object.keys(fallback)
  property var fadeFrom: palette
  property var fadeTo: palette
  property real fadeT: 1

  onPaletteChanged: {
    const shown = {};
    for (const r of roles)
      shown[r] = mix(r);
    fadeFrom = shown;
    fadeTo = palette;
    fade.restart();
  }

  NumberAnimation {
    id: fade
    target: root
    property: "fadeT"
    from: 0
    to: 1
    duration: 600
    easing.type: Easing.InOutQuad
  }

  // tint with transparent coerces a hex string to a color
  function mix(role) {
    const a = Qt.tint(fadeFrom[role], "transparent"), b = Qt.tint(fadeTo[role], "transparent");
    return Qt.rgba(a.r + (b.r - a.r) * fadeT, a.g + (b.g - a.g) * fadeT, a.b + (b.b - a.b) * fadeT, 1);
  }

  readonly property color bg: mix("bg")
  readonly property color bg1: mix("bg1")
  readonly property color bg2: mix("bg2")
  readonly property color fg: mix("fg")
  readonly property color dim: mix("dim")
  readonly property color accent: mix("accent")
  readonly property color accentFg: mix("accentFg")
  readonly property color secondary: mix("secondary")
  readonly property color tertiary: mix("tertiary")
  readonly property color error: mix("error")
  readonly property color warning: mix("warning")
  readonly property color success: mix("success")
  readonly property color info: mix("info")

  // c with a faint fg wash
  function hover(c) {
    const wash = Qt.rgba(fg.r, fg.g, fg.b, 0.08);
    return c.a === 0 ? wash : Qt.tint(c, wash);
  }

  readonly property int barHeight: 34
  // bar popups and notification toasts share one slot under the bar
  readonly property int popupWidth: 360
  readonly property int popupTop: barHeight + 6
  readonly property int popupMargin: 8
  readonly property int radius: 6
  readonly property string font: "monospace"
  readonly property string iconFont: "Material Symbols Rounded"
  readonly property int fontSize: 13
  readonly property int fontSizeSmall: 11
}
