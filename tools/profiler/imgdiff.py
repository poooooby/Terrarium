"""Compare two sets of probe screenshots (shot_<map>.png) for the
"no visual change" check on a garbage fix.

A frame of this mod is never bit-identical across two runs: water,
grass sway, clouds and ambient life all move with wall-clock time, and a
probe's frame lands at a slightly different moment each run. So a raw
"identical?" would fail every fix, including no fix at all. The honest test
is relative: measure the NOISE (baseline run A against baseline run B,
same build) and then the CHANGE (baseline against the fixed build). A fix
that changes nothing visual reads inside the noise band; a fix that broke a
billboard matrix reads far outside it.

    python tools/profiler/imgdiff.py <dirA> <dirB>              # one pair
    python tools/profiler/imgdiff.py <base1> <base2> <fixed>    # noise vs change

Per shot it prints the mean absolute channel difference (0-255) and the
share of pixels that differ by more than 24 on any channel. With three dirs
it flags a shot whose change exceeds max(2x noise, noise + 1.0).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def load(p):
    return np.asarray(Image.open(p).convert("RGB"), dtype=np.int16)


def diff(a, b):
    if a.shape != b.shape:
        return None
    d = np.abs(a - b)
    return float(d.mean()), float((d.max(axis=2) > 24).mean() * 100)


def pairs(da, db):
    out = {}
    for pa in sorted(Path(da).glob("shot_*.png")):
        pb = Path(db) / pa.name
        if pb.exists():
            out[pa.stem] = diff(load(pa), load(pb))
    return out


def main(argv):
    if len(argv) == 2:
        for name, r in pairs(*argv).items():
            print(f"{name:28} " + ("SIZE MISMATCH" if r is None
                                   else f"mean {r[0]:6.2f}  >24: {r[1]:6.2f}%"))
        return 0
    if len(argv) == 3:
        noise, change = pairs(argv[0], argv[1]), pairs(argv[0], argv[2])
        bad = 0
        for name in sorted(change):
            n, c = noise.get(name), change[name]
            if n is None or c is None:
                print(f"{name:28} missing or size mismatch")
                bad += 1
                continue
            limit = max(2 * n[0], n[0] + 1.0)
            flag = "CHANGED" if c[0] > limit else "ok"
            bad += flag != "ok"
            print(f"{name:28} noise {n[0]:6.2f}  change {c[0]:6.2f}  "
                  f"(limit {limit:5.2f})  {flag}")
        return 1 if bad else 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
