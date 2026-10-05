import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: card
  readonly property var player: Media.player

  visible: player !== null
  implicitHeight: col.implicitHeight + 24
  radius: 16
  color: Theme.bg1

  Column {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 12
    spacing: 8

    RowLayout {
      width: parent.width
      spacing: 12

      ClippingRectangle {
        implicitWidth: 52
        implicitHeight: 52
        radius: 10
        color: Theme.bg2
        Icon {
          anchors.centerIn: parent
          visible: art.status !== Image.Ready
          name: "music_note"
          color: Theme.dim
        }
        Image {
          id: art
          anchors.fill: parent
          source: card.player ? card.player.trackArtUrl : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
        }
      }

      Column {
        Layout.fillWidth: true
        Label {
          width: parent.width
          text: Media.title
          font.bold: true
          elide: Text.ElideRight
        }
        Label {
          width: parent.width
          visible: text !== ""
          text: Media.artist
          color: Theme.dim
          font.pixelSize: Theme.fontSizeSmall
          elide: Text.ElideRight
        }
      }

      IconButton {
        icon: "skip_previous"
        visible: !!card.player && card.player.canGoPrevious
        onClicked: card.player.previous()
      }
      IconButton {
        icon: card.player && card.player.isPlaying ? "pause" : "play_arrow"
        tint: Theme.bg2
        onClicked: card.player.togglePlaying()
      }
      IconButton {
        icon: "skip_next"
        visible: !!card.player && card.player.canGoNext
        onClicked: card.player.next()
      }
    }

    Slider {
      visible: !!card.player && card.player.canSeek && card.player.lengthSupported && card.player.length > 0
      width: parent.width
      value: visible ? card.player.position / card.player.length : 0
      onReleased: v => card.player.position = v * card.player.length
    }
  }
}
