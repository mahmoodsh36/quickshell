pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// lists Config.wallpaperDir, caches thumbnails and runs the theming scripts
Singleton {
  id: root

  property var entries: []
  property bool scanned: false
  // thumbnail keys known to exist; mutated in place, readyRev tells bindings to look again
  property var ready: ({})
  property int readyRev: 0
  readonly property string thumbDir: Quickshell.cachePath("thumbs")

  readonly property bool busy: applyProc.running
  signal applied(bool ok, string message)

  property var previews: ({})
  property int previewRev: 0

  readonly property var schemes: ["scheme-tonal-spot", "scheme-vibrant", "scheme-expressive", "scheme-fidelity", "scheme-content", "scheme-monochrome", "scheme-neutral", "scheme-rainbow", "scheme-fruit-salad"]

  property bool randomPending: false
  property bool thumbsAgain: false
  property var applyQueued: null
  property var previewQueued: null

  // percent-encode each segment so names with # or ? survive as a url
  function url(path) {
    return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "";
  }

  function scan() {
    if (!lister.running)
      lister.running = true;
  }

  function resolve(path) {
    path = String(path || "").replace(/^~(?=\/|$)/, Config.home);
    return path.startsWith("/") ? path : Config.wallpaperDir + "/" + path;
  }

  function set(path, mode, scheme) {
    if (!path)
      return;
    if (mode)
      Persist.colorMode = mode === "light" ? "light" : "dark";
    if (scheme && schemes.indexOf(scheme) >= 0)
      Persist.scheme = scheme;
    Persist.wallpaper = resolve(path);
    apply();
  }

  function random() {
    if (!scanned) {
      randomPending = true;
      scan();
      return;
    }
    const pool = entries.filter(e => e.path !== Persist.wallpaper);
    if (pool.length > 0)
      set(pool[Math.floor(Math.random() * pool.length)].path);
  }

  function setMode(m) {
    if (m === "toggle")
      m = Persist.colorMode === "dark" ? "light" : "dark";
    if (m !== "dark" && m !== "light") {
      console.warn("unknown color mode: " + m + " (want dark light toggle)");
      return;
    }
    Persist.colorMode = m;
    apply();
  }

  function setScheme(s) {
    s = String(s).startsWith("scheme-") ? String(s) : "scheme-" + s;
    if (schemes.indexOf(s) < 0) {
      console.warn("unknown scheme: " + s + " (want " + schemes.join(" ") + ")");
      return;
    }
    Persist.scheme = s;
    apply();
  }

  function apply() {
    if (!Persist.wallpaper)
      return;
    const cmd = ["sh", Quickshell.shellPath("theming/apply.sh"), Persist.wallpaper, Persist.colorMode, Persist.scheme];
    if (applyProc.running) {
      applyQueued = cmd;
      return;
    }
    applyProc.command = cmd;
    applyProc.running = true;
  }

  function previewKey(path, mode, scheme) {
    return path + "\n" + mode + "\n" + scheme;
  }

  function requestPreview(path, mode, scheme) {
    const key = previewKey(path, mode, scheme);
    if (!path || previews[key] !== undefined || (previewProc.running && previewProc.key === key))
      return;
    const req = {
      key: key,
      cmd: ["sh", Quickshell.shellPath("theming/preview.sh"), path, mode, scheme]
    };
    // only the newest request matters while one is in flight
    if (previewProc.running)
      previewQueued = req;
    else
      runPreview(req);
  }

  function runPreview(req) {
    previewProc.key = req.key;
    previewProc.command = req.cmd;
    previewProc.running = true;
  }

  function startThumbs() {
    if (thumbProc.running) {
      thumbsAgain = true;
      return;
    }
    const args = [];
    for (const e of entries) {
      if (!ready[e.key])
        args.push(e.path, e.key);
    }
    if (args.length === 0)
      return;
    thumbProc.command = ["nice", "-n", "10", "sh", "-c", thumbScript, "sh", thumbDir].concat(args);
    thumbProc.running = true;
  }

  // "mtime size path" per image, so a changed file gets a new thumbnail key
  readonly property string listScript: `
dir=$1; shift
for f in "$dir"/*; do
  case $f in
    *.[jJ][pP][gG] | *.[jJ][pP][eE][gG] | *.[pP][nN][gG] | *.[wW][eE][bB][pP]) [ -f "$f" ] && set -- "$@" "$f" ;;
  esac
done
[ $# -eq 0 ] || exec stat -L -c "%Y %s %n" -- "$@"
`

  // args: out dir, then src key pairs. existing thumbs are reported first so they show at once;
  // vips writes to a temp name so the picker never reads a half written file
  readonly property string thumbScript: `
out=$1; shift
mkdir -p "$out" || exit 1
run() {
  while [ $# -ge 2 ]; do
    t="$out/$2.jpg"
    if [ -e "$t" ]; then
      [ "$pass" = have ] && echo "$2"
    elif [ "$pass" = make ] && vipsthumbnail "$1" --size 480x -o "$t.part.jpg[Q=85]" 2>/dev/null && mv -f "$t.part.jpg" "$t"; then
      echo "$2"
    fi
    shift 2
  done
}
pass=have; run "$@"
pass=make; run "$@"
`

  Process {
    id: lister
    command: ["sh", "-c", root.listScript, "sh", Config.wallpaperDir]
    stdout: StdioCollector {
      id: listOut
    }
    onExited: {
      const list = [];
      for (const line of listOut.text.split("\n")) {
        const a = line.indexOf(" ");
        const b = line.indexOf(" ", a + 1);
        if (a < 0 || b < 0)
          continue;
        const path = line.slice(b + 1);
        const name = path.slice(path.lastIndexOf("/") + 1);
        const key = Qt.md5(path + "\n" + line.slice(0, b));
        list.push({
          path: path,
          name: name,
          lower: name.toLowerCase(),
          key: key,
          thumb: root.url(root.thumbDir + "/" + key + ".jpg")
        });
      }
      list.sort((x, y) => x.lower.localeCompare(y.lower));
      // keep the array identity when nothing changed so the picker's view isn't reset
      const sig = list.map(e => e.key).join();
      if (sig !== root.entries.map(e => e.key).join())
        root.entries = list;
      root.scanned = true;
      root.startThumbs();
      if (root.randomPending) {
        root.randomPending = false;
        root.random();
      }
    }
  }

  Process {
    id: thumbProc
    stdout: SplitParser {
      onRead: key => {
        root.ready[key] = true;
        flush.start();
      }
    }
    onExited: {
      flush.stop();
      root.readyRev++;
      if (root.thumbsAgain) {
        root.thumbsAgain = false;
        root.startThumbs();
      }
    }
  }

  // batches thumbnail notifications so a burst of cached ones costs one rebinding
  Timer {
    id: flush
    interval: 120
    onTriggered: root.readyRev++
  }

  Process {
    id: applyProc
    stderr: StdioCollector {
      id: applyErr
    }
    onExited: code => {
      if (root.applyQueued) {
        const next = root.applyQueued;
        root.applyQueued = null;
        applyProc.command = next;
        applyProc.running = true;
        return;
      }
      let message = "";
      if (code !== 0) {
        const lines = applyErr.text.trim().split("\n").filter(l => l.trim() !== "");
        message = lines.length > 0 ? lines.slice(-3).join("\n") : "apply.sh exited with " + code;
        console.warn("wallpaper apply failed: " + message);
      }
      root.applied(code === 0, message);
    }
  }

  Process {
    id: previewProc
    property string key
    stdout: StdioCollector {
      id: previewOut
    }
    onExited: code => {
      if (code === 0) {
        try {
          root.previews[previewProc.key] = JSON.parse(previewOut.text);
          root.previewRev++;
        } catch (e) {
          console.warn("bad preview palette: " + e);
        }
      }
      if (root.previewQueued) {
        const next = root.previewQueued;
        root.previewQueued = null;
        root.runPreview(next);
      }
    }
  }

  Component.onCompleted: scan()
}
