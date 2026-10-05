import Quickshell
import Quickshell.Io
import QtQuick

// entry point, run with: qs
// switch theme live: qs ipc call theme set <name> | next | get | list
ShellRoot {
  // singletons load lazily, these have to run from startup
  readonly property var services: [Osd, Notifs]

  IpcHandler {
    target: "theme"

    function set(name: string): void {
      Theme.setTheme(name);
    }
    function next(): void {
      Theme.nextTheme();
    }
    function get(): string {
      return Theme.themeName;
    }
    function list(): string {
      return Theme.themeNames.join(" ");
    }
  }

  Bar {
    id: bar
  }

  Binding {
    target: ControlCenter
    property: "barWindows"
    value: bar.windows
  }
  Binding {
    target: Calendar
    property: "barWindows"
    value: bar.windows
  }
  Binding {
    target: SysInfo
    property: "barWindows"
    value: bar.windows
  }

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
}
