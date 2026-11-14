#!/usr/bin/env python3
import os
import sys
import json

from build_authentic_push_campaign import (
    get_topology_set, jaccard_similarity, check_candidate_architecture
)

scratch = "/home/snowz/.gemini/antigravity/brain/db19d3e6-5897-4bec-b12d-4a1222e63add/scratch"
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

clean = []
for c in all_cands:
    ok, res = check_candidate_architecture(c)
    if ok:
        top = get_topology_set(c["lines"], c["w"], c["h"])
        c["top_set"] = set(tuple(x) for x in top)
        clean.append(c)

by_push = {}
for c in clean:
    by_push.setdefault(c["pushes"], []).append(c)

for p in sorted(by_push.keys()):
    cands = by_push[p]
    # Greedy independent set
    indep = []
    for c in cands:
        if all(len(c["top_set"] & x["top_set"])/len(c["top_set"] | x["top_set"]) < 0.70 for x in indep):
            indep.append(c)
    print(f"P={p:2d}: {len(cands):3d} candidates, greedy max independent set = {len(indep):2d}")

