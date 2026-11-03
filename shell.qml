//@ pragma ShellId mahmooz-shell
import Quickshell
import Quickshell.Io
import QtQuick

// entry point, run with: qs
ShellRoot {
  // singletons load lazily, these have to run from startup (the picker so its first open is instant)
  readonly property var services: [Osd, Notifs, Wallpapers, WallpaperPicker]

  Bar {
    id: bar
  }

  Binding {
    target: Popups
    property: "barWindows"
    value: bar.windows
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
