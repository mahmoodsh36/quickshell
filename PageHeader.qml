import QtQuick

// children go on the right
Item {
  id: header
  property string title
  default property alias extras: right.data
  signal back

  width: parent ? parent.width : 0
  implicitHeight: 36

  IconButton {
    id: backBtn
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    icon: "arrow_back"
    onClicked: header.back()
  }
  Label {
    anchors.left: backBtn.right
    anchors.leftMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    text: header.title
    font.pixelSize: Theme.fontSize + 2
    font.bold: true
  }
  Row {
    id: right
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: 8
  }
}
