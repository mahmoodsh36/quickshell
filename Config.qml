pragma Singleton
import Quickshell
import QtQuick

// machine specific knobs, each overridable from the environment so the shell runs anywhere
Singleton {
  readonly property string home: Quickshell.env("HOME")
  readonly property string dataDir: env("data", home + "/data")

  // argv prefix that runs a command in a new terminal window
  readonly property var terminalExec: env("QS_TERMINAL_EXEC", "wezterm start --").split(" ")
  readonly property var screenshotCmd: ["myscrot.sh"]
  readonly property var screenshotRegionCmd: ["myscrot.sh", "1"]
  readonly property string recordingsDir: env("QS_RECORDINGS_DIR", dataDir + "/videos/recs")
  readonly property string notesDir: env("NOTES_DIR", home + "/brain/notes")
  readonly property string wallpaperDir: env("QS_WALLPAPER_DIR", dataDir + "/images/wal")

  // generated theme outputs other apps read; must match theming/matugen.toml
  readonly property string themeDir: env("XDG_STATE_HOME", home + "/.local/state") + "/theme"

  function env(name, fallback) {
    const v = Quickshell.env(name);
    return v ? String(v) : fallback;
  }
}
