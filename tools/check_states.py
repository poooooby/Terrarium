"""Keep assets/docs/state-machines.md and the StateReport declarations honest.

    python tools/check_states.py

Every `StateReport.define("name", ...)` in main.lua and lib/*.lua must have a
row in the catalogue's "Reported" table, and every row there must still have a
define. Exits non-zero and names the difference when they disagree, the way
tools/gen_modkitignore.py --check does.
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
DOC = REPO / "assets" / "docs" / "state-machines.md"
# both spellings: a local `StateReport` and V.require("StateReport") inline
DEFINE = re.compile(r'StateReport(?:"\))?\.define\(\s*"([a-z0-9_.-]+)"')
HEADING = "## Reported"
ROW = re.compile(r"^\|\s*`([a-z0-9_.-]+)`\s*\|", re.M)


def declared():
    found = {}
    for path in [REPO / "main.lua", *sorted((REPO / "lib").glob("*.lua"))]:
        for name in DEFINE.findall(path.read_text(encoding="utf-8", errors="replace")):
            found.setdefault(name, path.relative_to(REPO).as_posix())
    return found


def catalogued():
    text = DOC.read_text(encoding="utf-8")
    start = text.find(HEADING)
    if start < 0:
        sys.exit(f"{DOC}: no '{HEADING}' section")
    # up to the next section of the same level
    rest = text[start + len(HEADING):]
    end = re.search(r"^## ", rest, re.M)
    return set(ROW.findall(rest[: end.start()] if end else rest))


def main():
    code, doc = declared(), catalogued()
    missing = sorted(set(code) - doc)
    stale = sorted(doc - set(code))
    for name in missing:
        print(f"not in the catalogue: {name} ({code[name]})")
    for name in stale:
        print(f"in the catalogue but never defined: {name}")
    if missing or stale:
        sys.exit(1)
    print(f"{len(code)} reported lifecycles, catalogue up to date")


if __name__ == "__main__":
    main()
