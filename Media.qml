pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// the playing mpris player, else the first one
Singleton {
  id: root
  // playerctld mirrors the other players
  readonly property var players: Array.from(Mpris.players.values).filter(p => !(p.dbusName || "").includes("playerctld"))
  readonly property var player: players.find(p => p.isPlaying) || players[0] || null
  readonly property string title: player ? player.trackTitle || player.identity : ""
  readonly property string artist: player ? player.trackArtist : ""

  // mpris doesn't push position updates
  Timer {
    running: root.player !== null && root.player.isPlaying && root.player.positionSupported
    interval: 1000
    repeat: true
    onTriggered: root.player.positionChanged()
  }
}
