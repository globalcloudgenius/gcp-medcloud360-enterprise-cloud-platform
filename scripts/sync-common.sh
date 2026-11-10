#!/usr/bin/env bash
# Copies terraform/_common/*.tf into every stage. Run after editing a common file.
# CI runs it with --check and fails if any stage has drifted.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="${1:-}"
rc=0
for stage in "$ROOT"/terraform/[0-9][0-9]-*/; do
  for f in "$ROOT"/terraform/_common/*.tf; do
    dest="$stage$(basename "$f")"
    if [[ "$CHECK" == "--check" ]]; then
      cmp -s "$f" "$dest" || { echo "drift: $dest"; rc=1; }
    else
      cp "$f" "$dest"
    fi
  done
done
exit $rc
