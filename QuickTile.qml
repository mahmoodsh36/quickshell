import QtQuick

// body toggles, chevron opens details
Rectangle {
  id: tile
  property string icon
  property string title
  property string subtitle
  property bool active: false
  // shows the chevron
  property bool expandable: true
  signal toggled
  signal opened

  readonly property color ink: active ? Theme.bg : Theme.fg

  implicitHeight: 60
  radius: 16
  color: active ? Theme.accent : Theme.bg1
  Behavior on color {
    ColorAnimation {
      duration: 150
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: parent.radius
    color: Theme.hover("transparent")
    visible: body.containsMouse || more.containsMouse
  }

  MouseArea {
    id: body
    anchors.left: parent.left
    anchors.right: more.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: tile.toggled()
  }

  Row {
    anchors.left: parent.left
    anchors.right: divider.left
    anchors.leftMargin: 14
    anchors.rightMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    spacing: 10
    Icon {
      anchors.verticalCenter: parent.verticalCenter
      name: tile.icon
      size: 22
      color: tile.ink
    }
    Column {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 32
      Label {
        width: parent.width
        text: tile.title
        color: tile.ink
        font.bold: true
        elide: Text.ElideRight
      }
      Label {
        width: parent.width
        text: tile.subtitle
        color: tile.ink
        opacity: 0.75
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideRight
      }
    }
  }

  Rectangle {
    id: divider
    visible: tile.expandable
    anchors.right: more.left
    anchors.verticalCenter: parent.verticalCenter
    width: 1
    height: parent.height - 28
    color: tile.ink
    opacity: 0.2
  }

  MouseArea {
    id: more
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: tile.expandable ? 34 : 0
    visible: tile.expandable
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: tile.opened()
    Icon {
      anchors.centerIn: parent
      name: "chevron_right"
      size: 20
      color: tile.ink
    }
  }
}
