import QtQuick

Rectangle {
  id: toggle
  property bool checked: false
  signal toggled

  implicitWidth: 52
  implicitHeight: 24
  radius: 12
  color: checked ? Theme.green : Theme.bg2
  Behavior on color {
    ColorAnimation {
      duration: 150
    }
  }

  Label {
    anchors.centerIn: parent
    text: toggle.checked ? "ON" : "OFF"
    color: Theme.bg
    font.pixelSize: Theme.fontSizeSmall
    font.bold: true
  }
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: toggle.toggled()
  }
}
