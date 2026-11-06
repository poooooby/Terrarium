"""Re-encode the painted-ground sheets as palette PNGs.

FadeyMods' Kanto ground (assets/buildings/kantoground_<MAP>.png) arrived as
32-bit RGBA: every alpha 255, about 400 colours a sheet, 17.7 MB for 34
sheets. PNG cannot compress noise, and those sheets are mostly painted
noise, so the alpha channel cost nothing to drop and the colour count is
what decided the size. At 128 colours the set is 7.9 MB.

128 was chosen against still-frame shots of five maps
(tests/kanto_shots_probe.lua with DS_SHOT_STILL=1): the change sits just
above the run-to-run noise, about the same as 64 colours (6.8 MB), with
more of the painting's grain kept. Texels never move -- the data files
(data/kantoground_<MAP>.lua) index the sheet by position -- only their
colours are mapped to the nearest of the palette's. No dither: a dithered
texel would be a different colour from its neighbour where the painting
had none.

    python tools/quantize_ground_sheets.py            # 128 colours, in place
    python tools/quantize_ground_sheets.py --colors 64
    python tools/quantize_ground_sheets.py --check    # fail if any sheet is
                                                      # not a palette PNG

Rerun it whenever the sheets are regenerated (tools/kanto_ground.py, which
is FadeyMods' and not in this repository): the generator writes RGBA.
"""
import argparse
import glob
import os
import sys

from PIL import Image

SHEETS = "assets/buildings/kantoground_*.png"


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--colors", type=int, default=128)
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    paths = sorted(glob.glob(os.path.join(root, SHEETS)))
    if not paths:
        sys.exit("no sheets match " + SHEETS)
    if a.check:
        bad = [p for p in paths if Image.open(p).mode != "P"]
        for p in bad:
            print("not a palette PNG:", os.path.relpath(p, root))
        sys.exit(1 if bad else 0)
    before = after = 0
    for p in paths:
        before += os.path.getsize(p)
        im = Image.open(p)
        if im.mode == "P" and len(im.getcolors(1 << 16) or []) <= a.colors:
            after += os.path.getsize(p)
            continue
        q = im.convert("RGB").quantize(colors=a.colors, method=Image.Quantize.MEDIANCUT,
                                       dither=Image.Dither.NONE)
        q.save(p, "PNG", optimize=True)
        after += os.path.getsize(p)
    print(f"{len(paths)} sheets, {a.colors} colours: "
          f"{before / 1048576:.2f} MB -> {after / 1048576:.2f} MB")


if __name__ == "__main__":
    main()
