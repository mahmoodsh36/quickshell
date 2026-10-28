import QtQuick

Item {
  id: slider
  property real value: 0
  signal moved(real v)
  signal released(real v)

  function at(x) {
    return Math.min(1, Math.max(0, x / width));
  }

  implicitHeight: 24

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: 6
    radius: 3
    color: Theme.bg2
  }
  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(6, parent.width * slider.value)
    height: 6
    radius: 3
    color: Theme.accent
  }
  Rectangle {
    property real d: mouse.pressed ? 16 : (mouse.containsMouse ? 14 : 12)
    anchors.verticalCenter: parent.verticalCenter
    x: (parent.width - width) * slider.value
    width: d
    height: d
    radius: d / 2
    color: Theme.fg
    Behavior on d {
      NumberAnimation {
        duration: 100
      }
    }
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPressed: event => slider.moved(slider.at(event.x))
    onPositionChanged: event => {
      if (pressed)
        slider.moved(slider.at(event.x));
    }
    onReleased: event => slider.released(slider.at(event.x))
  }
}
