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
    width: parent.width * slider.value
    height: 6
    radius: 3
    color: Theme.yellow
  }
  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    x: parent.width * slider.value - 7
    width: 14
    height: 14
    radius: 7
    color: Theme.fg
  }
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onPressed: mouse => slider.moved(slider.at(mouse.x))
    onPositionChanged: mouse => slider.moved(slider.at(mouse.x))
    onReleased: mouse => slider.released(slider.at(mouse.x))
  }
}
