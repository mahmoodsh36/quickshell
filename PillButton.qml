import QtQuick

Rectangle {
  id: btn
  property string text
  property string icon: ""
  property color accent: Theme.fg
  property bool filled: false
  signal clicked

  readonly property color ink: filled ? Theme.bg : accent

  implicitHeight: 30
  implicitWidth: row.implicitWidth + 24
  radius: height / 2
  color: {
    var base = filled ? accent : Theme.bg2;
    return mouse.containsMouse ? Theme.hover(base) : base;
  }
  Behavior on color {
    ColorAnimation {
      duration: 120
    }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 6
    Icon {
      visible: btn.icon !== ""
      name: btn.icon
      size: 16
      color: btn.ink
    }
    Label {
      text: btn.text
      color: btn.ink
      font.pixelSize: Theme.fontSizeSmall + 1
      font.bold: true
    }
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: btn.clicked()
  }
}
