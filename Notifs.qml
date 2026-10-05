pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import QtQuick

// notification daemon. history lives in the control center, popups top right.
Singleton {
  id: root
  property bool dnd: false
  readonly property var history: Array.from(server.trackedNotifications.values).reverse()
  // newest first
  property var popups: []

  function drop(n) {
    popups = popups.filter(p => p !== n);
  }
  function clear() {
    for (var n of history)
      n.dismiss();
  }

  NotificationServer {
    id: server
    actionsSupported: true
    bodyMarkupSupported: true
    imageSupported: true
    onNotification: n => {
      n.tracked = true;
      n.closed.connect(() => root.drop(n));
      if (!root.popups.includes(n) && (!root.dnd || n.urgency === NotificationUrgency.Critical))
        root.popups = [n].concat(root.popups);
    }
  }

  PanelWindow {
    screen: Focus.screen
    visible: root.popups.length > 0
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors {
      top: true
      right: true
    }
    margins {
      top: Theme.barHeight + 6
      right: 8
    }
    implicitWidth: 360
    implicitHeight: stack.implicitHeight
    color: "transparent"

    Column {
      id: stack
      width: parent.width
      spacing: 8
      Repeater {
        model: root.popups.slice(0, 4)
        NotifCard {
          id: card
          required property var modelData
          notif: modelData
          width: stack.width
          border.width: 1
          border.color: Theme.bg2

          // critical ones wait for a click. expireTimeout is in seconds, <= 0 means the default
          Timer {
            running: card.notif.urgency !== NotificationUrgency.Critical && !card.hovered
            interval: card.notif.expireTimeout > 0 ? card.notif.expireTimeout * 1000 : 5000
            onTriggered: root.drop(card.notif)
          }
        }
      }
    }
  }
}
