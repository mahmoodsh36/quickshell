import QtQuick

Column {
  id: empty
  property string icon
  property string text
  property bool spinning: false

  width: parent ? parent.width : 0
  topPadding: 18
  bottomPadding: 18
  spacing: 6
  Icon {
    anchors.horizontalCenter: parent.horizontalCenter
    name: empty.icon
    size: 28
    spinning: empty.spinning
    color: Theme.dim
  }
  Label {
    anchors.horizontalCenter: parent.horizontalCenter
    text: empty.text
    color: Theme.dim
  }
}
