pragma Singleton
import Quickshell
import QtQuick

// owns which bar popup is open, so opening one closes the others
Singleton {
  property string current: ""
  // join each popup's focus grab so bar clicks don't dismiss it
  property var barWindows: []

  function open(name) {
    current = name;
  }
  function close(name) {
    if (current === name)
      current = "";
  }
}
