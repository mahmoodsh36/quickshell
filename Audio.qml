pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// the tracker binds the sink, otherwise volume/mute go stale
Singleton {
  id: root

  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property bool ok: sink !== null && sink.ready && sink.audio !== null
  readonly property real volume: ok ? sink.audio.volume : 0
  readonly property bool muted: ok && sink.audio.muted

  function setVolume(v) {
    if (ok)
      sink.audio.volume = Math.min(1, Math.max(0, v));
  }
  function step(d) {
    setVolume(volume + d);
  }
  function toggleMute() {
    if (ok)
      sink.audio.muted = !sink.audio.muted;
  }

  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }
}
