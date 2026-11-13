my quickshell config

run it with `nix run github:mahmoodsh36/quickshell`, or from a NixOS config import
`nixosModules.default` and set `mahmooz.quickshell.enable = true`. set `mahmooz.quickshell.liveDir`
to a checkout to hot reload edits.

five layouts, switched live from the control center or with `qs ipc call style set <name>` (`cycle`,
`get`): `top` (classic bar, popups under it), `rail` and `rail-right` (vertical bar whose popups open
in one drawer that morphs between them; hovering a button peeks its popup), `island` (a pill at the
top that morphs into activities and popups) and `dock` (floating dock, popups rise out of it).
`qs ipc call overview toggle` opens a workspace overview, `qs ipc call media toggle` the media page.
weather comes from open-meteo for Haifa by default; set `QS_WEATHER_LOCATION="lat,lon,name"` (and
optionally `QS_WEATHER_UNIT=fahrenheit`) through the module's `env` option to change it.

works under hyprland and niri. on niri, workspaces and windows come from `niri msg --json event-stream`,
the overview opens niri's own, and popups close on outside clicks by covering the screen since niri has
no focus grab.
