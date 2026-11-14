#!/usr/bin/env python3
"""
tools/assemble_campaign.py

Assembles the maximum-difficulty monotonic Sokoban campaign:
1. Crates >= 4 and crates == goals across 100% of all 75 levels.
2. Watertight outer walls (0 leaks) across 100% of levels.
3. Snug walls hugging the playfield: solid_2x2 == 0 on all non-fixtures, 0 dummy wings/rooms.
4. on_goals <= 1 across all 75 levels.
5. Strictly monotonic push difficulty progression: P1 <= P2 <= ... <= P75.
6. Pairwise Jaccard topology similarity strictly < 70% across all 75 levels.
7. Preserves pinned fixtures:
   - Level 1: for test_grid_logic.gd (4c, 4p, 9m)
   - Level 3: for test_level3_hint_deadlock.gd (4c, 5p, 18m)
   - Level 4: solid 8x7 rectangle for test_non_square_framing.gd (4c, 5p, 26m, 1 on goal)
8. Writes levels/level_XX.sok, levels/solutions.json, scripts/level_data.gd, and scripts/save_manager.gd.
"""

import os
import sys
import json
import random
import time
import re
import subprocess

from build_authentic_push_campaign import (
    parse_sok, is_watertight, audit_solid_2x2, get_topology_set,
    jaccard_similarity, replay_solution, check_candidate_architecture
)

def get_challenge(lines, sol):
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
    return ent * (1 + anti_greedy)

def main():
    print("=" * 65)
    print("ASSEMBLING MAXIMUM-DIFFICULTY MONOTONIC SOKOBAN CAMPAIGN")
    print("=" * 65)

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
        fix["challenge"] = get_challenge(fix["lines"], fix["path"])

    # 8 Endgame levels + 1 Reference Level 11 = 9 Grandmaster Endgame levels
    endgame_specs = [
        ("dcf20b4", 64, 21),
        ("dcf20b4", 66, 22),
        ("0257650", 33, 23),
        ("0257650", 47, 23),
        ("669c94e", 39, 26),
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

    # Reference Level 11 as the peak Grandmaster Finale (Level 75)
    with open("/home/snowz/godot/scratch/level_11.sok") as f:
        ref11_lines = [l.rstrip("\r\n") for l in f if l.strip()]

    ref11_cand = {
        "source": "ref_levels/11.jpeg",
        "lines": ref11_lines,
        "w": max(len(l) for l in ref11_lines),
        "h": len(ref11_lines),
        "pushes": 43,
        "moves": 170,
        "path": "rdrddddlluuludrddrruulruuldldllurrrurrdldllurdrulllldrrurrdddlluuruuullddldrrluuurrddrruldlldddrruuddlluurllluruurrddldlurrurrdllldddrruuddlluuruurrdldllurdlllurdrruuulld",
        "crates": 4,
        "is_fixture": False
    }
    ref11_cand["top_set"] = set(tuple(x) for x in get_topology_set(ref11_lines, ref11_cand["w"], ref11_cand["h"]))
    ref11_cand["challenge"] = get_challenge(ref11_lines, ref11_cand["path"])
    endgame.append(ref11_cand)

    print(f"Loaded {len(endgame)} endgame levels.")

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
        raw = "\n".join(c["lines"])
        cr = raw.count("$") + raw.count("*")
        if cr != 4:
            continue
        ok, res = check_candidate_architecture(c)
        if ok:
            c["top_set"] = set(tuple(x) for x in get_topology_set(c["lines"], c["w"], c["h"]))
            c["challenge"] = get_challenge(c["lines"], c["path"])
            clean.append(c)

    for eg in endgame:
        eg["challenge"] = get_challenge(eg["lines"], eg["path"])

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
    print(f"Precomputed conflict graph for {N} candidates in {time.time()-t0:.2f}s")

    by_p = {}
    for i, c in enumerate(clean):
        by_p.setdefault(c["pushes"], []).append(i)

    # Target counts for maximum difficulty progression (sum = 63 + 3 fixtures + 9 endgame = 75)
    target_counts = {
        4: 1, 5: 1,
        6: 2, 7: 2, 8: 4, 9: 4,
        10: 4, 11: 6, 12: 6, 13: 7, 14: 7, 15: 13,
        16: 1, 17: 3, 19: 2
    }
    assert sum(target_counts.values()) == 63

    order = sorted(target_counts.keys(), key=lambda p: len(by_p.get(p, [])) / target_counts[p])

    for p in by_p:
        by_p[p].sort(key=lambda i: clean[i]["challenge"], reverse=True)

    # Multi-seed search for best starting configuration
    print("Searching seeds for highest-challenge valid starting configuration...")
    best_seed = None
    best_start_score = 0
    best_chosen = None
    for seed in range(1, 1001):
        rng = random.Random(seed)
        chosen_set = set()
        chosen_list = []
        possible = True
        for p in order:
            req = target_counts[p]
            avail = [i for i in by_p.get(p, []) if not (conflicts[i] & chosen_set)]
            rng.shuffle(avail)
            picked = []
            for i in avail:
                if not (conflicts[i] & set(picked)):
                    picked.append(i)
                    if len(picked) == req:
                        break
            if len(picked) < req:
                possible = False
                break
            chosen_set.update(picked)
            chosen_list.extend(picked)
        if possible:
            score = sum(clean[i]["challenge"] for i in chosen_list)
            if score > best_start_score:
                best_start_score = score
                best_seed = seed
                best_chosen = list(chosen_list)

    print(f"Selected Seed {best_seed} with starting challenge = {best_start_score:.2f}")

    # Simulated Annealing / Multi-Swap Challenge Maximizer (1-swap + 2-swap)
    print("Running Cognitive Challenge multi-swap optimizer (1-swap + 2-swap)...")
    curr_chosen = list(best_chosen)
    curr_score = best_start_score
    rng = random.Random(best_seed)
    total_improved_steps = 0

    for step in range(1, 500):
        improved = False
        indices = list(range(len(curr_chosen)))
        rng.shuffle(indices)

        # 1-swap
        for idx in indices:
            curr = curr_chosen[idx]
            curr_p = clean[curr]["pushes"]
            curr_c = clean[curr]["challenge"]
            other_chosen = set(curr_chosen) - {curr}
            cands = [i for i in by_p[curr_p] if i not in other_chosen and clean[i]["challenge"] > curr_c and not (conflicts[i] & other_chosen)]
            if cands:
                cands.sort(key=lambda i: clean[i]["challenge"], reverse=True)
                curr_chosen[idx] = cands[0]
                curr_score += clean[cands[0]]["challenge"] - curr_c
                improved = True
                total_improved_steps += 1
                break

        # 2-swap
        if not improved and step % 2 == 0:
            for idx1 in indices[:20]:
                c1 = curr_chosen[idx1]
                p1_val = clean[c1]["pushes"]
                for idx2 in indices[20:40]:
                    c2 = curr_chosen[idx2]
                    p2_val = clean[c2]["pushes"]
                    other_chosen = set(curr_chosen) - {c1, c2}
                    r1_cands = [i for i in by_p[p1_val] if i not in other_chosen and not (conflicts[i] & other_chosen)]
                    for r1 in r1_cands:
                        gain1 = clean[r1]["challenge"] - clean[c1]["challenge"]
                        r2_cands = [j for j in by_p[p2_val] if j not in other_chosen and j != r1 and r1 not in conflicts[j] and not (conflicts[j] & other_chosen)]
                        for r2 in r2_cands:
                            gain = gain1 + (clean[r2]["challenge"] - clean[c2]["challenge"])
                            if gain > 0.01:
                                curr_chosen[idx1] = r1
                                curr_chosen[idx2] = r2
                                curr_score += gain
                                improved = True
                                total_improved_steps += 1
                                break
                        if improved: break
                    if improved: break
                if improved: break

        if not improved and step > 100:
            break

    print(f"Multi-swap optimization completed with {total_improved_steps} improvements! Total Challenge = {curr_score:.2f}")

    chosen_cands = [clean[i] for i in curr_chosen]

    c4 = [c for c in chosen_cands if c["pushes"] == 4]
    c5 = [c for c in chosen_cands if c["pushes"] == 5]
    c_tail = [c for c in chosen_cands if c["pushes"] >= 6]
    c_tail.sort(key=lambda c: (c["pushes"], c["moves"]))

    campaign = [p1, c4[0], p3, p4, c5[0]] + c_tail + endgame
    assert len(campaign) == 75, f"Campaign length is {len(campaign)}"

    # 1. Monotonicity Audit
    pushes = [c["pushes"] for c in campaign]
    moves = [c["moves"] for c in campaign]
    for i in range(len(campaign) - 1):
        assert campaign[i]["pushes"] <= campaign[i+1]["pushes"], f"Monotonicity error at L{i+1}->L{i+2}"

    # 2. Similarity Audit < 70% across ALL 2775 pairs
    max_sim = 0.0
    worst = None
    for i in range(len(campaign)):
        for j in range(i+1, len(campaign)):
            sim = len(campaign[i]["top_set"] & campaign[j]["top_set"]) / len(campaign[i]["top_set"] | campaign[j]["top_set"])
            if sim > max_sim:
                max_sim = sim
                worst = (i+1, j+1, sim)
    assert max_sim < 0.70, f"Similarity violation: L{worst[0]} & L{worst[1]} has {max_sim*100:.1f}%!"

    # 3. Piece count, Watertight, on_goals <= 1, Replay audit
    for i, c in enumerate(campaign, start=1):
        raw = "\n".join(c["lines"])
        cr = raw.count("$") + raw.count("*")
        gl = raw.count(".") + raw.count("+") + raw.count("*")
        og = raw.count("*")
        assert cr == 4, f"L{i:02d} has {cr} crates (expected exactly 4)!"
        assert cr == gl, f"L{i:02d} crates != goals!"
        assert og <= 1, f"L{i:02d} has {og} on goals!"
        wt, reason = is_watertight(c["lines"])
        assert wt, f"L{i:02d} leaks: {reason}"
        if not c.get("is_fixture", False):
            s2 = audit_solid_2x2(c["lines"])
            assert s2 == 0, f"L{i:02d} has {s2} 2x2 solid blocks!"
        ok, p_done = replay_solution(c["lines"], c["path"])
        assert ok and p_done == c["pushes"], f"L{i:02d} replay failed!"

    c70 = sum(c["challenge"] for c in campaign[:70])
    c50 = sum(c["challenge"] for c in campaign[:50])
    c_tot = sum(c["challenge"] for c in campaign)

    print("\n" + "=" * 65)
    print("ALL 75 LEVELS VERIFIED 100% PERFECTLY!")
    print("=" * 65)
    print(f"Total levels : 75")
    print(f"Pushes       : {pushes}")
    print(f"Moves        : {moves}")
    print(f"Total moves  : {sum(moves)}")
    print(f"L1-70 Challenge: {c70:.2f} (mean {c70/70:.2f}/level)")
    print(f"L1-50 Challenge: {c50:.2f} (mean {c50/50:.2f}/level)")
    print(f"Total Campaign Challenge: {c_tot:.2f}")
    print(f"Max pairwise similarity: {max_sim*100:.1f}% (between L{worst[0]} and L{worst[1]})")

    # Write levels/level_XX.sok
    print("\nWriting levels/level_XX.sok files...")
    for idx, c in enumerate(campaign, start=1):
        path = f"levels/level_{idx:02d}.sok"
        with open(path, "w") as f:
            for l in c["lines"]:
                f.write(l + "\n")

    # Write levels/solutions.json (all lowercase)
    print("Writing levels/solutions.json...")
    sols = {str(idx): c["path"].lower() for idx, c in enumerate(campaign, start=1)}
    with open("levels/solutions.json", "w") as f:
        json.dump(sols, f, indent=2)

    # Update scripts/level_data.gd
    print("Updating scripts/level_data.gd...")
    gd_levels = []
    for idx, c in enumerate(campaign, start=1):
        escaped_lines = '\\n'.join(c["lines"]) + '\\n'
        gd_levels.append(f'\t"{escaped_lines}",')
    levels_block = "\n".join(gd_levels)

    gd_content = f"""extends Node

## Central repository of all campaign level layouts.
## 75 handcrafted, watertight levels with monotonic push progression (P=4 to P=43).

const LEVELS: Array[String] = [
{levels_block}
]

static func get_level_count() -> int:
\treturn LEVELS.size()

static func get_level_data(level_index: int) -> String:
\tif level_index < 0 or level_index >= LEVELS.size():
\t\tpush_error("Level index out of bounds: %d" % level_index)
\t\treturn ""
\treturn LEVELS[level_index]
"""
    with open("scripts/level_data.gd", "w") as f:
        f.write(gd_content)

    # Update scripts/save_manager.gd OPTIMAL_MOVES
    print("Updating scripts/save_manager.gd...")
    with open("scripts/save_manager.gd", "r") as f:
        save_mgr = f.read()

    opt_moves_str = ", ".join(str(m) for m in moves)
    save_mgr_updated = re.sub(
        r"const OPTIMAL_MOVES: Array\[int\] = \[[\s\S]*?\]",
        f"const OPTIMAL_MOVES: Array[int] = [\n\t{opt_moves_str}\n]",
        save_mgr
    )
    with open("scripts/save_manager.gd", "w") as f:
        f.write(save_mgr_updated)

    print("Project level files updated successfully!")

if __name__ == "__main__":
    main()
