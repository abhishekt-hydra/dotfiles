#!/usr/bin/env bash
# Shrink a PDF (scanned or digital) to fit under a target size.
#
# Usage: ./shrink-pdf.sh input.pdf [target_kb=150] [--gray]
# Output: <input>-compressed.pdf next to the input.
#
# Tries image resolution / JPEG quality combos from best to worst and keeps the
# first (highest quality) result that fits. --gray converts to grayscale, which
# roughly halves the size of colour scans if you need more headroom.
#
# PDFs with real text (fonts) go through shrink_pdf_images.py first, which only
# recompresses the images and leaves text/vectors untouched; ghostscript can
# bloat those (it slices transparent images into hundreds of strips). Scans,
# or anything that path can't get small enough, go through ghostscript.
set -euo pipefail

in="${1:?usage: $0 input.pdf [target_kb] [--gray]}"
target_kb="${2:-150}"
gray=0
for a in "$@"; do [[ "$a" == "--gray" ]] && gray=1; done
[[ "$target_kb" == "--gray" ]] && target_kb=150

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="${in%.pdf}-compressed.pdf"
target=$((target_kb * 1024))
tmpdir="$(mktemp -d)"
tmp="$tmpdir/out.pdf"
trap 'rm -rf "$tmpdir"' EXIT

color_args=()
gray_flag=()
if ((gray)); then
  color_args=(-sColorConversionStrategy=Gray -dProcessColorModel=/DeviceGray)
  gray_flag=(--gray)
fi

try_gs() { # dpi qfactor -> writes $tmp
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

try_img() { # dpi jpeg_quality -> writes $tmp
  python3 "$here/shrink_pdf_images.py" "$in" "$tmp" "$1" "$2" "${gray_flag[@]}"
}

ladder() { # try_fn label "dpi:q dpi:q ..." -> exits 0 on first fit
  local fn=$1 pair dpi q sz
  for pair in $3; do
    dpi=${pair%:*} q=${pair#*:}
    "$fn" "$dpi" "$q" || return 0
    sz=$(stat -f%z "$tmp")
    printf '  %s dpi=%-3s q=%-4s -> %4d KB\n' "$2" "$dpi" "$q" $((sz / 1024))
    if ((sz <= target)); then
      mv "$tmp" "$out"
      echo "done: $out ($((sz / 1024)) KB, $2 ${dpi}dpi q=$q)"
      exit 0
    fi
  done
}

orig=$(stat -f%z "$in")
echo "input: $in ($((orig / 1024)) KB) -> target ${target_kb} KB"
if ((orig <= target)); then
  cp "$in" "$out"; echo "already under target, copied to $out"; exit 0
fi

has_text=$(pdffonts "$in" 2>/dev/null | tail -n +3 | wc -l)
if ((has_text > 0)) && python3 -c "import pikepdf, PIL" 2>/dev/null; then
  # JPEG quality 1-100, higher = better. Drop resolution before quality gets
  # low enough to make logos/stamps blocky.
  ladder try_img images-only "300:85 300:75 200:80 200:70 150:75 150:65 120:70 120:60 100:65 100:55 85:60 85:50 72:55 72:45"
  echo "  images-only can't reach target (text/fonts too big?), trying ghostscript"
fi

# QFactor: lower = better quality (0.15 ~ q90, 0.4 ~ q75, 0.76 ~ q50, 1.3 ~ q30)
gs_steps=$(for d in 200 170 150 130 110 96 85 72 60; do for q in 0.25 0.4 0.55 0.76 1.0; do echo "$d:$q"; done; done)
ladder try_gs ghostscript "$gs_steps"

echo "could not reach ${target_kb} KB; try --gray or a larger target" >&2
exit 1
