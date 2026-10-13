#!/usr/bin/env bash
# Shrink a PDF (especially scanned ones) to fit under a target size.
#
# Usage: ./shrink-pdf.sh input.pdf [target_kb=150] [--gray]
# Output: <input>-compressed.pdf next to the input.
#
# Tries image resolution / JPEG quality combos from best to worst and keeps the
# first (highest quality) result that fits. --gray converts to grayscale, which
# roughly halves the size of colour scans if you need more headroom.
set -euo pipefail

in="${1:?usage: $0 input.pdf [target_kb] [--gray]}"
target_kb="${2:-150}"
gray=0
for a in "$@"; do [[ "$a" == "--gray" ]] && gray=1; done
[[ "$target_kb" == "--gray" ]] && target_kb=150

out="${in%.pdf}-compressed.pdf"
target=$((target_kb * 1024))
tmpdir="$(mktemp -d)"
tmp="$tmpdir/out.pdf"
trap 'rm -rf "$tmpdir"' EXIT

color_args=()
if ((gray)); then
  color_args=(-sColorConversionStrategy=Gray -dProcessColorModel=/DeviceGray)
fi

try() { # dpi qfactor -> writes $tmp
  local dpi=$1 qf=$2
  gs -q -dNOPAUSE -dBATCH -dSAFER -sDEVICE=pdfwrite -dCompatibilityLevel=1.5 \
    -dPassThroughJPEGImages=false -dPassThroughJPXImages=false \
    -dDetectDuplicateImages=true -dCompressFonts=true -dSubsetFonts=true \
    -dDownsampleColorImages=true -dColorImageDownsampleType=/Bicubic \
    -dColorImageResolution="$dpi" -dColorImageDownsampleThreshold=1.0 \
    -dDownsampleGrayImages=true -dGrayImageDownsampleType=/Bicubic \
    -dGrayImageResolution="$dpi" -dGrayImageDownsampleThreshold=1.0 \
    -dDownsampleMonoImages=true -dMonoImageResolution=$((dpi * 2)) \
    -dAutoFilterColorImages=false -dColorImageFilter=/DCTEncode \
    -dAutoFilterGrayImages=false -dGrayImageFilter=/DCTEncode \
    "${color_args[@]}" \
    -sOutputFile="$tmp" \
    -c "<< /ColorImageDict << /QFactor $qf /Blend 1 /HSamples [2 1 1 2] /VSamples [2 1 1 2] >>
          /GrayImageDict  << /QFactor $qf /Blend 1 /HSamples [2 1 1 2] /VSamples [2 1 1 2] >>
       >> setdistillerparams" \
    -f "$in"
}

orig=$(stat -f%z "$in")
echo "input: $in ($((orig / 1024)) KB) -> target ${target_kb} KB"
if ((orig <= target)); then
  cp "$in" "$out"; echo "already under target, copied to $out"; exit 0
fi

# QFactor: lower = better quality (0.15 ~ q90, 0.4 ~ q75, 0.76 ~ q50, 1.3 ~ q30)
for dpi in 200 170 150 130 110 96 85 72 60; do
  for qf in 0.25 0.4 0.55 0.76 1.0; do
    try "$dpi" "$qf"
    sz=$(stat -f%z "$tmp")
    printf '  dpi=%-3s q=%-4s -> %4d KB\n' "$dpi" "$qf" $((sz / 1024))
    if ((sz <= target)); then
      mv "$tmp" "$out"
      echo "done: $out ($((sz / 1024)) KB, ${dpi}dpi, QFactor $qf)"
      exit 0
    fi
  done
done

echo "could not reach ${target_kb} KB; try --gray or a larger target" >&2
exit 1
