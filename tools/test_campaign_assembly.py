#!/usr/bin/env python3
import os
import sys
import json
import random
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

# 7 Endgame levels
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

print(f"Loaded {len(endgame)} endgame levels.")

pool_files = [
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
    if not os.path.exists(p):
        continue
    try:
        items = json.load(open(p))
        for c in items:
            raw = "\n".join(c.get("lines", []))
            if raw not in seen:
                seen.add(raw)
                all_cands.append(c)
    except:
        pass

print(f"Total raw candidates loaded: {len(all_cands)}")
clean = []
for c in all_cands:
    ok, res = check_candidate_architecture(c)
    if ok:
        c["top_set"] = set(tuple(x) for x in get_topology_set(c["lines"], c["w"], c["h"]))
        clean.append(c)

print(f"Total clean candidates: {len(clean)}")

# Exclude any clean cand conflicting with endgame or fixtures
pool_early = [c for c in clean if all(len(c["top_set"] & x["top_set"])/len(c["top_set"] | x["top_set"]) < 0.70 for x in [p1, p3, p4] + endgame)]
print(f"Pool early non-conflicting with fixtures & endgame: {len(pool_early)}")

from collections import Counter
counts = Counter(c["pushes"] for c in pool_early)
print("Available pushes in pool_early:", sorted(counts.items()))

# We need 65 levels from pool_early
# Slot 2 (P=4), Slot 5 (P=5), and 63 levels across P=6..15
target_counts = {
    4: 1, 5: 1,
    6: 6, 7: 6, 8: 6, 9: 6, 10: 6,
    11: 8, 12: 5, 13: 8, 14: 6, 15: 6
}
assert sum(target_counts.values()) == 65

found = None
for seed in range(5000):
    rng = random.Random(seed)
    chosen = [p1]

    # Slot 2 (P=4)
    avail4 = [c for c in pool_early if c["pushes"] == 4 and len(c["top_set"] & p1["top_set"])/len(c["top_set"] | p1["top_set"]) < 0.70]
    if not avail4:
        continue
    c4 = rng.choice(avail4)
    chosen.append(c4)

    # Slot 3 (p3), Slot 4 (p4)
    if any(len(p3["top_set"] & c["top_set"])/len(p3["top_set"] | c["top_set"]) >= 0.70 for c in chosen):
        continue
    chosen.append(p3)
    if any(len(p4["top_set"] & c["top_set"])/len(p4["top_set"] | c["top_set"]) >= 0.70 for c in chosen):
        continue
    chosen.append(p4)

    # Slot 5 (P=5)
    avail5 = [c for c in pool_early if c["pushes"] == 5 and all(len(c["top_set"] & x["top_set"])/len(c["top_set"] | x["top_set"]) < 0.70 for x in chosen)]
    if not avail5:
        continue
    chosen.append(rng.choice(avail5))

    tail = []
    success = True
    for p in sorted(target_counts.keys()):
        if p in (4, 5):
            continue
        req = target_counts[p]
        cands_p = [c for c in pool_early if c["pushes"] == p]
        rng.shuffle(cands_p)
        picked_for_p = []
        for c in cands_p:
            if all(len(c["top_set"] & x["top_set"])/len(c["top_set"] | x["top_set"]) < 0.70 for x in chosen + tail + picked_for_p):
                picked_for_p.append(c)
                if len(picked_for_p) == req:
                    break
        if len(picked_for_p) < req:
            success = False
            break
        tail.extend(picked_for_p)

    if success:
        found = chosen + tail + endgame
        print(f"SUCCESS ON SEED {seed}!")
        break

if found:
    print(f"SUCCESS! Full campaign assembled: {len(found)} levels!")
    pushes = [c["pushes"] for c in found]
    print("Pushes:", pushes)
    print("Monotonic:", all(pushes[i] <= pushes[i+1] for i in range(len(pushes)-1)))
    max_sim = 0.0
    worst = None
    for i in range(len(found)):
        for j in range(i+1, len(found)):
            s = len(found[i]["top_set"] & found[j]["top_set"]) / len(found[i]["top_set"] | found[j]["top_set"])
            if s > max_sim:
                max_sim = s
                worst = (i+1, j+1, s)
    print(f"Max pairwise similarity: {max_sim*100:.1f}% between L{worst[0]} and L{worst[1]}")
else:
    print("Not found with this target distribution")
