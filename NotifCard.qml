import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import QtQuick

// click runs the default action, x dismisses
Rectangle {
  id: card
  required property var notif
  readonly property bool hovered: mouse.containsMouse || closeHover.hovered
  readonly property var actions: Array.from(notif.actions)
  readonly property var defaultAction: actions.find(a => a.identifier === "default") || null
  readonly property var buttons: actions.filter(a => a.identifier !== "default")
  readonly property string image: {
    var src = notif.image || notif.appIcon;
    if (src === "")
      return "";
    return src.includes("://") ? src : src.startsWith("/") ? "file://" + src : Quickshell.iconPath(src, true);
  }

  implicitHeight: body.implicitHeight + 24
  radius: 16
  color: hovered ? Theme.hover(Theme.bg1) : Theme.bg1

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: card.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: {
      if (card.defaultAction) {
        card.defaultAction.invoke();
        card.notif.dismiss();
      }
    }
  }

  Rectangle {
    visible: card.notif.urgency === NotificationUrgency.Critical
    width: 4
    height: parent.height
    radius: 2
    color: Theme.red
  }

  IconImage {
    id: icon
    visible: card.image !== ""
    x: 12
    y: 12
    implicitSize: 36
    source: card.image
  }

  Column {
    id: body
    anchors.left: icon.visible ? icon.right : parent.left
    anchors.right: closeBtn.left
    anchors.leftMargin: 12
    anchors.rightMargin: 4
    y: 12
    spacing: 2

    Label {
      width: parent.width
      text: card.notif.appName
      color: Theme.dim
      font.pixelSize: Theme.fontSizeSmall
      elide: Text.ElideRight
    }
    Label {
      width: parent.width
      text: card.notif.summary
      font.bold: true
      wrapMode: Text.Wrap
      maximumLineCount: 2
      elide: Text.ElideRight
    }
    Label {
      width: parent.width
      visible: text !== ""
      text: card.notif.body
      textFormat: Text.StyledText
      color: Theme.dim
      wrapMode: Text.Wrap
      maximumLineCount: 4
      elide: Text.ElideRight
    }
    Flow {
      visible: card.buttons.length > 0
      width: parent.width
      topPadding: 6
      spacing: 6
      Repeater {
        model: card.buttons
        PillButton {
          required property var modelData
          text: modelData.text
          onClicked: {
            modelData.invoke();
            card.notif.dismiss();
          }
        }
      }
    }
  }

  IconButton {
    id: closeBtn
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 6
    size: 26
    icon: "close"
    iconColor: Theme.dim
    onClicked: card.notif.dismiss()
    // hover on the button counts as hovering the card
    HoverHandler {
      id: closeHover
    }
  }
}
