import QtQuick

// children go in the expandable action area
Rectangle {
  id: row
  property string icon
  property string title
  property string subtitle
  property color subtitleColor: Theme.dim
  property bool highlighted: false
  property bool busy: false
  property string trailingIcon: ""
  property bool trailingInteractive: false
  property bool expanded: false
  default property alias actions: actionArea.data
  signal clicked
  signal trailingClicked

  width: parent ? parent.width : 0
  implicitHeight: head.height + (expanded ? actionArea.implicitHeight + 12 : 0)
  radius: 12
  clip: true
  color: expanded ? Theme.bg1 : (mouse.containsMouse ? Theme.hover("transparent") : "transparent")
  Behavior on implicitHeight {
    NumberAnimation {
      duration: 150
      easing.type: Easing.OutCubic
    }
  }

  Item {
    id: head
    width: parent.width
    height: 48

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: row.clicked()
    }

    Rectangle {
      id: badge
      x: 8
      anchors.verticalCenter: parent.verticalCenter
      width: 32
      height: 32
      radius: 16
      color: row.highlighted ? Theme.accent : Theme.bg2
      Icon {
        anchors.centerIn: parent
        name: row.icon
        color: row.highlighted ? Theme.bg : Theme.fg
      }
    }

    Column {
      anchors.left: badge.right
      anchors.right: trailing.left
      anchors.leftMargin: 10
      anchors.rightMargin: 6
      anchors.verticalCenter: parent.verticalCenter
      Label {
        width: parent.width
        text: row.title
        elide: Text.ElideRight
        color: row.highlighted ? Theme.accent : Theme.fg
        font.bold: row.highlighted
      }
      Label {
        width: parent.width
        visible: text !== ""
        text: row.subtitle
        elide: Text.ElideRight
        color: row.subtitleColor
        font.pixelSize: Theme.fontSizeSmall
      }
    }

    Item {
      id: trailing
      anchors.right: parent.right
      anchors.rightMargin: 6
      anchors.verticalCenter: parent.verticalCenter
      width: 32
      height: 32
      Icon {
        anchors.centerIn: parent
        visible: row.busy
        name: "progress_activity"
        spinning: row.busy
        color: Theme.accent
      }
      IconButton {
        anchors.centerIn: parent
        visible: !row.busy && row.trailingIcon !== ""
        icon: row.trailingIcon
        iconColor: row.trailingInteractive ? Theme.fg : Theme.dim
        interactive: row.trailingInteractive
        onClicked: row.trailingClicked()
      }
    }
  }

  Column {
    id: actionArea
    anchors.top: head.bottom
    x: 50
    width: parent.width - 62
    spacing: 8
    visible: row.expanded
  }
}
