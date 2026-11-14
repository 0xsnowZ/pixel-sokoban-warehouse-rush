#!/usr/bin/env python3
import os
import sys
import json
import subprocess

from build_authentic_push_campaign import (
    get_topology_set, jaccard_similarity, check_candidate_architecture, replay_solution
)

scratch = "/home/snowz/.gemini/antigravity/brain/db19d3e6-5897-4bec-b12d-4a1222e63add/scratch"

p1 = {
    "source": "pinned:level_01",
    "lines": ["#######", "##. .##", "# $ $ #", "# @   #", "# $ $ #", "##. .##", "#######"],
    "w": 7, "h": 7, "crates": 4, "pushes": 4, "moves": 9, "path": "uddurrudd", "is_fixture": True
}
p3 = {
    "source": "pinned:level_03",
    "lines": ["########", "#     .#", "# $$$$ #", "# ...  #", "#   @###", "########"],
    "w": 8, "h": 6, "crates": 4, "pushes": 5, "moves": 18, "path": "ullluurdurdurdrdru", "is_fixture": True
}
p4 = {
    "source": "pinned:level_04_solid",
    "lines": ["########", "##  *@##", "# $..$ #", "# # .# #", "#   $  #", "###  ###", "########"],
    "w": 8, "h": 7, "crates": 4, "pushes": 5, "moves": 26, "path": "lddlddrurruulrddllllluurur", "is_fixture": True
}
for fix in [p1, p3, p4]:
    fix["top_set"] = set(tuple(x) for x in get_topology_set(fix["lines"], fix["w"], fix["h"]))

endgame_specs = [
    ("dcf20b4", 64, 21),
    ("dcf20b4", 66, 22),
    ("0257650", 33, 23),
    ("0257650", 47, 23),
    ("dcf20b4", 69, 27),
    ("dcf20b4", 72, 30),
    ("dcf20b4", 74, 32),
]
endgame = []
for commit, lvl_num, expected_p in endgame_specs:
    sols = json.loads(subprocess.check_output(["git", "show", f"{commit}:levels/solutions.json"], text=True))
    sol = sols[str(lvl_num)].lower()
    content = subprocess.check_output(["git", "show", f"{commit}:levels/level_{lvl_num:02d}.sok"], text=True)
    lines = [l.rstrip("\r\n") for l in content.splitlines() if not l.startswith(";") and l.strip()]
    ok, p_done = replay_solution(lines, sol)
    assert ok and p_done == expected_p
    c = {
        "source": f"{commit}:levels/level_{lvl_num:02d}.sok",
        "lines": lines,
        "w": max(len(l) for l in lines),
        "h": len(lines),
        "pushes": p_done,
        "moves": len(sol),
        "path": sol,
        "crates": 4,
        "is_fixture": False
    }
    c["top_set"] = set(tuple(x) for x in get_topology_set(lines, c["w"], c["h"]))
    endgame.append(c)

pool_files = [
    "proper_watertight_generated.json",
    "all_valid_ge4.json",
    "all_clean_git_pool.json",
    "pool_with_gen.json",
    "valid_candidates_cache.json",
    "merged_tight_pool.json"
]

all_cands = []
seen = set()
for fname in pool_files:
    p = os.path.join(scratch, fname)
    if not os.path.exists(p): continue
    try:
        items = json.load(open(p))
        for c in items:
            raw = "\n".join(c.get("lines", []))
            if raw not in seen:
                seen.add(raw)
                all_cands.append(c)
    except: pass

clean = []
for c in all_cands:
    ok, res = check_candidate_architecture(c)
    if ok:
        c["top_set"] = set(tuple(x) for x in get_topology_set(c["lines"], c["w"], c["h"]))
        clean.append(c)

clean = [c for c in clean if all(len(c["top_set"] & x["top_set"])/len(c["top_set"] | x["top_set"]) < 0.70 for x in [p1, p3, p4] + endgame)]

N = len(clean)
adj = [set() for _ in range(N)]
for i in range(N):
    for j in range(i+1, N):
        sim = len(clean[i]["top_set"] & clean[j]["top_set"]) / len(clean[i]["top_set"] | clean[j]["top_set"])
        if sim >= 0.70:
            adj[i].add(j)
            adj[j].add(i)

# What are the templates/wall shapes?
# Notice: many synthesized levels share the same wall layout!
wall_signatures = {}
for i, c in enumerate(clean):
    wall_only = tuple(tuple(lines) for lines in c["lines"])
    # wall topology only:
    wall_top = tuple(sorted((y, x) for y in range(c["h"]) for x in range(len(c["lines"][y])) if c["lines"][y][x] == "#"))
    wall_signatures.setdefault(wall_top, []).append(i)

print(f"Total clean candidates: {N}")
print(f"Total distinct wall layouts: {len(wall_signatures)}")

# If two candidates share the same wall layout and goals, their similarity is very high!
# Let's see: how many distinct wall layouts exist per push count?
by_p = {}
for i, c in enumerate(clean):
    by_p.setdefault(c["pushes"], []).append(i)

for p in sorted(by_p.keys()):
    c_indices = by_p[p]
    p_walls = set(tuple(sorted((y, x) for y in range(clean[i]["h"]) for x in range(len(clean[i]["lines"][y])) if clean[i]["lines"][y][x] == "#")) for i in c_indices)
    print(f"P={p:2d}: {len(c_indices):2d} candidates, {len(p_walls):2d} distinct wall layouts")
