pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// everything the shell persists, in one file under the state dir (shell.qml pins ShellId so
// the live checkout and the store copy share it)
Singleton {
  property alias wallpaper: adapter.wallpaper
  property alias colorMode: adapter.colorMode
  property alias scheme: adapter.scheme
  property alias dnd: adapter.dnd

  FileView {
    path: Quickshell.statePath("state.json")
    blockLoading: true
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()
    onLoadFailed: err => {
      if (err === FileViewError.FileNotFound)
        writeAdapter();
    }

    JsonAdapter {
      id: adapter
      property string wallpaper: ""
      property string colorMode: "dark"
      // a matugen scheme type
      property string scheme: "scheme-tonal-spot"
      property bool dnd: false
    }
  }
}
