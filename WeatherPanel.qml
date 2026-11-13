pragma Singleton
import Quickshell
import QtQuick
import QtQuick.Shapes

// forecast page, opened from the weather readout on any bar, or qs ipc call weather toggle
Singleton {
  id: root
  readonly property bool open: popup.open

  function show() {
    Popups.open("weather");
    if (Date.now() - Weather.fetchedAt > 10 * 60 * 1000)
      Weather.refresh();
  }
  function hide() {
    Popups.close("weather");
  }
  function toggle() {
    if (open)
      hide();
    else
      show();
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  function ago(t) {
    const m = Math.round((clock.date - t) / 60000);
    return m < 1 ? "just now" : m < 60 ? m + "m ago" : Math.round(m / 60) + "h ago";
  }
  // canvas wants css colors
  function css(c, a) {
    return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
  }

  Popup {
    id: popup
    name: "weather"

    Column {
      id: page
      width: parent.width
      spacing: 14

      Item {
        width: parent.width
        height: 36
        Column {
          anchors.left: parent.left
          anchors.leftMargin: 4
          anchors.verticalCenter: parent.verticalCenter
          Label {
            text: Weather.place.name || "Weather"
            font.pixelSize: Theme.fontSize + 5
            font.bold: true
          }
          Caption {
            text: Weather.error !== "" ? Weather.error + (Weather.ok ? ", updated " + root.ago(Weather.fetchedAt) : "") : Weather.ok ? "Updated " + root.ago(Weather.fetchedAt) : "Loading"
            color: Weather.error !== "" ? Theme.warning : Theme.dim
          }
        }
        IconButton {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          icon: Weather.loading ? "progress_activity" : "refresh"
          spinning: Weather.loading
          onClicked: Weather.refresh()
        }
      }

      EmptyState {
        visible: !Weather.ok
        icon: Weather.loading ? "progress_activity" : "cloud_off"
        text: Weather.loading ? "Fetching the forecast" : "No forecast yet"
      }

      Item {
        visible: Weather.ok
        width: parent.width
        height: 64

        WeatherIcon {
          id: hero
          animate: root.open
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          size: 56
        }
        Column {
          anchors.left: hero.right
          anchors.leftMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          Label {
            text: Weather.temp + "°"
            font.pixelSize: 34
            font.bold: true
          }
          Caption {
            text: Weather.label
          }
        }
        Column {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2
          Caption {
            anchors.right: parent.right
            text: "Feels " + Weather.feels + "°"
          }
          Caption {
            anchors.right: parent.right
            visible: Weather.days.length > 0
            text: Weather.days.length > 0 ? "H " + Weather.days[0].max + "°  L " + Weather.days[0].min + "°" : ""
          }
          Caption {
            anchors.right: parent.right
            text: Weather.ok ? Weather.current.relative_humidity_2m + "% · " + Math.round(Weather.current.wind_speed_10m) + " km/h" : ""
          }
        }
      }

      // the sun's path between sunrise and sunset, with where it is now
      Item {
        id: sky
        visible: Weather.ok
        width: parent.width
        height: 58
        readonly property real span: Weather.sunset - Weather.sunrise
        readonly property real frac: span > 0 ? (clock.date - Weather.sunrise) / span : -1
        readonly property bool up: frac >= 0 && frac <= 1
        readonly property real rx: (width - 80) / 2
        readonly property real ry: 34

        Shape {
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.bg2
            strokeWidth: 2
            strokeStyle: ShapePath.DashLine
            dashPattern: [2, 3]
            startX: 40
            startY: sky.ry + 4
            PathArc {
              x: sky.width - 40
              y: sky.ry + 4
              radiusX: sky.rx
              radiusY: sky.ry
            }
          }
          ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.bg2
            strokeWidth: 1
            startX: 20
            startY: sky.ry + 4
            PathLine {
              x: sky.width - 20
              y: sky.ry + 4
            }
          }
        }
        Rectangle {
          visible: sky.up
          readonly property real angle: Math.PI * (1 - sky.frac)
          x: sky.width / 2 + sky.rx * Math.cos(angle) - width / 2
          y: sky.ry + 4 - sky.ry * Math.sin(angle) - height / 2
          width: 12
          height: 12
          radius: 6
          color: Theme.warning
          Rectangle {
            anchors.centerIn: parent
            width: 22
            height: 22
            radius: 11
            color: Theme.warning
            opacity: 0.25
          }
        }
        Row {
          anchors.left: parent.left
          anchors.bottom: parent.bottom
          spacing: 4
          Icon {
            name: "wb_twilight"
            size: 14
            color: Theme.dim
          }
          Caption {
            text: Qt.formatTime(Weather.sunrise, "hh:mm")
          }
        }
        Row {
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          spacing: 4
          Caption {
            text: Qt.formatTime(Weather.sunset, "hh:mm")
          }
          Icon {
            name: "nights_stay"
            size: 14
            color: Theme.dim
          }
        }
      }

      // next 24 hours: temperature curve over rain chance bars
      Canvas {
        id: chart
        visible: Weather.hours.length > 1
        width: parent.width
        height: 116
        readonly property var hours: Weather.hours
        readonly property var colors: [Theme.accent, Theme.info, Theme.fg, Theme.dim]
        onHoursChanged: requestPaint()
        onColorsChanged: requestPaint()
        onVisibleChanged: requestPaint()

        onPaint: {
          const ctx = getContext("2d"), hs = hours, n = hs.length;
          ctx.reset();
          if (n < 2)
            return;
          const pad = 10, top = 22, bottom = 64, barTop = 72, barBottom = 92;
          const temps = hs.map(h => h.temp), lo = Math.min(...temps), hi = Math.max(...temps);
          const xAt = i => pad + i * (width - 2 * pad) / (n - 1);
          const yAt = t => bottom - (hi === lo ? 0.5 : (t - lo) / (hi - lo)) * (bottom - top);

          for (let i = 0; i < n; i++) {
            const h = (barBottom - barTop) * hs[i].pop / 100;
            ctx.fillStyle = root.css(Theme.info, 0.25 + 0.5 * hs[i].pop / 100);
            ctx.fillRect(xAt(i) - 3, barBottom - h, 6, h);
          }

          // a smooth curve through the points, midpoints as quadratic anchors
          const curve = () => {
            ctx.moveTo(xAt(0), yAt(temps[0]));
            for (let i = 1; i < n - 1; i++)
              ctx.quadraticCurveTo(xAt(i), yAt(temps[i]), (xAt(i) + xAt(i + 1)) / 2, (yAt(temps[i]) + yAt(temps[i + 1])) / 2);
            ctx.lineTo(xAt(n - 1), yAt(temps[n - 1]));
          };
          const grad = ctx.createLinearGradient(0, top, 0, bottom);
          grad.addColorStop(0, root.css(Theme.accent, 0.35));
          grad.addColorStop(1, root.css(Theme.accent, 0));
          ctx.beginPath();
          curve();
          ctx.lineTo(xAt(n - 1), bottom);
          ctx.lineTo(xAt(0), bottom);
          ctx.closePath();
          ctx.fillStyle = grad;
          ctx.fill();
          ctx.beginPath();
          curve();
          ctx.strokeStyle = root.css(Theme.accent, 1);
          ctx.lineWidth = 2;
          ctx.stroke();

          ctx.font = Theme.fontSizeSmall - 1 + "px " + Theme.font;
          ctx.textAlign = "center";
          for (let i = 0; i < n; i += 3) {
            const x = xAt(i), y = yAt(temps[i]);
            ctx.fillStyle = root.css(Theme.accent, 1);
            ctx.beginPath();
            ctx.arc(x, y, 2.5, 0, 2 * Math.PI);
            ctx.fill();
            ctx.fillStyle = root.css(Theme.fg, 1);
            ctx.fillText(Math.round(temps[i]) + "°", x, y - 8);
            ctx.fillStyle = root.css(Theme.dim, 1);
            ctx.fillText(i === 0 ? "now" : Qt.formatTime(hs[i].time, "hh"), x, height - 6);
          }
        }
      }

      Column {
        id: week
        visible: Weather.days.length > 0
        width: parent.width
        spacing: 2
        readonly property int weekLo: Math.min(...Weather.days.map(d => d.min))
        readonly property int weekHi: Math.max(...Weather.days.map(d => d.max))

        Repeater {
          model: Weather.days
          Item {
            id: row
            required property var modelData
            required property int index
            width: parent.width
            height: 30

            Label {
              id: dayName
              anchors.verticalCenter: parent.verticalCenter
              leftPadding: 4
              width: 64
              text: row.index === 0 ? "Today" : Qt.formatDate(row.modelData.date, "ddd")
              font.bold: row.index === 0
            }
            WeatherIcon {
              id: dayIcon
              anchors.left: dayName.right
              anchors.verticalCenter: parent.verticalCenter
              code: row.modelData.code
              day: true
              size: 18
            }
            Caption {
              id: pop
              anchors.left: dayIcon.right
              anchors.leftMargin: 6
              anchors.verticalCenter: parent.verticalCenter
              width: 40
              text: row.modelData.pop >= 20 ? row.modelData.pop + "%" : ""
              color: Theme.info
            }
            Caption {
              id: lo
              anchors.left: pop.right
              anchors.verticalCenter: parent.verticalCenter
              width: 30
              horizontalAlignment: Text.AlignRight
              text: row.modelData.min + "°"
            }
            // this day's range placed on the week's
            Rectangle {
              id: track
              anchors.left: lo.right
              anchors.right: hi.left
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              height: 5
              radius: 2.5
              color: Theme.bg2
              readonly property real range: Math.max(1, week.weekHi - week.weekLo)
              Rectangle {
                x: track.width * (row.modelData.min - week.weekLo) / track.range
                width: Math.max(track.height, track.width * (row.modelData.max - row.modelData.min) / track.range)
                height: track.height
                radius: track.radius
                gradient: Gradient {
                  orientation: Gradient.Horizontal
                  GradientStop {
                    position: 0
                    color: Theme.info
                  }
                  GradientStop {
                    position: 1
                    color: Theme.warning
                  }
                }
              }
            }
            Label {
              id: hi
              anchors.right: parent.right
              anchors.rightMargin: 4
              anchors.verticalCenter: parent.verticalCenter
              width: 30
              horizontalAlignment: Text.AlignRight
              text: row.modelData.max + "°"
            }
          }
        }
      }
    }
  }
}
