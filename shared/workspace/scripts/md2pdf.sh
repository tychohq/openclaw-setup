#!/usr/bin/env bash
# md2pdf — Convert Markdown to PDF via pandoc + tectonic
# Usage: md2pdf input.md [output.pdf]
# If output is omitted, uses input filename with .pdf extension

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: md2pdf <input.md> [output.pdf]" >&2
  exit 1
fi

INPUT="$1"
OUTPUT="${2:-${INPUT%.md}.pdf}"

if [ ! -f "$INPUT" ]; then
  echo "Error: $INPUT not found" >&2
  exit 1
fi

pandoc "$INPUT" \
  --pdf-engine=tectonic \
  -V geometry:margin=1in \
  -V fontsize=11pt \
  -V 'mainfont=Avenir Next' \
  -V monofont=Menlo \
  -o "$OUTPUT"

echo "$OUTPUT"
