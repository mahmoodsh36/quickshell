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

  // not an Animator: those run on the render thread without frame throttling on wayland (hundreds of fps)
  RotationAnimation on rotation {
    // a hidden spinner (a closed page in a drawer) would still redraw its window
    running: icon.spinning && icon.visible
    from: 0
    to: 360
    duration: 1600
    loops: Animation.Infinite
  }
  onSpinningChanged: {
    if (!spinning)
      rotation = 0;
  }
}
