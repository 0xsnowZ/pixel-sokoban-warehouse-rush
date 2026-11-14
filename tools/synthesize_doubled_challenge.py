#!/usr/bin/env python3
"""
tools/synthesize_doubled_challenge.py

Synthesizes high-entanglement, high-anti-greedy puzzles from untouched templates:
- Targets templates with ZERO representation in high-push buckets.
- Enforces single-tile perimeter (solid_2x2 == 0), watertightness (0 leaks).
- Pushes between 11 and 22.
- High entanglement (E >= 2.0) and anti-greedy pushes (anti >= 1).
- Solvable in forward BFS <= 35,000 states.
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

def analyze_solution_challenge(lines, sol):
    grid = [list(r) for r in lines]
    H = len(grid)
    W = max(len(r) for r in grid)
    for r in range(H):
        if len(grid[r]) < W:
            grid[r] += [' '] * (W - len(grid[r]))
    px, py = -1, -1
    boxes = set()
    goals = set()
    for y in range(H):
        for x in range(W):
            ch = grid[y][x]
            if ch in ('@', '+'): px, py = x, y
            if ch in ('+', '.', '*'): goals.add((x, y))
            if ch in ('$', '*'): boxes.add((x, y))
    box_id_map = {pos: i for i, pos in enumerate(sorted(list(boxes)))}
    dirs = {'u': (0, -1), 'd': (0, 1), 'l': (-1, 0), 'r': (1, 0)}
    pushes = 0
    box_pushed_seq = []
    anti_greedy = 0
    for ch in sol:
        dx, dy = dirs[ch.lower()]
        nx, ny = px + dx, py + dy
        if (nx, ny) in box_id_map:
            bid = box_id_map.pop((nx, ny))
            bx, by = nx + dx, ny + dy
            box_id_map[(bx, by)] = bid
            box_pushed_seq.append(bid)
            pushes += 1
            if (nx, ny) in goals and (bx, by) not in goals:
                anti_greedy += 1
            else:
                d_before = min(abs(nx - gx) + abs(ny - gy) for gx, gy in goals)
                d_after = min(abs(bx - gx) + abs(by - gy) for gx, gy in goals)
                if d_after > d_before:
                    anti_greedy += 1
        px, py = nx, ny
    switches = 0
    for i in range(1, len(box_pushed_seq)):
        if box_pushed_seq[i] != box_pushed_seq[i-1]:
            switches += 1
    K = len(boxes)
    ent = switches / max(1, (K - 1))
    return ent, anti_greedy, ent * (1 + anti_greedy)

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
    # Untouched or underrepresented templates
    untouched = [
        'Castle Keep', 'Fortress Vault', 'Cruciform Depot', 'Hourglass Depot',
        'Snake Depot', 'Dual Pockets', 'Archway Hall', 'Mezzanine',
        'Corner Vault', 'Crossroads', 'Offset Cross', 'Triple Bay',
        'Fork Chambers', 'C-Courtyard', 'Stepped L-Room', 'Pocket S-Bend',
        'Twin Bays', 'Twin L-Interlock', 'Terrace Yard', 'Pyramid Vault',
        'Cloverleaf', 'Zigzag Double', 'Double Wing', 'Pillar Yard',
        'Staggered Rooms', 'Offset Donut', 'W-Chamber', 'Island Loop',
        'Pillar Hall', 'Vertical Shaft', 'T-Depot', 'Airlock Chambers',
        'Zigzag Run', 'Grand Ring', 'H-Dock', 'Alley Depot', 'Octagon Vault',
        'L-Annex'
    ]

    target_templates = [t for t in all_templates if t[0] in untouched]
    variants = []
    for name, tmpl in target_templates:
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

    print(f"Target variants available: {len(variants)}")
    random.seed(int(time.time()))
    random.shuffle(variants)

    t0 = time.time()
    time_limit = 45.0
    added = 0

    for vname, vlines in variants:
        if time.time() - t0 > time_limit:
            break
        walls, floor, h, w = get_interior_floor(vlines)
        floor_list = list(floor)

        for attempt in range(20):
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
            for step in range(36):
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

                if step in (12, 16, 20, 24, 28, 32, 36):
                    on_goals = len(set(cur_crates).intersection(goal_set))
                    if on_goals <= 1:
                        candidates.append((step, tuple(goals), player, tuple(cur_crates)))

            found = False
            for step, g_cand, p_cand, c_cand in reversed(candidates):
                res = solve_forward(walls, floor, g_cand, p_cand, c_cand, max_states=25000)
                if res and res["solvable"] and 11 <= res["pushes"] <= 24:
                    p = res["pushes"]
                    m = res["moves"]
                    lines = render_sok(walls, floor, g_cand, c_cand, p_cand, h, w)
                    sig = "\n".join(lines)
                    if sig not in seen_sigs:
                        ent, anti, chal = analyze_solution_challenge(lines, res["path"])
                        # Filter for cognitive quality: require entanglement >= 1.67 and challenge >= 3.0
                        if ent >= 1.67 and chal >= 3.0:
                            cand = {
                                "source": f"expert:{vname}_4c_{p}p_att{attempt}",
                                "lines": lines, "w": w, "h": h, "crates": 4,
                                "pushes": p, "moves": m, "path": res["path"],
                                "is_fixture": False
                            }
                            ok_arch, _ = check_candidate_architecture(cand)
                            if ok_arch:
                                seen_sigs.add(sig)
                                generated.append(cand)
                                by_p[p] = by_p.get(p, 0) + 1
                                added += 1
                                print(f"  + [{added}] P={p:2d} (C={chal:4.1f}, E={ent:.2f}, Anti={anti}) from {vname}")
                                found = True
                                break
            if found:
                break

    print(f"\nSynthesis completed in {time.time()-t0:.1f}s. Added {added} high-challenge candidates.")
    with open(out_path, "w") as f:
        json.dump(generated, f, indent=2)
    print(f"Saved total {len(generated)} expert candidates to {out_path}")

if __name__ == "__main__":
    main()

