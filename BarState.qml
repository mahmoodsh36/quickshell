pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import QtQuick

// workspace, window and battery state every bar style shows, from hyprland or niri
Singleton {
  readonly property bool niri: Niri.active
  // the top bar's popups close on outside clicks via hyprland's focus grab; see Popups.catching for the rest
  readonly property bool hasGrab: !niri && !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")

  // niri workspaces are per output and indexed from 1, so show the focused output's
  readonly property var niriWs: Niri.workspaces.filter(w => w.output === Niri.focusedOutput)

  // special hyprland workspaces have negative ids
  readonly property var wsIds: niri ? niriWs.filter(w => w.active_window_id !== null).map(w => w.idx) : Array.from(Hyprland.workspaces.values).map(w => w.id).filter(id => id > 0)
  readonly property int focusedWs: niri ? (Niri.focusedWorkspace ? Niri.focusedWorkspace.idx : -1) : Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
  // hyprland: 1..5 always, higher ones while in use. niri keeps one empty workspace at the end
  readonly property int wsCount: niri ? Math.max(1, niriWs.length) : Math.max(5, focusedWs, ...wsIds)
  readonly property string winTitle: niri ? (Niri.focusedWindow ? Niri.focusedWindow.title || "" : "") : Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""

  // { address, title, appId, wsId, focused }; wsId is -1 off the focused output under niri
  readonly property var windows: {
    if (niri) {
      const idx = {};
      for (const w of niriWs)
        idx[w.id] = w.idx;
      return Niri.windows.map(w => ({
            address: String(w.id),
            title: w.title || "",
            appId: w.app_id || "",
            wsId: idx[w.workspace_id] || -1,
            focused: w.is_focused
          }));
    }
    return Array.from(Hyprland.toplevels.values).map(t => ({
          address: t.address,
          title: t.title,
          appId: t.wayland ? t.wayland.appId : "",
          wsId: t.workspace ? t.workspace.id : -1,
          focused: t.wayland ? t.wayland.activated : false
        }));
  }

  readonly property var bat: UPower.displayDevice
  readonly property bool hasBat: bat !== null && bat.isLaptopBattery
  // upower reports 0..1
  readonly property int batPct: hasBat ? Math.round(bat.percentage * 100) : 0
  readonly property bool charging: hasBat && bat.state === UPowerDeviceState.Charging
  readonly property bool batLow: hasBat && batPct < 20 && !charging

  function batIcon() {
    if (charging)
      return "battery_charging_full";
    return batPct >= 95 ? "battery_full" : "battery_" + Math.round(batPct / 100 * 6) + "_bar";
  }

  // hyprland addresses are bare hex, niri's are window ids
  function focusWindow(address) {
    if (niri)
      Niri.action(["focus-window", "--id", address]);
    else
      Hyprland.dispatch("hl.dsp.focus({ window = \"address:0x" + address + "\" })");
  }
  function moveWindow(address, ws) {
    if (niri)
      Niri.action(["move-window-to-workspace", "--window-id", address, "--focus", "false", String(ws)]);
    else
      Hyprland.dispatch("hl.dsp.window.move({ workspace = " + ws + ", window = \"address:0x" + address + "\", silent = true })");
  }

  function focusWs(id) {
    if (id < 1)
      return;
    if (niri)
      Niri.action(["focus-workspace", String(id)]);
    else
      Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
  }
}
