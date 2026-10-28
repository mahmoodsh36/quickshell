import QtQuick

// read-only bar, value in 0..1
Rectangle {
  id: meter
  property real value: 0
  property color fill: Theme.accent

  implicitHeight: 6
  radius: height / 2
  color: Theme.bg2

  Rectangle {
    width: Math.max(meter.height, meter.width * Math.min(1, Math.max(0, meter.value)))
    height: meter.height
    radius: meter.radius
    color: meter.fill
    Behavior on width {
      NumberAnimation {
        duration: 120
      }
    }
  }
}
