pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects

// wallpaper carousel with a live palette preview. qs ipc call wallpaper toggle
Singleton {
  id: root
  property bool open: false
  property string query: ""
  // once typing starts, letters go to the filter instead of h l m
  property bool searching: false
  // previewed mode and scheme, seeded from Persist on open and committed on apply
  property string mode: "dark"
  property string scheme: "scheme-tonal-spot"
  property bool applying: false
  property string error: ""
  property string ambient: ""
  // last palette that arrived, kept while the next one loads so the strip never blanks
  property var shownPalette: null

  readonly property var swatchRoles: ["bg", "bg1", "bg2", "fg", "accent", "secondary", "tertiary", "error"]
  readonly property int screenW: window.screen ? window.screen.width : 1280
  readonly property int cardW: Math.round(Math.min(440, Math.max(260, screenW * 0.24)))
  readonly property int cardH: Math.round(cardW * 0.625)

  readonly property var matches: {
    const terms = query.toLowerCase().split(" ").filter(t => t !== "");
    const all = Wallpapers.entries;
    return terms.length === 0 ? all : all.filter(e => terms.every(t => e.lower.includes(t)));
  }

  readonly property var current: {
    const m = view.model;
    return m && view.currentIndex >= 0 && view.currentIndex < m.length ? m[view.currentIndex] : null;
  }

  readonly property var preview: Wallpapers.previewRev >= 0 && current ? Wallpapers.previews[Wallpapers.previewKey(current.path, mode, scheme)] || null : null

  onPreviewChanged: {
    if (preview)
      shownPalette = preview;
  }
  onCurrentChanged: resettle()
  onModeChanged: resettle()
  onSchemeChanged: resettle()

  // the view's model is swapped by hand so the centered wallpaper survives filtering and rescans
  onMatchesChanged: {
    const keep = current ? current.path : Persist.wallpaper;
    view.model = matches;
    centerOn(keep);
  }

  function show() {
    window.screen = Focus.screen;
    mode = Persist.colorMode;
    scheme = Persist.scheme;
    error = "";
    applying = false;
    endSearch();
    open = true;
    centerOn(Persist.wallpaper);
    settle();
    keys.forceActiveFocus();
    Wallpapers.scan();
  }
  function hide() {
    open = false;
    endSearch();
  }
  function toggle() {
    if (open)
      hide();
    else
      show();
  }

  function centerOn(path) {
    const m = view.model || [];
    const i = Math.max(0, m.findIndex(e => e.path === path));
    view.instant = true;
    instantOff.restart();
    view.currentIndex = m.length > 0 ? i : -1;
    if (m.length > 0)
      view.positionViewAtIndex(i, ListView.Center);
  }

  function move(d) {
    if (view.count > 0)
      view.currentIndex = Math.max(0, Math.min(view.currentIndex + d, view.count - 1));
  }

  function cycleScheme(d) {
    const s = Wallpapers.schemes;
    scheme = s[(s.indexOf(scheme) + d + s.length) % s.length];
  }

  function toggleMode() {
    mode = mode === "dark" ? "light" : "dark";
  }

  function beginSearch(text) {
    searching = true;
    input.text = text;
    input.cursorPosition = input.text.length;
    input.forceActiveFocus();
  }
  function endSearch() {
    searching = false;
    input.text = "";
    keys.forceActiveFocus();
  }

  function apply(entry) {
    if (!entry || Wallpapers.busy)
      return;
    error = "";
    applying = true;
    Wallpapers.set(entry.path, mode, scheme);
  }

  function resettle() {
    if (open)
      settleTimer.restart();
  }
  function settle() {
    const c = current;
    if (!c)
      return;
    if (Wallpapers.ready[c.key])
      ambient = c.thumb;
    Wallpapers.requestPreview(c.path, mode, scheme);
  }

  function key(event) {
    const k = event.key;
    const plain = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier));
    const ctrl = event.modifiers & Qt.ControlModifier;
    if (k === Qt.Key_Escape) {
      if (searching)
        endSearch();
      else
        hide();
    } else if (k === Qt.Key_Left || (ctrl && k === Qt.Key_P) || (!searching && k === Qt.Key_H))
      move(-1);
    else if (k === Qt.Key_Right || (ctrl && k === Qt.Key_N) || (!searching && k === Qt.Key_L))
      move(1);
    else if (k === Qt.Key_Return || k === Qt.Key_Enter)
      apply(current);
    else if (k === Qt.Key_Tab)
      cycleScheme(1);
    else if (k === Qt.Key_Backtab)
      cycleScheme(-1);
    else if (!searching && k === Qt.Key_M)
      toggleMode();
    else if (!searching && k === Qt.Key_Home)
      move(-view.count);
    else if (!searching && k === Qt.Key_End)
      move(view.count);
    else if (searching && k === Qt.Key_Backspace && input.text === "")
      endSearch();
    else if (!searching && k === Qt.Key_Slash)
      beginSearch("");
    else if (!searching && plain && event.text.trim() !== "")
      beginSearch(event.text);
    else
      return;
    event.accepted = true;
  }

  Connections {
    target: Wallpapers
    function onApplied(ok, err) {
      if (!root.applying)
        return;
      root.applying = false;
      if (ok)
        root.hide();
      else
        root.error = err;
    }
    // a thumbnail that finishes while it is centered still reaches the backdrop
    function onReadyRevChanged() {
      if (root.open)
        root.settle();
    }
  }

  // previews and the backdrop wait for the selection to rest, so holding a key stays cheap
  Timer {
    id: settleTimer
    interval: 200
    onTriggered: root.settle()
  }

  // jumps on open and filter skip the highlight animation; the reset waits for the view's layout
  Timer {
    id: instantOff
    interval: 120
    onTriggered: view.instant = false
  }

  component Pill: Rectangle {
    id: pill
    property string icon
    property string label
    property bool spinning: false
    property color tint: Theme.fg
    signal clicked

    implicitWidth: pillRow.implicitWidth + 22
    implicitHeight: 26
    radius: height / 2
    color: pillArea.containsMouse ? Theme.hover(Theme.bg1) : Theme.bg1

    Row {
      id: pillRow
      anchors.centerIn: parent
      spacing: 6
      Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: pill.icon
        size: 15
        color: pill.tint
        spinning: pill.spinning
      }
      Label {
        anchors.verticalCenter: parent.verticalCenter
        text: pill.label
        color: pill.tint
        font.pixelSize: Theme.fontSizeSmall
      }
    }
    MouseArea {
      id: pillArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: pill.clicked()
    }
  }

  PanelWindow {
    id: window
    visible: root.open || stage.shown > 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-wallpaper-picker"
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    color: "transparent"

    HyprlandFocusGrab {
      active: window.visible && root.open
      windows: [window]
      onCleared: root.hide()
    }

    Item {
      id: stage
      anchors.fill: parent
      property real shown: root.open ? 1 : 0
      Behavior on shown {
        NumberAnimation {
          duration: 240
          easing.type: Easing.OutCubic
        }
      }

      // blurred at quarter resolution and scaled up, which is both cheaper and softer
      Item {
        x: -32
        y: -32
        width: (parent.width + 64) / 4
        height: (parent.height + 64) / 4
        scale: 4
        transformOrigin: Item.TopLeft
        opacity: stage.shown

        Crossfade {
          id: ambientImage
          anchors.fill: parent
          visible: false
          source: root.ambient
          sourceSize: Qt.size(width, height)
          duration: 450
          fromScale: 1.06
        }
        MultiEffect {
          anchors.fill: parent
          source: ambientImage
          autoPaddingEnabled: false
          blurEnabled: true
          blur: 1
          blurMax: 24
          saturation: 0.1
        }
      }

      Rectangle {
        anchors.fill: parent
        color: Theme.bg
        opacity: 0.6 * stage.shown
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
      }

      WheelSteps {
        anyAxis: true
        onStepped: steps => root.move(-steps)
      }

      Item {
        id: keys
        focus: true
        Keys.onPressed: event => root.key(event)
      }

      // swallows clicks between the controls so only the bare backdrop closes
      MouseArea {
        anchors.fill: content
      }

      Column {
        id: content
        anchors.centerIn: parent
        width: parent.width
        spacing: 18
        opacity: stage.shown
        scale: 0.97 + 0.03 * stage.shown
        transform: Translate {
          y: (1 - stage.shown) * 28
        }

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 340
          height: 34
          radius: height / 2
          color: Theme.bg1
          border.width: 1
          border.color: root.searching ? Theme.accent : Theme.bg2
          Behavior on border.color {
            ColorAnimation {
              duration: 150
            }
          }

          Icon {
            id: searchIcon
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 16
            color: Theme.dim
          }
          TextInput {
            id: input
            anchors.left: searchIcon.right
            anchors.leftMargin: 8
            anchors.right: countLabel.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            activeFocusOnPress: false
            clip: true
            color: Theme.fg
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentFg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            onTextChanged: root.query = text
            Keys.onPressed: event => root.key(event)
          }
          Label {
            anchors.fill: input
            verticalAlignment: Text.AlignVCenter
            visible: input.text === ""
            text: root.searching ? "" : "type to filter"
            color: Theme.dim
          }
          Caption {
            id: countLabel
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: view.count > 0 ? (view.currentIndex + 1) + " / " + view.count : "0"
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: {
              if (!root.searching)
                root.beginSearch("");
            }
          }
        }

        ListView {
          id: view
          property bool instant: false
          // the screen's width is known before the window is configured, so the first open is centered
          anchors.horizontalCenter: parent.horizontalCenter
          width: root.screenW
          height: root.cardH + 48
          orientation: ListView.Horizontal
          spacing: 18
          // the wheel and keys drive it; a flick would fight the snapping
          interactive: false
          reuseItems: true
          cacheBuffer: root.cardW * 2
          highlightRangeMode: ListView.StrictlyEnforceRange
          preferredHighlightBegin: (width - root.cardW) / 2
          preferredHighlightEnd: (width + root.cardW) / 2
          highlightMoveDuration: instant ? 0 : 360
          highlightMoveVelocity: -1
          Component.onCompleted: model = root.matches

          delegate: Item {
            id: card
            required property var modelData
            required property int index
            readonly property real dist: Math.min(Math.abs(x + width / 2 - view.contentX - view.width / 2) / (width + view.spacing), 2.5)
            readonly property real near: Math.min(dist, 1)
            readonly property real far: Math.max(0, Math.min(dist - 1, 1))
            readonly property bool hasThumb: Wallpapers.readyRev >= 0 && Wallpapers.ready[modelData.key] === true

            width: root.cardW
            height: root.cardH
            y: (view.height - height) / 2
            scale: 1 - 0.18 * near - 0.08 * far
            opacity: 1 - 0.45 * near - 0.35 * far

            Rectangle {
              anchors.fill: frame
              anchors.margins: -5
              radius: frame.radius + 5
              color: "transparent"
              border.width: 2
              border.color: Theme.accent
              opacity: Math.max(0, 1 - card.dist * 2.5)
            }

            ClippingRectangle {
              id: frame
              anchors.fill: parent
              radius: 14
              color: Theme.bg1

              Icon {
                anchors.centerIn: parent
                name: "image"
                size: 32
                color: Theme.dim
                opacity: thumb.status === Image.Ready ? 0 : 0.5
              }
              Image {
                id: thumb
                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                source: card.hasThumb ? card.modelData.thumb : ""
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity {
                  NumberAnimation {
                    duration: 220
                  }
                }
              }
            }

            Rectangle {
              visible: card.modelData.path === Persist.wallpaper
              anchors.top: parent.top
              anchors.right: parent.right
              anchors.margins: 10
              width: 24
              height: 24
              radius: 12
              color: Theme.accent
              Icon {
                anchors.centerIn: parent
                name: "check"
                size: 16
                color: Theme.accentFg
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: view.currentIndex = card.index
              onDoubleClicked: root.apply(card.modelData)
            }
          }

          Label {
            anchors.centerIn: parent
            visible: view.count === 0
            text: !Wallpapers.scanned ? "loading" : Wallpapers.entries.length === 0 ? "no images in " + Config.wallpaperDir : "no match"
            color: Theme.dim
          }
        }

        Label {
          anchors.horizontalCenter: parent.horizontalCenter
          width: Math.min(implicitWidth, root.cardW * 1.6)
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideMiddle
          text: root.current ? root.current.name : " "
          font.pixelSize: Theme.fontSize + 1
        }

        ClippingRectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 304
          height: 14
          radius: height / 2
          color: Theme.bg1
          opacity: root.preview ? 1 : 0.55
          Behavior on opacity {
            NumberAnimation {
              duration: 200
            }
          }

          Row {
            anchors.fill: parent
            Repeater {
              model: root.swatchRoles
              Rectangle {
                required property string modelData
                width: parent.width / root.swatchRoles.length
                height: parent.height
                color: root.shownPalette && root.shownPalette[modelData] ? root.shownPalette[modelData] : Theme[modelData]
                Behavior on color {
                  ColorAnimation {
                    duration: 260
                    easing.type: Easing.InOutQuad
                  }
                }
              }
            }
          }
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 8
          Pill {
            icon: "palette"
            label: root.scheme.replace(/^scheme-/, "").replace(/-/g, " ")
            onClicked: root.cycleScheme(1)
          }
          Pill {
            icon: root.mode === "dark" ? "dark_mode" : "light_mode"
            label: root.mode
            onClicked: root.toggleMode()
          }
          Pill {
            visible: Wallpapers.busy
            icon: "progress_activity"
            label: "applying"
            spinning: Wallpapers.busy
            tint: Theme.accent
          }
        }

        Label {
          anchors.horizontalCenter: parent.horizontalCenter
          visible: root.error !== ""
          width: 640
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          maximumLineCount: 3
          elide: Text.ElideRight
          text: root.error
          color: Theme.error
          font.pixelSize: Theme.fontSizeSmall
        }

        Caption {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.searching ? "arrows move   enter apply   tab scheme   esc clear" : "h l move   enter apply   tab scheme   m mode   / search   esc close"
        }
      }
    }
  }
}
