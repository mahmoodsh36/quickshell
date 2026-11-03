#!/bin/sh
set -eu
dir=$(cd "$(dirname "$0")" && pwd)
. "$dir/args.sh"
have jq || die "jq not found on PATH"

json=$(matugen image "$img" -c "$dir/preview.toml" -q -m "$mode" -t "$scheme" </dev/null) ||
	die "matugen failed"
printf '%s' "$json" | jq -c . || die "matugen produced invalid json"
