#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
from typing import List, Tuple

ROOT = Path("test262/test")
ALLOWLIST = Path("test262.allowlist.txt")
OUT = Path("test262.allowlist.glob.txt")


def process_dir(path: Path, allow: set[str]) -> Tuple[List[str], List[str], int, int]:
    patterns: List[str] = []
    files: List[str] = []
    total_js = 0
    allow_js = 0

    try:
        entries = sorted(path.iterdir(), key=lambda p: p.name)
    except FileNotFoundError:
        return patterns, files, total_js, allow_js

    for entry in entries:
        if entry.is_dir():
            child_patterns, child_files, child_total, child_allow = process_dir(entry, allow)
            total_js += child_total
            allow_js += child_allow
            if child_total > 0 and child_allow == child_total:
                patterns.append(entry.as_posix() + "/**")
            else:
                patterns.extend(child_patterns)
                files.extend(child_files)
        elif entry.is_file() and entry.suffix == ".js":
            total_js += 1
            rel = entry.as_posix()
            if rel in allow:
                allow_js += 1
                files.append(rel)

    return patterns, files, total_js, allow_js


def main() -> None:
    allow = {line.strip() for line in ALLOWLIST.read_text().splitlines() if line.strip()}
    patterns, files, total_js, allow_js = process_dir(ROOT, allow)

    # If the root is fully covered, prefer a single glob.
    if total_js > 0 and allow_js == total_js:
        out_lines = [ROOT.as_posix() + "/**"]
    else:
        out_lines = sorted(patterns) + sorted(files)

    OUT.write_text("\n".join(out_lines) + "\n")
    print(f"wrote {OUT} (patterns={len(patterns)} files={len(files)} total_js={total_js} allow_js={allow_js})")


if __name__ == "__main__":
    main()
