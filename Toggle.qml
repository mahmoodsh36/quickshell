import QtQuick

Rectangle {
  id: toggle
  property bool checked: false
  signal toggled

  implicitWidth: 40
  implicitHeight: 22
  radius: height / 2
  color: checked ? Theme.accent : Theme.bg2
  Behavior on color {
    ColorAnimation {
      duration: 150
    }
  }

  Rectangle {
    width: 16
    height: 16
    radius: 8
    anchors.verticalCenter: parent.verticalCenter
    x: toggle.checked ? parent.width - width - 3 : 3
    color: toggle.checked ? Theme.bg : Theme.dim
    Behavior on x {
      NumberAnimation {
        duration: 150
        easing.type: Easing.OutCubic
      }
    }
  }
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: toggle.toggled()
  }
}
