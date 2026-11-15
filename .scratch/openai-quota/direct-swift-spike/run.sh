#!/bin/zsh
set -euo pipefail
probe_dir="${0:A:h}"
probe_build="${TMPDIR:-/private/tmp}/quotai-native-codex-probe"
mkdir -p "$probe_build"
swiftc -parse-as-library -O -module-cache-path "$probe_build/module-cache" \
  "$probe_dir/Probe.swift" -o "$probe_build/quotai-codex-probe"
exec "$probe_build/quotai-codex-probe" "$@"
