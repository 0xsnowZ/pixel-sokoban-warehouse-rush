#!/usr/bin/env python3
import os
import sys
import json
import random
import time
import subprocess

from build_authentic_push_campaign import (
    parse_sok, is_watertight, audit_solid_2x2, get_topology_set,
    jaccard_similarity, replay_solution, check_candidate_architecture
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

# Endgame levels
endgame_specs = [
    ("dcf20b4", 64, 21),
    ("dcf20b4", 66, 22),
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

print(f"Loaded {len(endgame)} endgame fixtures.")

pool_files = [
    "expert_difficulty_pool.json",
    "authentic_diverse_pool.json",
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

# Filter out conflicts with fixtures & endgame
fixed_refs = [p1, p3, p4] + endgame
clean = [c for c in clean if all(len(c["top_set"] & x["top_set"])/len(c["top_set"] | x["top_set"]) < 0.70 for x in fixed_refs)]
print(f"Pool early non-conflicting with fixtures & endgame: {len(clean)}")

# Precompute conflict graph
t0 = time.time()
N = len(clean)
conflicts = [set() for _ in range(N)]
for i in range(N):
    s1 = clean[i]["top_set"]
    for j in range(i+1, N):
        s2 = clean[j]["top_set"]
        if len(s1 & s2) / len(s1 | s2) >= 0.70:
            conflicts[i].add(j)
            conflicts[j].add(i)
print(f"Conflict graph built in {time.time()-t0:.2f}s")

by_p = {}
for i, c in enumerate(clean):
    by_p.setdefault(c["pushes"], []).append(i)

# Target counts: exactly 67
target_counts = {
    4: 1, 5: 1,
    6: 3, 7: 3, 8: 3, 9: 3,
    10: 4, 11: 8, 12: 6, 13: 10, 14: 7, 15: 8,
    16: 1, 17: 1, 19: 4, 23: 4
}
assert sum(target_counts.values()) == 67

order = sorted(target_counts.keys(), key=lambda p: len(by_p.get(p, [])) / target_counts[p])
print("Pick order (MRV):", [(p, len(by_p.get(p, [])), target_counts[p]) for p in order])

found_indices = None
t_search = time.time()
for trial in range(50000):
    rng = random.Random(trial)
    chosen_set = set()
    chosen_list = []
    possible = True
    for p in order:
        req = target_counts[p]
        cands_indices = [idx for idx in by_p.get(p, []) if not (conflicts[idx] & chosen_set)]
        if len(cands_indices) < req:
            possible = False
            break
        rng.shuffle(cands_indices)
        picked = []
        for idx in cands_indices:
            if not (conflicts[idx] & set(picked)):
                picked.append(idx)
                if len(picked) == req:
                    break
        if len(picked) < req:
            possible = False
            break
        chosen_set.update(picked)
        chosen_list.extend(picked)

    if possible:
        print(f"SUCCESS on trial {trial} in {time.time()-t_search:.2f}s!")
        found_indices = chosen_list
        break

if found_indices:
    print("Found valid selection!")
    chosen_cands = [clean[i] for i in found_indices]
    
    # Construct monotonic campaign
    c4 = [c for c in chosen_cands if c["pushes"] == 4]
    c5 = [c for c in chosen_cands if c["pushes"] == 5]
    c_tail = [c for c in chosen_cands if c["pushes"] >= 6]
    
    # Merge with endgame
    all_mid_late = c_tail + endgame
    all_mid_late.sort(key=lambda c: c["pushes"])
    
    campaign = [p1, c4[0], p3, p4, c5[0]] + all_mid_late
    print(f"Total campaign levels: {len(campaign)}")
    pushes = [c["pushes"] for c in campaign]
    print(f"Pushes: {pushes}")
    print("Monotonic:", all(pushes[i] <= pushes[i+1] for i in range(len(pushes)-1)))
    
    # Check max similarity
    max_sim = 0.0
    worst = None
    for i in range(len(campaign)):
        for j in range(i+1, len(campaign)):
            sim = len(campaign[i]["top_set"] & campaign[j]["top_set"]) / len(campaign[i]["top_set"] | campaign[j]["top_set"])
            if sim > max_sim:
                max_sim = sim
                worst = (i+1, j+1, sim)
    print(f"Max pairwise similarity: {max_sim*100:.1f}% (between L{worst[0]} and L{worst[1]})")
else:
    print("Failed to find selection")
