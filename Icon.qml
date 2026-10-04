import QtQuick

// material symbols, by ligature name
Text {
  id: icon
  property string name
  property real size: 18
  property bool spinning: false

  text: name
  color: Theme.fg
  font.family: Theme.iconFont
  font.pixelSize: size
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter

  RotationAnimator on rotation {
    running: icon.spinning
    from: 0
    to: 360
    duration: 1000
    loops: Animation.Infinite
  }
  onSpinningChanged: {
    if (!spinning)
      rotation = 0;
  }
}
