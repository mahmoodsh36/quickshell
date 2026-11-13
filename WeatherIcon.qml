import QtQuick

// weather glyph with a little life: the sun turns, clouds drift, rain bobs, storms flash
Icon {
  id: w
  property int code: Weather.code
  property bool day: Weather.isDay
  // off by default: a looping animation keeps its whole window redrawing
  property bool animate: false

  name: Weather.iconFor(code, day)
  readonly property string kind: name === "sunny" ? "spin" : ["cloud", "partly_cloudy_day", "partly_cloudy_night", "foggy"].includes(name) ? "drift" : name === "thunderstorm" ? "flash" : name.startsWith("rainy") || name === "weather_snowy" ? "bob" : ""
  color: name === "sunny" ? Theme.warning : name === "clear_night" ? Theme.tertiary : name === "thunderstorm" ? Theme.warning : kind === "bob" ? Theme.info : Theme.fg

  onKindChanged: {
    rotation = 0;
    shift.x = 0;
    shift.y = 0;
    opacity = 1;
  }
  transform: Translate {
    id: shift
  }

  RotationAnimation {
    target: w
    running: w.animate && w.kind === "spin"
    from: 0
    to: 360
    duration: 24000
    loops: Animation.Infinite
  }
  SequentialAnimation {
    running: w.animate && w.kind === "drift"
    loops: Animation.Infinite
    NumberAnimation {
      target: shift
      property: "x"
      from: -w.size * 0.08
      to: w.size * 0.08
      duration: 2600
      easing.type: Easing.InOutSine
    }
    NumberAnimation {
      target: shift
      property: "x"
      to: -w.size * 0.08
      duration: 2600
      easing.type: Easing.InOutSine
    }
  }
  SequentialAnimation {
    running: w.animate && w.kind === "bob"
    loops: Animation.Infinite
    NumberAnimation {
      target: shift
      property: "y"
      from: 0
      to: w.size * 0.07
      duration: 700
      easing.type: Easing.InOutSine
    }
    NumberAnimation {
      target: shift
      property: "y"
      to: 0
      duration: 700
      easing.type: Easing.InOutSine
    }
  }
  SequentialAnimation {
    running: w.animate && w.kind === "flash"
    loops: Animation.Infinite
    PauseAnimation {
      duration: 3200
    }
    NumberAnimation {
      target: w
      property: "opacity"
      to: 0.35
      duration: 60
    }
    NumberAnimation {
      target: w
      property: "opacity"
      to: 1
      duration: 80
    }
    NumberAnimation {
      target: w
      property: "opacity"
      to: 0.5
      duration: 50
    }
    NumberAnimation {
      target: w
      property: "opacity"
      to: 1
      duration: 140
    }
  }
}
