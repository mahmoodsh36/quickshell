import QtQuick

// two image slots: a new source decodes hidden, then fades in over the old one with a slight
// scale settle, and the old slot is cleared so only one decoded image stays alive
Item {
  id: root
  property url source
  property size sourceSize
  property bool cache: true
  property int duration: 800
  property real fromScale: 1.04

  property Image shown: null
  property Image incoming: null

  onSourceChanged: swap()
  Component.onCompleted: swap()

  function swap() {
    if (fade.running) {
      fade.stop();
      settle();
    }
    const src = String(source);
    const slot = shown === a ? b : a;
    if (src === "" || (shown && String(shown.source) === src)) {
      incoming = null;
      slot.source = "";
      if (src === "" && shown) {
        shown.source = "";
        shown = null;
      }
      return;
    }
    slot.opacity = 0;
    slot.scale = fromScale;
    slot.z = 1;
    if (shown)
      shown.z = 0;
    incoming = slot;
    slot.source = src;
    loaded(slot);
  }

  function loaded(slot) {
    if (slot !== incoming)
      return;
    if (slot.status === Image.Ready && !fade.running)
      fade.start();
    else if (slot.status === Image.Error) {
      incoming = null;
      slot.source = "";
    }
  }

  function settle() {
    if (!incoming)
      return;
    incoming.opacity = 1;
    incoming.scale = 1;
    if (shown) {
      shown.source = "";
      shown.opacity = 0;
    }
    shown = incoming;
    incoming = null;
  }

  ParallelAnimation {
    id: fade
    NumberAnimation {
      target: root.incoming
      property: "opacity"
      from: 0
      to: 1
      duration: root.duration
      easing.type: Easing.InOutQuad
    }
    NumberAnimation {
      target: root.incoming
      property: "scale"
      from: root.fromScale
      to: 1
      duration: root.duration * 1.2
      easing.type: Easing.OutQuart
    }
    onFinished: root.settle()
  }

  component Slot: Image {
    id: slot
    anchors.fill: parent
    asynchronous: true
    cache: root.cache
    fillMode: Image.PreserveAspectCrop
    sourceSize: root.sourceSize
    opacity: 0
    onStatusChanged: root.loaded(slot)
  }

  Slot {
    id: a
  }
  Slot {
    id: b
  }
}
