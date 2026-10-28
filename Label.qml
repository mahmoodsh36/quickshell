import QtQuick

Text {
  id: label
  property bool clickable: false
  signal clicked

  color: Theme.fg
  font.family: Theme.font
  font.pixelSize: Theme.fontSize

  MouseArea {
    anchors.fill: parent
    enabled: label.clickable
    cursorShape: Qt.PointingHandCursor
    onClicked: label.clicked()
  }
}
