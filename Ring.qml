import QtQuick
import QtQuick.Shapes

// circular meter, value in 0..1, filled clockwise from the top
Item {
  id: ring
  property real value: 0
  property real thickness: 3
  property color fill: Theme.accent
  property color track: Theme.bg2
  default property alias content: inner.data

  // whole percents: polled values jitter, and each change animates (redrawing the window) for 400ms
  property real shown: Math.round(Math.max(0, Math.min(1, value)) * 100) / 100
  Behavior on shown {
    NumberAnimation {
      duration: 400
      easing.type: Easing.OutCubic
    }
  }

  implicitWidth: 34
  implicitHeight: 34

  component Arc: ShapePath {
    id: arc
    property real sweep: 360
    fillColor: "transparent"
    strokeWidth: ring.thickness
    capStyle: ShapePath.RoundCap
    PathAngleArc {
      centerX: ring.width / 2
      centerY: ring.height / 2
      radiusX: (ring.width - ring.thickness) / 2
      radiusY: (ring.height - ring.thickness) / 2
      startAngle: -90
      sweepAngle: arc.sweep
    }
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    Arc {
      strokeColor: ring.track
    }
    Arc {
      // a zero sweep would still draw the round cap
      strokeColor: ring.shown > 0.005 ? ring.fill : "transparent"
      sweep: 360 * ring.shown
    }
  }

  Item {
    id: inner
    anchors.fill: parent
  }
}
