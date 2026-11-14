#!/usr/bin/env python3
"""
tools/verify_entire_campaign.py

Direct disk verification of all 75 levels in the campaign:
1. Piece counts (crates >= 4, crates == goals).
2. on_goals <= 1.
3. Watertightness (0 exterior leaks).
4. Snug single-tile perimeter (solid_2x2 == 0 on non-fixtures).
5. Exact solution replay (solutions.json solves level_XX.sok).
6. Monotonicity (P_1 <= P_2 <= ... <= P_75).
7. Pairwise Jaccard topology similarity (< 70% on all 2,775 pairs).
8. Pinned fixtures integrity (L1, L3, L4).
"""

import sys
import json
import os

sys.path.append("tools")
from build_authentic_push_campaign import (
    is_watertight, audit_solid_2x2, get_topology_set,
    jaccard_similarity, replay_solution
)

def verify():
    print("=" * 65)
    print("VERIFYING FULL 75-LEVEL MAXIMUM-DIFFICULTY CAMPAIGN")
    print("=" * 65)

    with open("levels/solutions.json") as f:
        solutions = json.load(f)

    assert len(solutions) == 75, f"Expected 75 solutions, got {len(solutions)}"

    levels = []
    pushes = []
    moves = []
    topologies = []

    for idx in range(1, 76):
        sok_path = f"levels/level_{idx:02d}.sok"
        assert os.path.exists(sok_path), f"Missing {sok_path}"
        with open(sok_path) as f:
            lines = [l.rstrip("\r\n") for l in f if not l.startswith(";") and l.strip()]

        raw = "\n".join(lines)
        cr = raw.count("$") + raw.count("*")
        gl = raw.count(".") + raw.count("+") + raw.count("*")
        og = raw.count("*")

        # 1. Piece counts
        assert cr >= 4, f"L{idx:02d} has only {cr} crates!"
        assert cr == gl, f"L{idx:02d} crates ({cr}) != goals ({gl})!"
        assert og <= 1, f"L{idx:02d} has {og} on-goals!"

        # 2. Watertightness
        wt, reason = is_watertight(lines)
        assert wt, f"L{idx:02d} leaked: {reason}"

        # 3. Solid 2x2 walls on non-fixtures
        is_fixture = idx in (1, 3, 4)
        if not is_fixture:
            s2 = audit_solid_2x2(lines)
            assert s2 == 0, f"L{idx:02d} has {s2} solid 2x2 wall blocks!"

        # 4. Replay solution
        sol = solutions[str(idx)]
        ok, p_done = replay_solution(lines, sol)
        assert ok, f"L{idx:02d} solution failed to solve level!"
        pushes.append(p_done)
        moves.append(len(sol))

        # Topology set
        w = max(len(l) for l in lines)
        h = len(lines)
        top = set(tuple(x) for x in get_topology_set(lines, w, h))
        topologies.append(top)
        levels.append({
            "idx": idx,
            "w": w, "h": h,
            "crates": cr,
            "pushes": p_done,
            "moves": len(sol)
        })

    # 5. Monotonicity
    for i in range(len(pushes) - 1):
        assert pushes[i] <= pushes[i+1], f"Monotonicity broken at L{i+1} (P={pushes[i]}) -> L{i+2} (P={pushes[i+1]})"

    # 6. Pairwise Jaccard similarity across all 2,775 pairs
    max_sim = 0.0
    worst_pair = None
    pair_count = 0
    for i in range(75):
        for j in range(i + 1, 75):
            pair_count += 1
            sim = jaccard_similarity(topologies[i], topologies[j])
            if sim > max_sim:
                max_sim = sim
                worst_pair = (i + 1, j + 1)
    assert max_sim < 0.70, f"Similarity violation: L{worst_pair[0]} & L{worst_pair[1]} has {max_sim*100:.1f}% similarity!"

    # 7. Check pinned fixtures
    with open("levels/level_01.sok") as f:
        l1 = f.read().strip()
    assert "#######\n##. .##\n# $ $ #\n# @   #\n# $ $ #\n##. .##\n#######" == l1

    with open("levels/level_03.sok") as f:
        l3 = f.read().strip()
    assert "########\n#     .#\n# $$$$ #\n# ...  #\n#   @###\n########" == l3

    with open("levels/level_04.sok") as f:
        l4 = f.read().strip()
    assert "########\n##  *@##\n# $..$ #\n# # .# #\n#   $  #\n###  ###\n########" == l4

    print("ALL CHECKS PASSED FLAWLESSLY!")
    print(f"Total levels verified: 75")
    print(f"Total pairs verified : {pair_count}")
    print(f"Push ramp            : P={min(pushes)} -> P={max(pushes)}")
    print(f"Total pushes         : {sum(pushes)}")
    print(f"Total moves          : {sum(moves)}")
    print(f"Max pairwise Jaccard : {max_sim*100:.1f}% (between L{worst_pair[0]} and L{worst_pair[1]})")
    print(f"Level 75 capstone    : P={pushes[-1]}, M={moves[-1]} (Ref Level 11)")
    print("=" * 65)

if __name__ == "__main__":
    verify()

