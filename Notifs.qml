pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import QtQuick

// notification daemon. history lives in the control center, popups top right.
Singleton {
  id: root
  readonly property var history: Array.from(server.trackedNotifications.values).reverse()
  // newest first
  property var popups: []
  property var flown: []

  function drop(n) {
    popups = popups.filter(p => p !== n);
  }
  function clear() {
    for (const n of history)
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
      if (!root.popups.includes(n) && (!Persist.dnd || n.urgency === NotificationUrgency.Critical))
        root.popups = [n].concat(root.popups);
    }
  }

  PanelWindow {
    id: win
    screen: Focus.screen
    visible: root.popups.length > 0
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    // beside a left rail, else top right
    readonly property bool leftSide: Style.rail && !Style.railRight
    anchors {
      top: true
      left: leftSide
      right: !leftSide
    }
    margins {
      top: Theme.popupTop
      left: Theme.railWidth + Theme.popupMargin
      right: Theme.popupMargin + (Style.railRight ? Theme.railWidth : 0)
    }
    implicitWidth: Theme.popupWidth
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

          // the repeater rebuilds on every change, so only a card not seen before flies in
          Component.onCompleted: {
            if (root.flown.includes(notif))
              return;
            root.flown = [notif].concat(root.flown).slice(0, 8);
            flyIn.start();
          }
          ParallelAnimation {
            id: flyIn
            NumberAnimation {
              target: card
              property: "x"
              from: (win.leftSide ? -1 : 1) * 80
              to: 0
              duration: 380
              easing.type: Easing.OutBack
              easing.overshoot: 0.8
            }
            NumberAnimation {
              target: card
              property: "opacity"
              from: 0
              to: 1
              duration: 220
            }
          }

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
