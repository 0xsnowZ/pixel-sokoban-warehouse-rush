#!/usr/bin/env python3
"""
tools/synthesize_high_challenge_pool.py

Synthesizes high-challenge, high-entanglement candidates across all 41 compact templates:
- 4 rotations per template (164 variants)
- 4 crates, 4 goals, on_goals <= 1
- Single-tile perimeter (solid_2x2 == 0), watertight (0 leaks)
- High cognitive challenge: C = E * (1 + S_anti)
- Compact floor (14 <= floor <= 24)
- Solvable in forward BFS <= 40,000 states
"""

import sys
import os
import json
import time
import random
import re

sys.path.insert(0, "tools")
sys.path.insert(0, "/home/snowz/.gemini/antigravity/brain/db19d3e6-5897-4bec-b12d-4a1222e63add/scratch")

from new_level_generator import TEMPLATES
from generate_all_templates import MORE_TEMPLATES, rot90, get_interior_floor, render_sok, is_watertight, audit_solid_2x2
from generate_hard_retro_puzzles import manhattan, get_reachable, solve_forward
from build_authentic_push_campaign import check_candidate_architecture
from synthesize_doubled_challenge import analyze_solution_challenge

def max_consecutive_walk(path):
    runs = [match.group(0) for match in re.finditer(r"(.)\1*", path.lower())]
    return max(len(r) for r in runs) if runs else 0

def main():
    scratch = "/home/snowz/.gemini/antigravity/brain/db19d3e6-5897-4bec-b12d-4a1222e63add/scratch"
    out_path = os.path.join(scratch, "expert_difficulty_pool.json")

    generated = []
    seen_sigs = set()
    by_p = {}
    if os.path.exists(out_path):
        try:
            for c in json.load(open(out_path)):
                sig = "\n".join(c["lines"])
                if sig not in seen_sigs:
                    seen_sigs.add(sig)
                    generated.append(c)
                    by_p[c["pushes"]] = by_p.get(c["pushes"], 0) + 1
        except Exception as e:
            print("Error loading:", e)

    print(f"Loaded {len(generated)} existing candidates: {by_p}")

    all_templates = [(name, tmpl) for name, tmpl, _ in TEMPLATES[1:]] + list(MORE_TEMPLATES)
    variants = []
    for name, tmpl in all_templates:
        lines0 = [l.rstrip() for l in tmpl.strip("\n").split("\n")]
        _, fl, _, _ = get_interior_floor(lines0)
        if 14 <= len(fl) <= 24:
            for rname, rlines in [
                (f"{name}_0", lines0),
                (f"{name}_90", rot90(lines0)),
                (f"{name}_180", rot90(rot90(lines0))),
                (f"{name}_270", rot90(rot90(rot90(lines0))))
            ]:
                if audit_solid_2x2(rlines) == 0 and is_watertight(rlines):
                    variants.append((rname, rlines))

    print(f"Total valid compact variants: {len(variants)}")

    # Prioritize variants from templates with zero or low representation
    existing_bases = set(c["source"].split("_4c_")[0].split(":")[1].rsplit("_", 1)[0] for c in generated if ":" in c["source"] and "_4c_" in c["source"])
    variants.sort(key=lambda v: (0 if v[0].rsplit("_", 1)[0] not in existing_bases else 1, random.random()))

    random.seed(int(time.time()))
    t0 = time.time()
    time_limit = 90.0  # 90 seconds synthesis budget
    added = 0

    for vname, vlines in variants:
        if time.time() - t0 > time_limit:
            break
        walls, floor, h, w = get_interior_floor(vlines)
        floor_list = list(floor)

        # Identify non-corner tiles for goal seeding
        non_corner_floor = []
        for r, c in floor_list:
            wall_neighbors = sum(1 for dr, dc in [(-1,0),(1,0),(0,-1),(0,1)] if (r+dr, c+dc) in walls or (r+dr, c+dc) not in floor)
            if wall_neighbors < 2:  # Not a corner or narrow dead-end
                non_corner_floor.append((r, c))
        if len(non_corner_floor) < 4:
            non_corner_floor = floor_list

        for attempt in range(40):
            if time.time() - t0 > time_limit:
                break
            seed_tile = random.choice(non_corner_floor)
            if random.random() < 0.60:
                goals = tuple(sorted(sorted(floor_list, key=lambda p: manhattan(p, seed_tile))[:4]))
            else:
                goals = tuple(sorted(random.sample(non_corner_floor, 4)))
            goal_set = set(goals)
            cur_crates = list(goals)
            empty = [p for p in floor if p not in goal_set]
            adj_cands = [p for p in empty if any(manhattan(p, c) == 1 for c in cur_crates)]
            if not adj_cands:
                continue
            player = random.choice(adj_cands)
            gc_r = sum(g[0] for g in goals) / 4.0
            gc_c = sum(g[1] for g in goals) / 4.0

            candidates = []
            for step in range(50):
                c_set = set(cur_crates)
                reachable = get_reachable(player, floor, walls, c_set)
                pulls = []
                for p_pos in reachable:
                    for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                        c_pos = (p_pos[0] - dr, p_pos[1] - dc)
                        p_next = (p_pos[0] + dr, p_pos[1] + dc)
                        if c_pos in c_set and p_next in floor and p_next not in c_set and p_next not in walls:
                            dist = sum(abs(cr[0] - gc_r) + abs(cr[1] - gc_c) for cr in ((c_set - {c_pos}) | {p_pos}))
                            pulls.append((p_pos, c_pos, p_next, dist))
                if not pulls:
                    break

                if len(c_set.intersection(goal_set)) > 0:
                    off_pulls = [p for p in pulls if p[1] in goal_set and p[0] not in goal_set]
                    chosen = random.choice(off_pulls) if off_pulls else random.choice(pulls)
                else:
                    keep_off = [p for p in pulls if p[0] not in goal_set]
                    pool = keep_off if keep_off else pulls
                    pool.sort(key=lambda x: -x[3])
                    chosen = pool[0] if random.random() < 0.70 else random.choice(pool)

                p_pos, c_pos, p_next, _ = chosen
                cur_crates.remove(c_pos)
                cur_crates.append(p_pos)
                player = p_next

                if step in (16, 20, 24, 28, 32, 36, 40, 44, 48):
                    on_goals = len(set(cur_crates).intersection(goal_set))
                    if on_goals <= 1:
                        candidates.append((step, tuple(goals), player, tuple(cur_crates)))

            found = False
            for step, g_cand, p_cand, c_cand in reversed(candidates):
                res = solve_forward(walls, floor, g_cand, p_cand, c_cand, max_states=35000)
                if res and res["solvable"] and 8 <= res["pushes"] <= 26:
                    p = res["pushes"]
                    m = res["moves"]
                    d = p / m
                    mw = max_consecutive_walk(res["path"])
                    if d >= 0.20 and mw <= 6:
                        lines = render_sok(walls, floor, g_cand, c_cand, p_cand, h, w)
                        sig = "\n".join(lines)
                        if sig not in seen_sigs:
                            ent, anti, chal = analyze_solution_challenge(lines, res["path"])
                            min_c = 2.67 if p < 11 else (4.00 if p < 15 else 5.00)
                            if chal >= min_c:
                                cand = {
                                    "source": f"expert:{vname}_4c_{p}p_att{attempt}",
                                    "lines": lines, "w": w, "h": h, "crates": 4,
                                    "pushes": p, "moves": m, "path": res["path"],
                                    "density": d, "max_walk": mw, "challenge": chal,
                                    "states": res["states"], "is_fixture": False
                                }
                                ok_arch, _ = check_candidate_architecture(cand)
                                if ok_arch:
                                    seen_sigs.add(sig)
                                    generated.append(cand)
                                    by_p[p] = by_p.get(p, 0) + 1
                                    added += 1
                                    print(f"  + [{added:2d}] P={p:2d} (C={chal:5.2f}, E={ent:.2f}, Anti={anti}, states={res['states']}) from {vname}")
                                    found = True
                                    break
            if found:
                break

    print(f"\nSynthesis completed in {time.time()-t0:.1f}s. Added {added} high-challenge candidates.")
    with open(out_path, "w") as f:
        json.dump(generated, f, indent=2)
    print(f"Saved total {len(generated)} expert candidates to {out_path}")
    print("New push breakdown:", by_p)

if __name__ == "__main__":
    main()

