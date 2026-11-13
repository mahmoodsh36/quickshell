//@ pragma ShellId mahmooz-shell
import Quickshell
import Quickshell.Io
import QtQuick

// entry point, run with: qs
ShellRoot {
  // singletons load lazily, these have to run from startup (the picker so its first open is instant)
  readonly property var services: [Osd, Notifs, Wallpapers, WallpaperPicker, Overview, Weather]

  // before the bars, so they stack above it
  Catcher {}

  // one bar style at a time, see Style
  LazyLoader {
    id: topBar
    active: Style.shown === "top"
    Bar {}
  }
  LazyLoader {
    id: rail
    active: Style.rail
    Rail {
      right: Style.railRight
    }
  }
  LazyLoader {
    id: island
    active: Style.shown === "island"
    Island {}
  }
  LazyLoader {
    id: dock
    active: Style.shown === "dock"
    Dock {}
  }

  Binding {
    target: Popups
    property: "barWindows"
    value: [topBar, rail, island, dock].map(l => l.item).filter(b => b).reduce((all, b) => all.concat(Array.from(b.windows)), [])
  }

  Background {}

  IpcHandler {
    target: "sysinfo"

    function toggle(): void {
      SysInfo.toggle();
    }
  }

  IpcHandler {
    target: "calendar"

    function toggle(): void {
      Calendar.toggle();
    }
  }

  IpcHandler {
    target: "launcher"

    function toggle(): void {
      Launcher.toggle("apps");
    }
    function clipboard(): void {
      Launcher.toggle("clipboard");
    }
    function show(): void {
      Launcher.show();
    }
    function hide(): void {
      Launcher.hide();
    }
  }

  IpcHandler {
    target: "cc"

    function toggle(side: string): void {
      ControlCenter.toggle(side);
    }
    function show(side: string): void {
      ControlCenter.show(side);
    }
    function hide(): void {
      ControlCenter.hide();
    }
  }

  IpcHandler {
    target: "volume"

    function up(): void {
      Audio.step(0.05);
    }
    function down(): void {
      Audio.step(-0.05);
    }
    function mute(): void {
      Audio.toggleMute();
    }
  }

  IpcHandler {
    target: "brightness"

    function up(): void {
      Brightness.step(0.05);
    }
    function down(): void {
      Brightness.step(-0.05);
    }
  }

  IpcHandler {
    target: "nightlight"

    function toggle(): void {
      NightLight.toggle();
    }
  }

  IpcHandler {
    target: "recorder"

    function toggle(): void {
      Recorder.toggle(false);
    }
    function region(): void {
      Recorder.toggle(true);
    }
  }

  IpcHandler {
    target: "overview"

    function toggle(): void {
      Overview.toggle();
    }
  }

  IpcHandler {
    target: "weather"

    function toggle(): void {
      WeatherPanel.toggle();
    }
    function refresh(): void {
      Weather.refresh();
    }
  }

  IpcHandler {
    target: "media"

    function toggle(): void {
      MediaPanel.toggle();
    }
  }

  // qs ipc call style set <top|rail|rail-right|island|dock> | cycle | get
  IpcHandler {
    target: "style"

    function set(name: string): void {
      Style.set(name);
    }
    function cycle(): void {
      Style.cycle();
    }
    function get(): string {
      return Style.current;
    }
  }

  // qs ipc call wallpaper toggle | set <path> | random | mode <dark|light|toggle> | scheme <name> | get
  IpcHandler {
    target: "wallpaper"

    function toggle(): void {
      WallpaperPicker.toggle();
    }
    function set(path: string): void {
      Wallpapers.set(path);
    }
    function random(): void {
      Wallpapers.random();
    }
    function mode(m: string): void {
      Wallpapers.setMode(m);
    }
    function scheme(s: string): void {
      Wallpapers.setScheme(s);
    }
    function get(): string {
      return Persist.wallpaper;
    }
  }
}
