"""Record the game window from OUTSIDE while a driver runs, and count the
black frames per phase.

    python tools/profiler/flicker_record.py [--all-mods] [--driver flicker_bisect_probe]

Captured with ffmpeg's ddagrab (Desktop Duplication, what Snagit and remote
desktop see), cropped to the game window. gdigrab was tried first and gets
an all-black window: GDI cannot read an OpenGL window's contents.

Why outside: the black strobe reported on 2026-10-29 shows on the monitor,
over remote desktop and in a Snagit recording, but never in a frame read
back from inside the game (captureScreenshot).

The driver logs "PHASE n at epoch S: <what changed>"; frames are binned by
wall-clock second against those lines.
"""
import argparse
import re
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
FFMPEG = "ffmpeg"


def window_title():
    ps = ("Get-Process love,lovec -ErrorAction SilentlyContinue | "
          "Where-Object { $_.MainWindowTitle } | "
          "Select-Object -First 1 -ExpandProperty MainWindowTitle")
    out = subprocess.run(["powershell", "-NoProfile", "-Command", ps],
                         capture_output=True, text=True).stdout.strip()
    return out or None


def window_rect():
    """Client-area rect of the game window in desktop pixels, or None."""
    ps = r"""
Add-Type @"
using System; using System.Runtime.InteropServices;
public class W {
  [StructLayout(LayoutKind.Sequential)] public struct R { public int L, T, Ri, B; }
  [StructLayout(LayoutKind.Sequential)] public struct P { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref P p);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[W]::SetProcessDPIAware() | Out-Null
$p = Get-Process love,lovec -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if ($p) { $r = New-Object W+R; [W]::GetClientRect($p.MainWindowHandle, [ref]$r) | Out-Null
  $pt = New-Object W+P; [W]::ClientToScreen($p.MainWindowHandle, [ref]$pt) | Out-Null
  "$($pt.X) $($pt.Y) $($r.Ri) $($r.B)" }
"""
    out = subprocess.run(["powershell", "-NoProfile", "-Command", ps],
                         capture_output=True, text=True).stdout.split()
    if len(out) != 4:
        return None
    x, y, w, h = (int(v) for v in out)
    return x, y, w - w % 2, h - h % 2


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--driver", default="flicker_bisect_probe")
    ap.add_argument("--all-mods", action="store_true")
    ap.add_argument("--seconds", type=int, default=60)
    ap.add_argument("--env", action="append", default=[])
    ap.add_argument("--with", dest="with_mods", action="append", default=[],
                    help="enable this mod alongside Terrarium (run.py --with)")
    a = ap.parse_args()

    # a previous run's log already says "start epoch"; waiting on it would
    # start the recording before this run's warm-up is over
    stale_root = Path(__import__("os").environ.get("TERRARIUM_PROBE_OUT")
                      or REPO.parent / (REPO.name + "-probe_out")) / a.driver
    stale = stale_root / (a.driver.replace("_probe", "") + ".log")
    if stale.exists():
        stale.unlink()
    cmd = [sys.executable, str(HERE / "run.py"), a.driver, "--timeout", "600"]
    if a.all_mods:
        cmd.append("--all-mods")
    for e in a.env:
        cmd += ["--env", e]
    for m in a.with_mods:
        cmd += ["--with", m]
    run = subprocess.Popen(cmd)

    out_root = Path(__import__("os").environ.get("TERRARIUM_PROBE_OUT")
                    or REPO.parent / (REPO.name + "-probe_out")) / a.driver
    log = out_root / (a.driver.replace("_probe", "") + ".log")
    # wait for the driver's warm-up to end ("start epoch" in its log): the
    # launcher window comes first and the game window resizes while booting,
    # so the position is only read once the scene is up
    t_end = time.time() + 180
    while time.time() < t_end:
        time.sleep(1)
        if run.poll() is not None:
            sys.exit("the run ended before the warm-up finished")
        if log.exists() and "start epoch" in log.read_text(encoding="utf-8",
                                                           errors="replace"):
            break
    rect = window_rect()
    if not rect:
        run.wait()
        sys.exit("could not read the game window's position")
    x, y, w, h = rect
    print(f"game window client area {w}x{h} at ({x},{y}) on display 0")
    video = out_root / "window.mp4"
    start = time.time()
    # the whole display, cropped in software: a ddagrab crop rectangle set
    # while the window was still moving failed outright
    grab = "ddagrab=output_idx=0:framerate=30:draw_mouse=0,hwdownload,format=bgra"
    rec = subprocess.Popen([FFMPEG, "-v", "error", "-y", "-f", "lavfi",
                            "-i", grab, "-t", str(a.seconds), "-vf",
                            f"crop={w}:{h}:{x}:{y}", "-pix_fmt", "yuv420p",
                            str(video)])
    rec.wait()
    run.wait()
    print(f"recorded {video} from epoch {start:.1f}")

    # mean brightness per frame, 64x36 greyscale
    raw = subprocess.run([FFMPEG, "-v", "error", "-i", str(video), "-vf",
                          "scale=64:36,format=gray", "-f", "rawvideo", "-"],
                         capture_output=True).stdout
    n = 64 * 36
    means = [sum(raw[i:i + n]) / n for i in range(0, len(raw) - n + 1, n)]
    phases = []
    if log.exists():
        for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
            m = re.match(r"PHASE (\d+) at epoch (\d+): (.*)", line)
            if m:
                phases.append((int(m.group(2)), m.group(1), m.group(3)))
    end_epoch = start + len(means) / 30.0
    rows = []
    for i, (ep, num, what) in enumerate(phases):
        nxt = phases[i + 1][0] if i + 1 < len(phases) else end_epoch
        lo = int((ep + 1 - start) * 30)          # skip the switching second
        hi = int((nxt - start) * 30)
        seg = means[max(lo, 0):max(hi, 0)]
        if not seg:
            continue
        med = sorted(seg)[len(seg) // 2]
        black = sum(1 for v in seg if v < 0.35 * med)
        rows.append((num, what, len(seg), black, med))
    for num, what, frames, black, med in rows:
        print(f"phase {num}: {black:3d} black of {frames:4d} frames "
              f"(median brightness {med:.0f})  {what}")
    if not rows:
        allb = [i for i in range(1, len(means)) if means[i] < 0.35 * means[i - 1]]
        print(f"no phases logged; {len(allb)} black frames overall")


if __name__ == "__main__":
    main()
