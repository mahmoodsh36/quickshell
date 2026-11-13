pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects

// workspace grid with live window thumbnails. qs ipc call overview toggle
Singleton {
  id: root
  property bool open: false
  property string query: ""
  // card index under the keyboard selection
  property int selected: 0
  // workspace whose card morphs to and from the full screen
  property int hero: 1
  // 0 closed, 1 open; each card eases its own staggered slice of it
  property real progress: 0
  property int dropIndex: -1

  readonly property real screenW: window.screen ? window.screen.width : 1600
  readonly property real screenH: window.screen ? window.screen.height : 900
  readonly property real aspect: screenW / Math.max(1, screenH)

  readonly property int highestUsed: Math.max(0, ...Array.from(Hyprland.toplevels.values).map(t => t.workspace ? t.workspace.id : 0))
  // every workspace up to the highest in use, plus one empty slot to start a new one
  readonly property int slots: Math.max(BarState.wsCount, highestUsed) + 1

  readonly property int gap: 24
  // picks the column count that gives the largest cards
  readonly property var grid: {
    const n = slots, availW = screenW - 120, availH = screenH - 180;
    let best = { cols: 1, rows: n, w: 0 };
    for (let c = 1; c <= n; c++) {
      const r = Math.ceil(n / c);
      const w = Math.min((availW - (c - 1) * gap) / c, (availH - (r - 1) * gap) / r * aspect);
      if (w > best.w)
        best = { cols: c, rows: r, w: w };
    }
    best.h = best.w / aspect;
    best.x0 = (screenW - (best.cols * best.w + (best.cols - 1) * gap)) / 2;
    best.y0 = 96 + (availH - (best.rows * best.h + (best.rows - 1) * gap)) / 2;
    return best;
  }
  readonly property int heroIndex: Math.max(0, Math.min(hero - 1, slots - 1))
  readonly property real maxDelay: 0.3

  function show() {
    window.screen = Focus.screen;
    Hyprland.refreshToplevels();
    input.text = "";
    hero = Math.max(1, BarState.focusedWs);
    selected = Math.min(hero, slots) - 1;
    open = true;
    animate(1, 420);
    input.forceActiveFocus();
  }
  function hide(ws) {
    if (!open)
      return;
    hero = ws >= 1 ? ws : Math.max(1, BarState.focusedWs);
    open = false;
    dropIndex = -1;
    animate(0, 320);
  }
  // niri has its own overview, which knows its scrolling layout
  function toggle() {
    if (Niri.active)
      Niri.action(["toggle-overview"]);
    else if (open)
      hide();
    else
      show();
  }

  function animate(to, ms) {
    anim.stop();
    anim.to = to;
    anim.duration = ms * Math.abs(to - progress);
    anim.start();
  }

  function goTo(ws) {
    BarState.focusWs(ws);
    hide(ws);
  }
  function focusWin(w) {
    BarState.focusWindow(w.address);
    hide(w.wsId);
  }

  function cardT(index) {
    const ci = index % grid.cols, ri = Math.floor(index / grid.cols);
    const hc = heroIndex % grid.cols, hr = Math.floor(heroIndex / grid.cols);
    const delay = Math.min((Math.abs(ci - hc) + Math.abs(ri - hr)) * 0.06, maxDelay);
    const t = Math.max(0, Math.min(1, (progress - delay) / (1 - maxDelay)));
    return 1 - Math.pow(1 - t, 3);
  }

  function matches(title, appId) {
    const q = query.trim().toLowerCase();
    return q === "" || title.toLowerCase().includes(q) || appId.toLowerCase().includes(q);
  }

  function shownWins() {
    const out = [];
    for (let i = 0; i < winRep.count; i++) {
      const w = winRep.itemAt(i);
      if (w && w.visible)
        out.push(w);
    }
    return out.sort((a, b) => a.wsId - b.wsId || a.ry - b.ry || a.rx - b.rx);
  }

  function move(d) {
    selected = Math.max(0, Math.min(selected + d, slots - 1));
  }

  function key(event) {
    const k = event.key;
    const typing = query !== "";
    if (k === Qt.Key_Escape) {
      if (typing)
        input.text = "";
      else
        hide();
    } else if (k === Qt.Key_Left || (!typing && k === Qt.Key_H))
      move(-1);
    else if (k === Qt.Key_Right || (!typing && k === Qt.Key_L))
      move(1);
    else if (k === Qt.Key_Up || (!typing && k === Qt.Key_K))
      move(-grid.cols);
    else if (k === Qt.Key_Down || (!typing && k === Qt.Key_J))
      move(grid.cols);
    else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
      const first = typing ? shownWins().find(w => w.hit) : null;
      if (first)
        focusWin(first);
      else
        goTo(selected + 1);
    } else
      return;
    event.accepted = true;
  }

  NumberAnimation {
    id: anim
    target: root
    property: "progress"
  }

  // ipc geometry is a snapshot, so refetch whenever hyprland reports a change while open
  Connections {
    target: Hyprland
    enabled: root.open
    function onRawEvent(event) {
      refresh.restart();
    }
  }
  Timer {
    id: refresh
    interval: 60
    onTriggered: Hyprland.refreshToplevels()
  }

  PanelWindow {
    id: window
    visible: root.open || root.progress > 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-overview"
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
      readonly property url wallpaper: window.visible ? Wallpapers.url(Persist.wallpaper) : ""

      // blurred at quarter resolution and scaled up, as in WallpaperPicker
      Item {
        x: -32
        y: -32
        width: (parent.width + 64) / 4
        height: (parent.height + 64) / 4
        scale: 4
        transformOrigin: Item.TopLeft
        opacity: root.progress

        Image {
          id: backdrop
          anchors.fill: parent
          visible: false
          asynchronous: true
          fillMode: Image.PreserveAspectCrop
          source: stage.wallpaper
          sourceSize: Qt.size(width, height)
        }
        MultiEffect {
          anchors.fill: parent
          source: backdrop
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
        opacity: 0.55 * root.progress
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 36 - 16 * (1 - root.progress)
        width: 340
        height: 34
        radius: height / 2
        color: Theme.bg1
        border.width: 1
        border.color: root.query !== "" ? Theme.accent : Theme.bg2
        opacity: root.progress

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
          anchors.right: parent.right
          anchors.rightMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          focus: true
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
          text: "type to filter windows"
          color: Theme.dim
        }
      }

      Caption {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        opacity: root.progress
        text: "arrows or hjkl select   enter go   drag a window to move it   esc close"
      }

      Repeater {
        id: cardRep
        model: root.slots

        Item {
          id: card
          required property int index
          readonly property int wsId: index + 1
          readonly property bool isNew: index === root.slots - 1
          readonly property bool isHero: index === root.heroIndex
          readonly property bool isFocused: wsId === BarState.focusedWs
          readonly property int col: index % root.grid.cols
          readonly property int row: Math.floor(index / root.grid.cols)
          readonly property int inRow: row === root.grid.rows - 1 ? root.slots - row * root.grid.cols : root.grid.cols
          readonly property real gx: root.grid.x0 + (root.grid.cols - inRow) * (root.grid.w + root.gap) / 2 + col * (root.grid.w + root.gap)
          readonly property real gy: root.grid.y0 + row * (root.grid.h + root.gap)
          readonly property real t: root.cardT(index)
          // the others zoom down from a larger scale into their slot
          readonly property real zoom: 1.25 - 0.25 * t

          x: isHero ? gx * t : gx - root.grid.w * (zoom - 1) / 2
          y: isHero ? gy * t : gy - root.grid.h * (zoom - 1) / 2
          width: isHero ? root.screenW + (root.grid.w - root.screenW) * t : root.grid.w * zoom
          height: isHero ? root.screenH + (root.grid.h - root.screenH) * t : root.grid.h * zoom
          opacity: isHero ? 1 : t
          z: isHero ? 1 : 0

          Rectangle {
            anchors.fill: frame
            anchors.margins: -5
            radius: frame.radius + 5
            color: "transparent"
            border.width: 2
            border.color: Theme.fg
            opacity: (index === root.selected ? 0.7 : 0) * card.t
            Behavior on opacity {
              NumberAnimation {
                duration: 120
              }
            }
          }

          // plain backing so the card reads even before the clipped wallpaper decodes
          Rectangle {
            anchors.fill: parent
            radius: frame.radius
            color: Theme.bg1
          }

          ClippingRectangle {
            id: frame
            anchors.fill: parent
            radius: 12 * card.t
            color: "transparent"

            Image {
              anchors.fill: parent
              asynchronous: true
              fillMode: Image.PreserveAspectCrop
              source: stage.wallpaper
              sourceSize: Qt.size(root.screenW / 2, root.screenH / 2)
              opacity: card.isNew ? 0.35 : 1
            }

            Icon {
              visible: card.isNew
              anchors.centerIn: parent
              name: "add"
              size: 36
              color: Theme.fg
            }
          }

          Rectangle {
            anchors.fill: parent
            radius: frame.radius
            color: "transparent"
            border.width: card.isFocused || root.dropIndex === card.index ? 2 : 1
            border.color: root.dropIndex === card.index ? Theme.secondary : card.isFocused ? Theme.accent : Qt.rgba(1, 1, 1, 0.08)
            opacity: card.t
          }

          Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 8
            width: wsLabel.implicitWidth + 14
            height: 20
            radius: 10
            color: card.isFocused ? Theme.accent : Theme.bg
            opacity: 0.9 * card.t
            Label {
              id: wsLabel
              anchors.centerIn: parent
              text: card.isNew ? "new" : card.wsId
              color: card.isFocused ? Theme.accentFg : Theme.fg
              font.pixelSize: Theme.fontSizeSmall
            }
          }

          MouseArea {
            anchors.fill: parent
            enabled: root.open
            cursorShape: Qt.PointingHandCursor
            onClicked: root.goTo(card.wsId)
          }
        }
      }

      // one layer above every card so a thumbnail can be dragged across cards
      Item {
        anchors.fill: parent
        z: 2

        Repeater {
          id: winRep
          model: Hyprland.toplevels

          Item {
            id: win
            required property var modelData
            readonly property var ipc: modelData.lastIpcObject || ({})
            readonly property string address: modelData.address
            readonly property string title: modelData.title || ""
            readonly property string appId: modelData.wayland ? modelData.wayland.appId : ipc["class"] || ""
            readonly property int wsId: modelData.workspace ? modelData.workspace.id : -1
            readonly property Item card: cardRep.count === root.slots && wsId >= 1 && wsId <= root.slots ? cardRep.itemAt(wsId - 1) : null
            // ipc geometry is in global logical coords; monitor width/height are physical
            readonly property var mon: (modelData.workspace && modelData.workspace.monitor) || modelData.monitor
            readonly property real monX: mon ? mon.x : 0
            readonly property real monY: mon ? mon.y : 0
            readonly property real monW: mon ? mon.width / mon.scale : root.screenW
            readonly property real monH: mon ? mon.height / mon.scale : root.screenH
            readonly property var at: ipc.at || [0, 0]
            readonly property var size: ipc.size || [0, 0]
            readonly property real rx: (at[0] - monX) / monW
            readonly property real ry: (at[1] - monY) / monH
            readonly property bool hit: root.matches(title, appId)
            readonly property var entry: appId !== "" ? DesktopEntries.heuristicLookup(appId) : null
            property bool dragging: false
            property real dragX
            property real dragY

            visible: card !== null && size[0] > 0 && !ipc.hidden
            x: dragging ? dragX : card ? card.x + rx * card.width : 0
            y: dragging ? dragY : card ? card.y + ry * card.height : 0
            width: card ? size[0] / monW * card.width : 0
            height: card ? size[1] / monH * card.height : 0
            // floating above tiled, then most recently focused on top
            z: dragging ? 10000 : (ipc.floating ? 1000 : 0) - (ipc.focusHistoryID || 0) + (card && card.isHero ? 2000 : 0)
            opacity: (card ? card.opacity : 0) * (hit ? 1 : 0.25)
            scale: dragging ? 1.04 : 1

            Rectangle {
              anchors.fill: parent
              radius: card ? 6 * card.t : 0
              color: Theme.bg2
              visible: !shot.hasContent

              Icon {
                anchors.centerIn: parent
                name: "web_asset"
                size: Math.min(parent.width, parent.height) * 0.4
                color: Theme.dim
              }
            }
            ClippingRectangle {
              anchors.fill: parent
              radius: card ? 6 * card.t : 0
              color: "transparent"

              ScreencopyView {
                id: shot
                anchors.fill: parent
                captureSource: window.visible ? win.modelData.wayland : null
                live: root.open
              }
            }

            Rectangle {
              anchors.fill: parent
              radius: card ? 6 * card.t : 0
              color: "transparent"
              border.width: area.containsMouse ? 2 : 1
              border.color: area.containsMouse ? Theme.accent : Qt.rgba(0, 0, 0, 0.3)
              opacity: win.card ? win.card.t : 0
            }

            IconImage {
              visible: win.entry !== null && win.width > 40
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              anchors.bottomMargin: -implicitSize / 3
              implicitSize: Math.max(16, Math.min(36, win.width * 0.22))
              source: win.entry ? Quickshell.iconPath(win.entry.icon, true) : ""
              opacity: win.card ? win.card.t : 0
            }

            MouseArea {
              id: area
              anchors.fill: parent
              enabled: root.open
              hoverEnabled: true
              cursorShape: win.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
              property point grab
              property point start
              property bool dragged: false

              function cardAt(p) {
                for (let i = 0; i < cardRep.count; i++) {
                  const c = cardRep.itemAt(i);
                  if (p.x >= c.x && p.x < c.x + c.width && p.y >= c.y && p.y < c.y + c.height)
                    return i;
                }
                return -1;
              }

              onPressed: mouse => {
                grab = Qt.point(mouse.x, mouse.y);
                start = mapToItem(stage, mouse.x, mouse.y);
                dragged = false;
              }
              onPositionChanged: mouse => {
                if (!pressed)
                  return;
                const p = mapToItem(stage, mouse.x, mouse.y);
                if (!win.dragging && Math.hypot(p.x - start.x, p.y - start.y) < 8)
                  return;
                if (!win.dragging) {
                  win.dragX = win.x;
                  win.dragY = win.y;
                  win.dragging = true;
                  dragged = true;
                }
                win.dragX = p.x - grab.x;
                win.dragY = p.y - grab.y;
                root.dropIndex = cardAt(p);
              }
              onReleased: mouse => {
                if (!win.dragging)
                  return;
                const target = cardAt(mapToItem(stage, mouse.x, mouse.y));
                win.dragging = false;
                root.dropIndex = -1;
                if (target >= 0 && target + 1 !== win.wsId)
                  BarState.moveWindow(win.address, target + 1);
              }
              onClicked: {
                if (!dragged)
                  root.focusWin(win);
              }
            }
          }
        }
      }
    }
  }
}
