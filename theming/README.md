# theming

Wallpaper to system colors with [matugen](https://github.com/InioX/matugen) 4.x.

- `apply.sh <image> <dark|light> <scheme>` renders `templates/` into the theme dir
  (`${XDG_STATE_HOME:-~/.local/state}/theme`: `colors.json`, `gtk.css`, `wezterm.lua`, `hyprland.lua`),
  links `~/.cache/wallpaper` and `~/.config/gtk-{3,4}.0/gtk.css` (skipping nix store links), sets
  gsettings and recolors hyprland borders with `hyprctl eval` when those exist. WezTerm watches the theme dir itself.
- `preview.sh <image> <dark|light> <scheme>` prints the `colors.json` object to stdout and writes nothing.
- `scheme` is a matugen type (`scheme-tonal-spot`, `scheme-vibrant`, ...); the `scheme-` prefix is optional.
- warning, success, info and the terminal ansi colors are fixed per-mode hues from `hues.json`,
  harmonized toward the wallpaper's source color in the templates, so they stay recognizable in every scheme.

By hand, without quickshell:

    sh apply.sh ~/pics/wall.jpg dark scheme-tonal-spot
    # or raw matugen (template output paths are absolute and need -p):
    matugen image ~/pics/wall.jpg -c matugen.toml -p ~/.local/state/theme -m dark -t scheme-tonal-spot

Runtime deps: matugen (4.x), jq, POSIX sh and coreutils; gsettings and hyprctl are optional.
