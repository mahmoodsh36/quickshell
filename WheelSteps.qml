import QtQuick

// one step per 120, touchpads send small deltas; reversing drops the partial step
WheelHandler {
  property real acc: 0
  // follow whichever axis moved more, so horizontal scrolling steps too
  property bool anyAxis: false
  signal stepped(int steps)

  onWheel: event => {
    const a = event.angleDelta;
    const d = anyAxis && Math.abs(a.x) > Math.abs(a.y) ? a.x : a.y;
    if (Math.sign(d) !== Math.sign(acc))
      acc = 0;
    acc += d;
    const steps = Math.trunc(acc / 120);
    if (steps !== 0) {
      acc -= steps * 120;
      stepped(steps);
    }
  }
}
