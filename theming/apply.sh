#!/bin/sh
set -eu
dir=$(cd "$(dirname "$0")" && pwd)
. "$dir/args.sh"

theme=${XDG_STATE_HOME:-$HOME/.local/state}/theme
config=${XDG_CONFIG_HOME:-$HOME/.config}
files="colors.json gtk.css wezterm.lua hyprland.lua"

mkdir -p "$theme" || die "cannot create $theme"
# render into a sibling dir and rename, so watchers never read a half written file
stage=$(mktemp -d "$theme.stage.XXXXXX") || die "cannot create a staging dir next to $theme"
trap 'rm -rf "$stage"' EXIT
trap 'exit 1' INT TERM HUP

if ! out=$(matugen image "$img" -c "$dir/matugen.toml" -p "$stage" -m "$mode" -t "$scheme" </dev/null 2>&1); then
	printf '%s\n' "$out" >&2
	die "matugen failed"
fi
for f in $files; do
	[ -s "$stage/$f" ] || { printf '%s\n' "$out" >&2; die "matugen did not produce $f"; }
done
if have jq && ! jq -e . "$stage/colors.json" >/dev/null 2>&1; then
	die "generated colors.json is not valid json"
fi
for f in $files; do
	mv -f "$stage/$f" "$theme/$f" || die "cannot write $theme/$f"
done

{ mkdir -p "$HOME/.cache" && ln -sfn "$img" "$HOME/.cache/wallpaper"; } ||
	die "cannot link $HOME/.cache/wallpaper"

for v in 3.0 4.0; do
	t=$config/gtk-$v/gtk.css
	if [ -L "$t" ]; then
		case $(readlink "$t") in
		/nix/store/*)
			warn "$t is managed by nix, not touching it"
			continue
			;;
		esac
	fi
	{ mkdir -p "$config/gtk-$v" && ln -sfn "$theme/gtk.css" "$t"; } || warn "cannot link $t"
done

if have gsettings; then
	s=org.gnome.desktop.interface
	if [ "$mode" = dark ]; then
		gsettings set $s color-scheme prefer-dark || warn "gsettings color-scheme failed"
		gsettings set $s gtk-theme adw-gtk3-dark || warn "gsettings gtk-theme failed"
	else
		# prefer-light is missing from older schemas, where default means light
		gsettings set $s color-scheme prefer-light 2>/dev/null ||
			gsettings set $s color-scheme default || warn "gsettings color-scheme failed"
		gsettings set $s gtk-theme adw-gtk3 || warn "gsettings gtk-theme failed"
	fi
fi

# eval sets only the borders; a full reload would redo every rule, bind and monitor
if have hyprctl && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
	lua="local t = dofile([==[$theme/hyprland.lua]==]); hl.config({ general = { col = {
		active_border = t.active_border, inactive_border = t.inactive_border } } })"
	r=$(hyprctl eval "$lua" 2>&1) || r=${r:-failed}
	[ "$r" = ok ] || warn "hyprctl eval: $r"
fi
