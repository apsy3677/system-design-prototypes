#!/usr/bin/env bash
# Render every ```mermaid block in the repo's Markdown files to SVG.
#
# The Markdown stays the single source of truth (GitHub and Cursor render
# the blocks directly). The SVGs are for viewers that can't: block N of
# path/to/README.md is written to path/to/diagrams/README-N.svg.
# A block that fails to render fails the script, which doubles as a
# syntax check before GitHub shows a broken diagram.
set -euo pipefail

cd "$(dirname "$0")/.."
command -v mmdc >/dev/null || { echo "mmdc not found: npm install -g @mermaid-js/mermaid-cli"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

count=0
while IFS= read -r md; do
  dir=$(dirname "$md")
  base=$(basename "$md" .md)
  # Split mermaid blocks into $tmp/<base>-<n>.mmd
  awk -v out="$tmp/$base" '
    /^```mermaid[[:space:]]*$/ { n++; f = out "-" n ".mmd"; inblock = 1; next }
    inblock && /^```[[:space:]]*$/ { inblock = 0; close(f); next }
    inblock { print > f }
  ' "$md"
  for mmd in "$tmp/$base"-*.mmd; do
    [ -e "$mmd" ] || continue
    mkdir -p "$dir/diagrams"
    svg="$dir/diagrams/$(basename "$mmd" .mmd).svg"
    mmdc -q -i "$mmd" -o "$svg" -b white
    echo "rendered $svg"
    rm "$mmd"
    count=$((count + 1))
  done
done < <(grep -rl --include='*.md' '^```mermaid' . --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=_template)

echo "$count diagram(s) rendered"
