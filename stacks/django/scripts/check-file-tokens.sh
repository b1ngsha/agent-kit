#!/usr/bin/env bash
# Keep staged, hand-authored files under the review context budget.
set -euo pipefail

max_tokens=5000
max_bytes=$((max_tokens * 4))
offenders=()

for file in "$@"; do
  bytes=$(git cat-file -s ":$file" 2>/dev/null || wc -c <"$file")
  [ "$bytes" -le "$max_bytes" ] || offenders+=("$file: ~$((bytes / 4)) tokens ($bytes bytes)")
done

[ "${#offenders[@]}" -eq 0 ] && exit 0

cat <<EOF
These staged files are over the $max_tokens-token limit (tokens = bytes / 4,
so $max_bytes bytes):

$(printf '  %s\n' "${offenders[@]}")

Split each file along its concepts before committing. Keep generated files and
lockfiles out of this hook's file pattern; split hand-authored files instead of
minifying or hiding their contents.
EOF
exit 1
