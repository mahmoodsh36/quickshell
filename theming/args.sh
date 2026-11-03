prog=${0##*/}
die() { printf '%s: %s\n' "$prog" "$*" >&2; exit 1; }
warn() { printf '%s: warning: %s\n' "$prog" "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

[ $# -eq 3 ] || die "usage: $prog <image> <dark|light> <scheme>"
img=$1 mode=$2 scheme=$3

case $img in /*) ;; *) img=$PWD/$img ;; esac
[ -f "$img" ] || die "image not found: $img"

case $mode in dark | light) ;; *) die "mode must be dark or light, got '$mode'" ;; esac

case $scheme in scheme-*) ;; *) scheme=scheme-$scheme ;; esac
case $scheme in
scheme-content | scheme-expressive | scheme-fidelity | scheme-fruit-salad | scheme-monochrome | \
	scheme-neutral | scheme-rainbow | scheme-tonal-spot | scheme-vibrant | scheme-smart) ;;
*) die "unknown scheme '$3'" ;;
esac

have matugen || die "matugen not found on PATH"
