pragma Singleton
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects

Singleton {
  id: root
  readonly property bool open: popup.open
  function show() {
    Popups.open("media");
  }
  function hide() {
    Popups.close("media");
  }
  function toggle() {
    if (open)
      hide();
    else
      show();
  }

  Popup {
    id: popup
    name: "media"

    Rectangle {
      id: page
      // the player this page controls, falling back when the chosen one goes away
      property var chosen: null
      readonly property var player: Media.players.indexOf(chosen) >= 0 ? chosen : Media.player
      readonly property bool seekable: !!player && player.canSeek && player.lengthSupported && player.length > 0
      readonly property string title: player ? player.trackTitle || player.identity : ""

      width: parent.width
      implicitHeight: player ? col.implicitHeight + 32 : empty.implicitHeight
      radius: 16
      color: Theme.bg1

      function fmt(s) {
        const t = Math.max(0, Math.floor(s));
        const sec = t % 60;
        return Math.floor(t / 60) + ":" + (sec < 10 ? "0" : "") + sec;
      }

      ClippingRectangle {
        anchors.fill: parent
        visible: !!page.player
        radius: page.radius
        color: "transparent"

        Crossfade {
          id: backdropSrc
          anchors.fill: parent
          visible: false
          source: page.player ? page.player.trackArtUrl : ""
          sourceSize: Qt.size(64, 64)
        }
        MultiEffect {
          anchors.fill: parent
          source: backdropSrc
          autoPaddingEnabled: false
          blurEnabled: true
          blur: 1
          blurMax: 32
          saturation: 0.2
          scale: 1.5
        }
        Rectangle {
          anchors.fill: parent
          color: Theme.bg
          opacity: 0.72
        }
      }

      EmptyState {
        id: empty
        visible: !page.player
        icon: "music_off"
        text: "Nothing playing"
        topPadding: 28
        bottomPadding: 28
      }

      Column {
        id: col
        visible: !!page.player
        x: 16
        y: 16
        width: parent.width - 32
        spacing: 14

        ClippingRectangle {
          width: parent.width
          height: width
          radius: 14
          color: Theme.bg2
          Icon {
            anchors.centerIn: parent
            visible: !page.player || String(page.player.trackArtUrl) === ""
            name: "music_note"
            size: 64
            color: Theme.dim
          }
          Crossfade {
            anchors.fill: parent
            source: page.player ? page.player.trackArtUrl : ""
            sourceSize: Qt.size(width * 2, height * 2)
          }
        }

        Column {
          width: parent.width
          spacing: 2
          Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: page.title
            font.bold: true
            font.pixelSize: Theme.fontSize + 4
            elide: Text.ElideRight
          }
          Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: text !== ""
            text: page.player ? page.player.trackArtist : ""
            elide: Text.ElideRight
          }
          Caption {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: text !== ""
            text: page.player ? page.player.trackAlbum : ""
            elide: Text.ElideRight
          }
        }

        Column {
          width: parent.width
          spacing: 4

          Item {
            id: wave
            readonly property int count: 44
            readonly property real gap: 2
            property real dragFrac: -1
            readonly property real frac: dragFrac >= 0 ? dragFrac : page.seekable ? Math.min(1, page.player.position / page.player.length) : 0
            // stable pseudo random heights, smoothed so it reads as a waveform
            readonly property var heights: {
              let seed = 7;
              const t = page.title;
              for (let i = 0; i < t.length; i++)
                seed = (seed * 31 + t.charCodeAt(i)) % 2147483647;
              const raw = [];
              for (let i = 0; i < count; i++) {
                seed = (seed * 48271) % 2147483647;
                raw.push(seed / 2147483647);
              }
              const out = [];
              for (let i = 0; i < count; i++) {
                const v = (raw[Math.max(0, i - 1)] + raw[i] * 2 + raw[Math.min(count - 1, i + 1)]) / 4;
                out.push(0.2 + 0.8 * v);
              }
              return out;
            }

            width: parent.width
            height: 36

            Repeater {
              model: wave.count
              Rectangle {
                required property int index
                readonly property real center: (index + 0.5) / wave.count
                width: (wave.width - (wave.count - 1) * wave.gap) / wave.count
                height: wave.height * wave.heights[index]
                x: index * (width + wave.gap)
                anchors.verticalCenter: wave.verticalCenter
                radius: width / 2
                color: center <= wave.frac ? Theme.accent : Theme.bg2
                opacity: page.seekable ? 1 : 0.5
              }
            }

            MouseArea {
              anchors.fill: parent
              enabled: page.seekable
              cursorShape: Qt.PointingHandCursor
              function frac(x) {
                return Math.max(0, Math.min(1, x / width));
              }
              onPressed: m => wave.dragFrac = frac(m.x)
              onPositionChanged: m => {
                if (pressed)
                  wave.dragFrac = frac(m.x);
              }
              onReleased: m => {
                page.player.position = frac(m.x) * page.player.length;
                wave.dragFrac = -1;
              }
              onCanceled: wave.dragFrac = -1
            }
          }

          Item {
            width: parent.width
            height: elapsed.implicitHeight
            Caption {
              id: elapsed
              text: page.fmt(wave.dragFrac >= 0 ? wave.dragFrac * page.player.length : page.player && page.player.positionSupported ? page.player.position : 0)
            }
            Caption {
              anchors.right: parent.right
              visible: !!page.player && page.player.lengthSupported && page.player.length > 0
              text: page.player ? page.fmt(page.player.length) : ""
            }
          }
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 10
          height: 56

          IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!page.player && page.player.shuffleSupported
            icon: "shuffle"
            iconColor: page.player && page.player.shuffle ? Theme.accent : Theme.dim
            onClicked: page.player.shuffle = !page.player.shuffle
          }
          IconButton {
            anchors.verticalCenter: parent.verticalCenter
            size: 40
            icon: "skip_previous"
            iconColor: page.player && page.player.canGoPrevious ? Theme.fg : Theme.dim
            interactive: !!page.player && page.player.canGoPrevious
            onClicked: page.player.previous()
          }
          IconButton {
            anchors.verticalCenter: parent.verticalCenter
            size: 56
            icon: page.player && page.player.isPlaying ? "pause" : "play_arrow"
            iconColor: Theme.accentFg
            tint: Theme.accent
            interactive: !!page.player && page.player.canTogglePlaying
            onClicked: page.player.togglePlaying()
          }
          IconButton {
            anchors.verticalCenter: parent.verticalCenter
            size: 40
            icon: "skip_next"
            iconColor: page.player && page.player.canGoNext ? Theme.fg : Theme.dim
            interactive: !!page.player && page.player.canGoNext
            onClicked: page.player.next()
          }
          IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!page.player && page.player.loopSupported
            icon: page.player && page.player.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
            iconColor: page.player && page.player.loopState !== MprisLoopState.None ? Theme.accent : Theme.dim
            onClicked: {
              const s = page.player.loopState;
              page.player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist : s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
            }
          }
        }

        Flow {
          width: parent.width
          visible: Media.players.length > 1
          spacing: 6
          Repeater {
            model: Media.players
            Rectangle {
              id: chip
              required property var modelData
              readonly property bool picked: modelData === page.player
              readonly property var entry: modelData.desktopEntry ? DesktopEntries.heuristicLookup(modelData.desktopEntry) : null
              height: 28
              width: chipRow.implicitWidth + 20
              radius: height / 2
              color: picked ? Theme.accent : chipMouse.containsMouse ? Theme.hover(Theme.bg2) : Theme.bg2
              Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 6
                Image {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: !!chip.entry && chip.entry.icon !== ""
                  width: 16
                  height: 16
                  sourceSize: Qt.size(32, 32)
                  source: chip.entry ? Quickshell.iconPath(chip.entry.icon, true) : ""
                }
                Caption {
                  anchors.verticalCenter: parent.verticalCenter
                  text: chip.modelData.identity
                  color: chip.picked ? Theme.accentFg : Theme.fg
                }
              }
              MouseArea {
                id: chipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: page.chosen = chip.modelData
              }
            }
          }
        }
      }
    }
  }
}
