#!/usr/bin/env python3
import subprocess
import json
import os
import sys

from build_authentic_push_campaign import (
    is_watertight, audit_solid_2x2, replay_solution, get_topology_set, check_candidate_architecture
)

commits = [
    'c19b141', '641ebd3', 'dcf20b4', 'cc59458', '507fc7c', 'b2f93ff',
    '34a250b', '969bd73', '6b5122f', 'b5330e5', '0257650', '669c94e',
    '494c064', 'ea1d398', '5847e60', 'f584493', 'd3d6a34'
]

seen = set()
valid_git_levels = []

for c in commits:
    try:
        sols_raw = subprocess.check_output(['git', 'show', f'{c}:levels/solutions.json'], text=True)
        sols = json.loads(sols_raw)
    except:
        sols = {}

    try:
        files = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', c, 'levels'], text=True).splitlines()
    except:
        continue

    for f in files:
        if not f.endswith('.sok'):
            continue
        # extract level number
        # e.g. levels/level_05.sok -> "5" or "05"
        base = os.path.basename(f).replace('.sok', '').replace('level_', '')
        try:
            lvl_num = str(int(base))
        except:
            lvl_num = base

        sol = sols.get(lvl_num, sols.get(f"{int(lvl_num):02d}" if lvl_num.isdigit() else "", ""))
        if not sol:
            continue

        try:
            content = subprocess.check_output(['git', 'show', f'{c}:{f}'], text=True)
        except:
            continue

        lines = [l.rstrip("\r\n") for l in content.splitlines() if not l.startswith(";") and l.strip()]
        if not lines:
            continue
        sig = "\n".join(lines)
        if sig in seen:
            continue
        seen.add(sig)

        ok, p_done = replay_solution(lines, sol)
        if not ok:
            continue

        cand = {
            "source": f"{c}:{f}",
            "lines": lines,
            "w": max(len(l) for l in lines),
            "h": len(lines),
            "pushes": p_done,
            "moves": len(sol),
            "path": sol
        }

        ok_arch, reason = check_candidate_architecture(cand)
        if ok_arch:
            valid_git_levels.append(cand)

print(f"Total valid git levels passing strict architecture: {len(valid_git_levels)}")
by_p = {}
for c in valid_git_levels:
    by_p.setdefault(c["pushes"], []).append(c)

for p in sorted(by_p.keys()):
    print(f"P={p:2d}: {len(by_p[p]):2d} levels")

