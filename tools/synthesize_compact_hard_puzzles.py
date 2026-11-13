#!/usr/bin/env python3
"""
tools/synthesize_compact_hard_puzzles.py

Synthesizes high-difficulty, compact Sokoban puzzles:
- Minimum 4 boxes (crates >= 4)
- 100% Watertight single-tile perimeter ('#')
- solid_2x2 == 0
- High push density: pushes / moves >= 0.35
- Compact maneuvering: max_walk <= 4 (no long empty corridor walks)
- Solvable in forward BFS
"""

import sys
import os
import json
import time
import random
from collections import deque
import re

sys.path.insert(0, "tools")
sys.path.insert(0, "/home/snowz/.gemini/antigravity/brain/db19d3e6-5897-4bec-b12d-4a1222e63add/scratch")

from new_level_generator import TEMPLATES
from generate_all_templates import MORE_TEMPLATES, rot90, get_interior_floor, render_sok, is_watertight, audit_solid_2x2, get_topology_set
from generate_hard_retro_puzzles import manhattan, get_reachable, solve_forward

random.seed(42)

def max_consecutive_walk(path):
    runs = [match.group(0) for match in re.finditer(r"(.)\1*", path.lower())]
    return max(len(r) for r in runs) if runs else 0

def synthesize_compact_retro(vname, vlines, num_crates, min_pushes=11, max_attempts=40):
    walls, floor, h, w = get_interior_floor(vlines)
    floor_list = list(floor)
    if len(floor_list) < num_crates + 5:
        return None

    for attempt in range(max_attempts):
        seed_tile = random.choice(floor_list)
        # Cluster-seed goals: choose nearest floor tiles to seed
        goals = tuple(sorted(sorted(floor_list, key=lambda p: manhattan(p, seed_tile))[:num_crates]))
        goal_set = set(goals)
        cur_crates = list(goals)
        empty = [p for p in floor if p not in goal_set]

        adj_cands = [p for p in empty if any(manhattan(p, c) == 1 for c in cur_crates)]
        if not adj_cands:
            continue
        player = random.choice(adj_cands)

        gc_r = sum(g[0] for g in goals) / float(num_crates)
        gc_c = sum(g[1] for g in goals) / float(num_crates)

        candidates = []

        # Retrograde pulls
        for step in range(60):
            c_set = set(cur_crates)
            reachable = get_reachable(player, floor, walls, c_set)

            pulls = []
            for p_pos in reachable:
                for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    c_pos = (p_pos[0] - dr, p_pos[1] - dc)
                    p_next = (p_pos[0] + dr, p_pos[1] + dc)
                    if c_pos in c_set and p_next in floor and p_next not in c_set and p_next not in walls:
                        new_c_set = (c_set - {c_pos}) | {p_pos}
                        dist_score = sum(abs(cr[0] - gc_r) + abs(cr[1] - gc_c) for cr in new_c_set)
                        pulls.append((p_pos, c_pos, p_next, dist_score))

            if not pulls:
                break

            # Disperse crates away from goals
            if len(c_set.intersection(goal_set)) > 0:
                off_pulls = [p for p in pulls if p[1] in goal_set and p[0] not in goal_set]
                chosen = random.choice(off_pulls) if off_pulls else random.choice(pulls)
            else:
                keep_off = [p for p in pulls if p[0] not in goal_set]
                pool = keep_off if keep_off else pulls
                pool.sort(key=lambda x: -x[3])
                chosen = pool[0] if random.random() < 0.65 else random.choice(pool)

            p_pos, c_pos, p_next, _ = chosen
            cur_crates.remove(c_pos)
            cur_crates.append(p_pos)
            player = p_next

            # Snapshot candidates after step 10
            if step >= 10 and step % 3 == 0:
                candidates.append((step, tuple(goals), player, tuple(cur_crates)))

        for step, g_cand, p_cand, c_cand in reversed(candidates):
            res = solve_forward(walls, floor, g_cand, p_cand, c_cand, max_states=30000)
            if res and res["solvable"] and res["pushes"] >= min_pushes:
                p = res["pushes"]
                m = res["moves"]
                density = p / m
                mw = max_consecutive_walk(res["path"])
                # Strict compact criteria
                if density >= 0.35 and mw <= 4:
                    lines = render_sok(walls, floor, g_cand, c_cand, p_cand, h, w)
                    if is_watertight(lines) and audit_solid_2x2(lines) == 0:
                        return {
                            "source": f"retro_compact:{vname}_{num_crates}c_{p}p_att{attempt}",
                            "lines": lines,
                            "w": w,
                            "h": h,
                            "crates": num_crates,
                            "pushes": p,
                            "moves": m,
                            "path": res["path"],
                            "top": [list(x) for x in get_topology_set(lines, w, h)],
                            "unused": len(floor) - num_crates,
                            "pct": (num_crates / len(floor)) * 100.0,
                            "density": density,
                            "max_walk": mw,
                            "is_fixture": False
                        }
    return None

def main():
    pool_path = "/home/snowz/.gemini/antigravity/brain/db19d3e6-5897-4bec-b12d-4a1222e63add/scratch/proper_watertight_generated.json"
    with open(pool_path) as f:
        pool = json.load(f)

    print(f"Initial pool size: {len(pool)}")

    all_templates = []
    for name, tmpl, _ in TEMPLATES[1:]:
        all_templates.append((name, tmpl))
    for name, tmpl in MORE_TEMPLATES:
        all_templates.append((name, tmpl))

    variants = []
    for name, tmpl in all_templates:
        lines0 = [l.rstrip() for l in tmpl.strip("\n").split("\n")]
        variants.append((f"{name}_0", lines0))
        variants.append((f"{name}_90", rot90(lines0)))
        variants.append((f"{name}_180", rot90(rot90(lines0))))
        variants.append((f"{name}_270", rot90(rot90(rot90(lines0)))))

    # Shuffle variants for diverse coverage
    random.shuffle(variants)

    print(f"Searching across {len(variants)} rotation variants...")
    t0 = time.time()
    added = 0

    seen_signatures = set("\n".join(c["lines"]) for c in pool)

    for min_p in [14, 13, 12, 11]:
        for vname, vlines in variants:
            for num_crates in [4, 5]:
                cand = synthesize_compact_retro(vname, vlines, num_crates, min_pushes=min_p, max_attempts=15)
                if cand:
                    sig = "\n".join(cand["lines"])
                    if sig not in seen_signatures:
                        seen_signatures.add(sig)
                        pool.append(cand)
                        added += 1
                        print(f"  + [{added}] {cand['source']}: {cand['pushes']}p, {cand['moves']}m, d={cand['density']:.2f}, mw={cand['max_walk']}")
                        if added >= 50:
                            break
            if added >= 50:
                break
        if added >= 50:
            break

    print(f"\nAdded {added} high-difficulty compact puzzles in {time.time()-t0:.1f}s. Pool size: {len(pool)}")
    with open(pool_path, "w") as f:
        json.dump(pool, f, indent=2)

if __name__ == "__main__":
    main()

