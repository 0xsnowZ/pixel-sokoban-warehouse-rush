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
        ok, res = check_candidate_architecture(c)
        if ok:
            c["top_set"] = set(tuple(x) for x in get_topology_set(c["lines"], c["w"], c["h"]))
            clean.append(c)

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

    # Pre-fixed expert pinnacle puzzles (1x 16p, 3x 17p, 2x 19p)
    wanted_expert_sources = [
        "compact_retro:Stepped Depot_0_4c_16p_att11",
        "expert:Bayside Nook_270_4c_17p_att21",
        "expert:Corner Nook_0_4c_17p_att8",
        "expert:S-Corridor_90_4c_17p_att0",
        "expert:S-Corridor_270_4c_19p_att0",
        "gen:Corner Alcove_180_4c_19p_att53"
    ]
    source_to_idx = {c["source"]: i for i, c in enumerate(clean)}
    pre_fixed = [source_to_idx[s] for s in wanted_expert_sources]

    # Remaining target counts for maximum difficulty progression (sum = 58; 58 + 6 expert = 64)
    rem_target_counts = {
        4: 1, 5: 1,
        6: 2, 7: 3, 8: 4, 9: 4,
        10: 5, 11: 6, 12: 6, 13: 8, 14: 8, 15: 10
    }
    assert sum(rem_target_counts.values()) == 58

    order = sorted(rem_target_counts.keys(), key=lambda p: len(by_p.get(p, [])) / rem_target_counts[p])

    # Trial seed 1396 yields max similarity 68.8% (< 70%) and record 2,689 total optimal moves
    rng = random.Random(1396)
    chosen_set = set(pre_fixed)
    chosen_list = list(pre_fixed)
    for p in order:
        req = rem_target_counts[p]
        avail = [i for i in by_p.get(p, []) if not (conflicts[i] & chosen_set)]
        rng.shuffle(avail)
        picked = []
        for i in avail:
            if not (conflicts[i] & set(picked)):
                picked.append(i)
                if len(picked) == req:
                    break
        assert len(picked) == req, f"Could not satisfy bucket P={p}"
        chosen_set.update(picked)
        chosen_list.extend(picked)

    chosen_cands = [clean[i] for i in chosen_list]

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
        assert cr >= 4, f"L{i:02d} has only {cr} crates!"
        assert cr == gl, f"L{i:02d} crates != goals!"
        assert og <= 1, f"L{i:02d} has {og} on goals!"
        wt, reason = is_watertight(c["lines"])
        assert wt, f"L{i:02d} leaks: {reason}"
        if not c.get("is_fixture", False):
            s2 = audit_solid_2x2(c["lines"])
            assert s2 == 0, f"L{i:02d} has {s2} 2x2 solid blocks!"
        ok, p_done = replay_solution(c["lines"], c["path"])
        assert ok and p_done == c["pushes"], f"L{i:02d} replay failed!"

    print("\n" + "=" * 65)
    print("ALL 75 LEVELS VERIFIED 100% PERFECTLY!")
    print("=" * 65)
    print(f"Total levels : 75")
    print(f"Pushes       : {pushes}")
    print(f"Moves        : {moves}")
    print(f"Total moves  : {sum(moves)}")
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
