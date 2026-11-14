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

    existing = []
    seen_sigs = set()
    by_p = {}
    if os.path.exists(out_path):
        try:
            existing = json.load(open(out_path))
            for c in existing:
                sig = "\n".join(c["lines"])
                if sig not in seen_sigs:
                    seen_sigs.add(sig)
                    by_p[c["pushes"]] = by_p.get(c["pushes"], 0) + 1
        except Exception as e:
            print("Error loading:", e)

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

    print(f"Compact variants: {len(compact_variants)}. Existing expert pool: {by_p}")

    random.seed(int(time.time() * 1000) % 100000)
    random.shuffle(compact_variants)

    t0 = time.time()
    time_limit = 45.0

    new_count = 0
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
            for step in range(55):
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

                if step >= 20 and step % 4 == 0:
                    on_goals = len(set(cur_crates).intersection(goal_set))
                    if on_goals <= 1:
                        candidates.append((step, tuple(goals), player, tuple(cur_crates)))

            for step, g_cand, p_cand, c_cand in reversed(candidates):
                res = solve_forward(walls, floor, g_cand, p_cand, c_cand, max_states=45000)
                if res and res["solvable"] and 15 <= res["pushes"] <= 26:
                    p = res["pushes"]
                    m = res["moves"]
                    d = p / m
                    mw = max_consecutive_walk(res["path"])
                    if d >= 0.18 and mw <= 7:
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
                                existing.append(cand)
                                by_p[p] = by_p.get(p, 0) + 1
                                new_count += 1
                                print(f"  + P={p:2d} (now {by_p[p]:2d}) from {vname}: {m}m, d={d:.2f}, mw={mw}")
                                break

    print(f"Finished search. Added {new_count} new candidates. Pool summary: {by_p}")
    with open(out_path, "w") as f:
        json.dump(existing, f, indent=2)

if __name__ == "__main__":
    main()
