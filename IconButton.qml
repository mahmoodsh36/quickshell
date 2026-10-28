import QtQuick

Rectangle {
  id: btn
  property alias icon: glyph.name
  property alias iconColor: glyph.color
  property alias spinning: glyph.spinning
  property real size: 32
  property color tint: "transparent"
  property bool interactive: true
  signal clicked

  implicitWidth: size
  implicitHeight: size
  radius: size / 2
  color: interactive && mouse.containsMouse ? Theme.hover(tint) : tint
  Behavior on color {
    ColorAnimation {
      duration: 120
    }
  }

  Icon {
    id: glyph
    anchors.centerIn: parent
    size: btn.size * 0.56
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    enabled: btn.interactive
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: btn.clicked()
  }
}
