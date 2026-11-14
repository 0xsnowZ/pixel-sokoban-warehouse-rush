#!/usr/bin/env python3
import os
import sys
import json
import random
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

# Filter out conflicts with fixtures and endgame
clean = [c for c in clean if all(len(c["top_set"] & x["top_set"])/len(c["top_set"] | x["top_set"]) < 0.70 for x in [p1, p3, p4] + endgame)]

# Build conflict graph among clean candidates
N = len(clean)
print(f"Clean candidates non-conflicting with fixtures & endgame: {N}")

adj = [[] for _ in range(N)]
for i in range(N):
    for j in range(i+1, N):
        sim = len(clean[i]["top_set"] & clean[j]["top_set"]) / len(clean[i]["top_set"] | clean[j]["top_set"])
        if sim >= 0.70:
            adj[i].append(j)
            adj[j].append(i)

degrees = [len(adj[i]) for i in range(N)]
print(f"Max conflict degree: {max(degrees)}, avg: {sum(degrees)/N:.1f}")

# Target distribution
# Slots 1..5: p1 (P=4), 1xP=4, p3 (P=5), p4 (P=5), 1xP=5 -> total 5
# Endgame: 7 levels [21, 22, 23, 23, 27, 30, 32]
# Remaining 63 slots across P=6..16
target_counts = {
    4: 1, 5: 1,
    6: 5, 7: 6, 8: 6, 9: 5, 10: 4,
    11: 12, 12: 5, 13: 8, 14: 6, 15: 5, 16: 1
}
print(f"Target distribution total: {sum(target_counts.values())}")
assert sum(target_counts.values()) == 65  # 65 + 3 fixtures + 7 endgame = 75!

by_p = {}
for i, c in enumerate(clean):
    by_p.setdefault(c["pushes"], []).append(i)

# Greedy selection with degree heuristic or randomized restart
success = False
for trial in range(10000):
    rng = random.Random(trial)
    chosen_indices = set()
    possible = True
    for p in sorted(target_counts.keys()):
        needed = target_counts[p]
        avail = [i for i in by_p.get(p, []) if not (set(adj[i]) & chosen_indices)]
        if len(avail) < needed:
            possible = False
            break
        # Pick needed items from avail that don't conflict with each other
        picked_for_p = []
        # Sort avail by fewest remaining conflicts or shuffle
        rng.shuffle(avail)
        for idx in avail:
            if not (set(adj[idx]) & set(picked_for_p)):
                picked_for_p.append(idx)
                if len(picked_for_p) == needed:
                    break
        if len(picked_for_p) < needed:
            possible = False
            break
        chosen_indices.update(picked_for_p)
    if possible:
        print(f"FOUND VALID ASSIGNMENT on trial {trial}!")
        success = True
        break

if success:
    chosen_cands = [clean[i] for i in chosen_indices]
    print(f"Chosen cands count: {len(chosen_cands)}")
    counts = {}
    for c in chosen_cands:
        counts[c["pushes"]] = counts.get(c["pushes"], 0) + 1
    print("Chosen counts by push:", sorted(counts.items()))

