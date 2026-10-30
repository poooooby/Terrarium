"""Run one profiling driver with ONLY Terrarium loaded, and leave the
player's setup exactly as it was.

    python tools/profiler/run.py profile_bench_probe
    python tools/profiler/run.py gc_budget_probe --out probe_out/gc_after
    python tools/profiler/run.py profile_play_driver --all-mods

What it does, in order:
  1. refuses if the game is already running (two sessions would fight over
     options.lua and the save directory)
  2. backs up <gen1recomp>/options.lua -- and refuses if a backup from a
     run that died is still there, until you restore or delete it
  3. rewrites options.lua so every installed mod is off for the version
     except Terrarium (tools/profiler/bench_options.lua, via the engine's
     own serializer) -- unless --all-mods
  4. runs the driver (lovec.exe, POKEPORT_DRIVER=<this checkout>/tests/...)
  5. ALWAYS restores options.lua byte for byte, whatever the run did to it
     (the probes pin Terrarium settings, and those persist)

The probes boot through Game:startNewGame{intro=false} and never save, so
the save slots are not touched; the runner checks their timestamps anyway
and says so if one moved.

Environment: GEN1RECOMP (engine checkout), LOVE_EXE, LUAJIT, POKEPORT_VERSION.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
GAME = Path(os.environ.get("GEN1RECOMP")
            or Path.home() / "Documents" / "GitHub" / "gen1recomp")
LOVE = Path(os.environ.get("LOVE_EXE") or r"C:\Program Files\LOVE\lovec.exe")
LUAJIT = os.environ.get("LUAJIT") or str(Path.home() / "luajit" / "bin" / "luajit")
BACKUP_NAME = "options.lua.terrarium-bench-backup"


def game_running():
    if os.name != "nt":
        return False
    out = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True,
                         text=True).stdout.lower()
    return '"love.exe"' in out or '"lovec.exe"' in out


def mod_ids():
    ids = []
    for m in sorted((GAME / "mods").glob("*/manifest.json")):
        try:
            ids.append(json.loads(m.read_text(encoding="utf-8"))["id"])
        except (ValueError, KeyError, OSError):
            pass
    return sorted(set(ids))


def save_stamps(version):
    root = GAME / "saves" / version
    return {p.name: p.stat().st_mtime for p in root.glob("*")} if root.exists() else {}


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("driver", help="tests/<driver>.lua, without .lua")
    ap.add_argument("--out", help="output dir (default probe_out/<driver>)")
    ap.add_argument("--all-mods", action="store_true",
                    help="keep the player's mod set instead of Terrarium only")
    ap.add_argument("--timeout", type=int, default=1800)
    ap.add_argument("--env", action="append", default=[],
                    help="extra NAME=VALUE for the run (DS_GC_RECORD=1, ...)")
    a = ap.parse_args()

    driver = REPO / "tests" / (a.driver + ".lua")
    if not driver.exists():
        sys.exit(f"no such driver: {driver}")
    if game_running():
        sys.exit("the game is running -- close it first")
    options = GAME / "options.lua"
    backup = GAME / BACKUP_NAME
    if backup.exists():
        sys.exit(f"{backup} exists: a previous run did not restore. Compare it "
                 f"with options.lua, keep the right one, delete the backup, rerun.")
    version = os.environ.get("POKEPORT_VERSION", "yellow")
    out = Path(a.out) if a.out else REPO / "probe_out" / a.driver
    out = out if out.is_absolute() else REPO / out
    out.mkdir(parents=True, exist_ok=True)

    manifest = json.loads((REPO / "manifest.json").read_text(encoding="utf-8"))
    mod_id = manifest["id"]

    stamps = save_stamps(version)
    shutil.copy2(options, backup)
    try:
        if not a.all_mods:
            ids = [i for i in mod_ids() if i != mod_id]
            subprocess.run([LUAJIT, str(REPO / "tools" / "profiler" / "bench_options.lua"),
                            "options.lua", version, mod_id, *ids],
                           cwd=GAME, check=True)
        env = dict(os.environ, POKEPORT_VERSION=version,
                   DS_PROBE_DIR=str(out), POKEPORT_DRIVER=str(driver),
                   TERRARIUM_ID=mod_id)
        for kv in a.env:
            k, _, v = kv.partition("=")
            env[k] = v
        print(f"{a.driver} -> {out}  ({'all mods' if a.all_mods else mod_id + ' only'})")
        t0 = time.time()
        with open(out / "console.txt", "w", encoding="utf-8", errors="replace") as con:
            try:
                rc = subprocess.run([str(LOVE), "."], cwd=GAME, env=env, stdout=con,
                                    stderr=subprocess.STDOUT, timeout=a.timeout).returncode
            except subprocess.TimeoutExpired:
                rc = "timeout"
        print(f"exited {rc} after {time.time() - t0:.0f}s")
    finally:
        shutil.copy2(backup, options)
        backup.unlink()
        print("options.lua restored")
    moved = [n for n, t in save_stamps(version).items() if stamps.get(n) != t]
    if moved:
        print("WARNING: save files changed during the run:", ", ".join(moved))
    for log in sorted(out.glob("*.log")):
        print(f"--- {log.name}")
        lines = log.read_text(encoding="utf-8", errors="replace").splitlines()
        for ln in [l for l in lines if l.startswith(("FAIL", "PASS", "NOTE", "NEW"))] or lines[-15:]:
            print(ln)


if __name__ == "__main__":
    main()
