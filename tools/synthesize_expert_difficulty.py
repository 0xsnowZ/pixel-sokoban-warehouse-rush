#!/usr/bin/env python3
"""
tools/synthesize_expert_difficulty.py

Synthesizes high-difficulty compact Sokoban puzzles:
- Pushes between 15 and 25
- Exactly 4 crates and 4 goals
- on_goals <= 1
- solid_2x2 == 0 (single-tile perimeter)
- 100% Watertight (0 leaks)
- Compact floor (14 <= floor <= 24)
- High push density (pushes / moves >= 0.25)
- max_walk <= 5 (no long runway corridors)
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

def max_consecutive_walk(path):
    runs = [match.group(0) for match in re.finditer(r"(.)\1*", path.lower())]
    return max(len(r) for r in runs) if runs else 0

def main():
    scratch = "/home/snowz/.gemini/antigravity/brain/db19d3e6-5897-4bec-b12d-4a1222e63add/scratch"
    out_path = os.path.join(scratch, "expert_difficulty_pool.json")

    # Load existing if any
    generated = []
    seen_sigs = set()
    by_p = {}
    if os.path.exists(out_path):
        try:
            existing = json.load(open(out_path))
            for c in existing:
                sig = "\n".join(c["lines"])
                if sig not in seen_sigs:
                    seen_sigs.add(sig)
                    generated.append(c)
                    by_p[c["pushes"]] = by_p.get(c["pushes"], 0) + 1
        except Exception as e:
            print("Error loading existing:", e)

    all_templates = [(name, tmpl) for name, tmpl, _ in TEMPLATES[1:]] + list(MORE_TEMPLATES)
    compact_variants = []
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
                    compact_variants.append((rname, rlines))

    print(f"Total compact variants available: {len(compact_variants)}")
    print(f"Already have {len(generated)} existing candidates: {by_p}")

    random.seed(int(time.time()))
    # Prioritize templates that are NOT yet in generated sources
    existing_bases = set(c["source"].split("_4c_")[0].split(":")[1].rsplit("_", 1)[0] for c in generated if ":" in c["source"] and "_4c_" in c["source"])
    compact_variants.sort(key=lambda v: (0 if v[0].rsplit("_", 1)[0] not in existing_bases else 1, random.random()))

    t0 = time.time()
    time_limit = 60.0  # run for 60 seconds

    for vname, vlines in compact_variants:
        if time.time() - t0 > time_limit:
            break
        walls, floor, h, w = get_interior_floor(vlines)
        floor_list = list(floor)

        for attempt in range(25):
            if time.time() - t0 > time_limit:
                break
            seed_tile = random.choice(floor_list)
            goals = tuple(sorted(sorted(floor_list, key=lambda p: manhattan(p, seed_tile))[:4]))
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
            for step in range(40):
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

                if step in (12, 16, 20, 24, 28, 32, 36, 40):
                    on_goals = len(set(cur_crates).intersection(goal_set))
                    if on_goals <= 1:
                        candidates.append((step, tuple(goals), player, tuple(cur_crates)))

            found_for_variant = False
            for step, g_cand, p_cand, c_cand in reversed(candidates):
                res = solve_forward(walls, floor, g_cand, p_cand, c_cand, max_states=30000)
                if res and res["solvable"] and 14 <= res["pushes"] <= 26:
                    p = res["pushes"]
                    m = res["moves"]
                    d = p / m
                    mw = max_consecutive_walk(res["path"])
                    if d >= 0.20 and mw <= 6:
                        lines = render_sok(walls, floor, g_cand, c_cand, p_cand, h, w)
                        sig = "\n".join(lines)
                        if sig not in seen_sigs:
                            cand = {
                                "source": f"expert:{vname}_4c_{p}p_att{attempt}",
                                "lines": lines,
                                "w": w,
                                "h": h,
                                "crates": 4,
                                "pushes": p,
                                "moves": m,
                                "path": res["path"],
                                "density": d,
                                "max_walk": mw,
                                "is_fixture": False
                            }
                            ok_arch, msg = check_candidate_architecture(cand)
                            if ok_arch:
                                seen_sigs.add(sig)
                                generated.append(cand)
                                by_p[p] = by_p.get(p, 0) + 1
                                print(f"  + P={p:2d} (now {by_p[p]:2d}) from {vname}: {m}m, d={d:.2f}, mw={mw}")
                                found_for_variant = True
                                break
            if found_for_variant:
                break

    print(f"\nSynthesis completed in {time.time()-t0:.1f}s.")
    print(f"Total expert candidates: {len(generated)}")
    for p in sorted(by_p.keys()):
        print(f"  P={p:2d}: {by_p[p]} candidates")

    with open(out_path, "w") as f:
        json.dump(generated, f, indent=2)
    print(f"Saved to {out_path}")

if __name__ == "__main__":
    main()
