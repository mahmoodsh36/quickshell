import Quickshell
import Quickshell.Io

// entry point, run with: qs
// switch theme live: qs ipc call theme set nord | next | get | list
ShellRoot {
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

  Bar {}

  IpcHandler {
    target: "launcher"

    function toggle(): void {
      Launcher.toggle();
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
}
