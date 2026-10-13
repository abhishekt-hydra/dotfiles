#!/usr/bin/env python3
"""Recompress only the images in a PDF; text, fonts and vector art are untouched.

Usage: shrink_pdf_images.py in.pdf out.pdf DPI JPEG_QUALITY [--gray]

Images drawn above DPI are downsampled to it and re-encoded as JPEG at
JPEG_QUALITY; an image is only replaced when that makes it smaller. Soft masks
(transparency) are scaled with their image and kept lossless.
Used by shrink-pdf.sh for digital PDFs, where ghostscript bloats the output.
"""
import io
import subprocess
import sys
import zlib

import pikepdf
from pikepdf import Name, PdfImage
from PIL import Image


def image_ppi(path):
    """object number -> highest ppi the image is drawn at (from poppler's pdfimages)."""
    out = subprocess.run(["pdfimages", "-list", path], capture_output=True, text=True, check=True).stdout
    ppi = {}
    for line in out.splitlines()[2:]:
        f = line.split()
        if len(f) < 14 or f[2] != "image" or not f[10].isdigit():
            continue  # masks, stencils and inline images
        obj = int(f[10])
        ppi[obj] = max(ppi.get(obj, 0), int(f[12]), int(f[13]))
    return ppi


def scale_mask(mask, size):
    m = PdfImage(mask).as_pil_image().convert("L").resize(size, Image.LANCZOS)
    mask.write(zlib.compress(m.tobytes(), 9), filter=Name.FlateDecode)
    mask.Width, mask.Height = size
    mask.ColorSpace = Name.DeviceGray
    mask.BitsPerComponent = 8
    if "/DecodeParms" in mask:
        del mask.DecodeParms


def shrink(img, ppi, dpi, quality, gray):
    if "/Decode" in img or "/Mask" in img:
        return  # unusual decode arrays / colour-key masks: not worth the risk
    try:
        pil = PdfImage(img).as_pil_image()
    except Exception:
        return  # encodings Pillow can't read (JBIG2, odd colour spaces): leave as is
    if pil.mode == "P":
        pil = pil.convert("RGB")
    if pil.mode not in ("RGB", "L"):
        return  # CMYK etc.: converting risks colour shifts
    keep_cs = pil.mode == PdfImage(img).mode and "/Indexed" not in str(img.get("/ColorSpace"))

    scale = min(1.0, dpi / ppi) if ppi else 1.0
    size = (max(1, round(pil.width * scale)), max(1, round(pil.height * scale)))
    if size != pil.size:
        pil = pil.resize(size, Image.LANCZOS)
    if gray and pil.mode == "RGB":
        pil, keep_cs = pil.convert("L"), False

    buf = io.BytesIO()
    pil.save(buf, "JPEG", quality=quality, optimize=True)
    data = buf.getvalue()
    if len(data) >= len(img.read_raw_bytes()):
        return

    img.write(data, filter=Name.DCTDecode)
    img.Width, img.Height = size
    img.BitsPerComponent = 8
    if not keep_cs:
        img.ColorSpace = Name.DeviceGray if pil.mode == "L" else Name.DeviceRGB
    if "/SMask" in img and scale < 1:
        scale_mask(img.SMask, size)


def main():
    src, dst, dpi, quality = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    gray = "--gray" in sys.argv[5:]
    ppi = image_ppi(src)
    with pikepdf.open(src) as pdf:
        for obj in pdf.objects:
            if isinstance(obj, pikepdf.Stream) and obj.get("/Subtype") == Name.Image and not obj.get("/ImageMask"):
                if obj.objgen[0] in ppi:  # drawn as a picture, i.e. not itself someone's soft mask
                    shrink(obj, ppi[obj.objgen[0]], dpi, quality, gray)
        pdf.remove_unreferenced_resources()
        pdf.save(dst, compress_streams=True, recompress_flate=True,
                 object_stream_mode=pikepdf.ObjectStreamMode.generate)


if __name__ == "__main__":
    main()
