#!/usr/bin/env python3
"""
tools/build_authentic_push_campaign.py

Assembles the authentic Sokoban campaign:
1. Eliminates all monolithic "wall wall on wall" blocks (0 solid 2x2 walls).
2. Enforces single-perimeter walls enclosing architectural rooms like ref_levels/15.jpeg.
3. Strictly scales difficulty monotonically by Push Count across all 75 levels (4 to 39 pushes).
4. Preserves pinned fixtures:
   - Level 1: pinned for test_grid_logic.gd (4 pushes, 9 moves)
   - Level 3: pinned for test_level3_hint_deadlock.gd (5 pushes, 18 moves)
   - Level 4: solid rectangular room for test_non_square_framing.gd (5 pushes, 16 moves)
5. Uses strictly lowercase solution strings in solutions.json for test_hint_performance.gd.
6. Updates levels/*.sok, levels/solutions.json, scripts/level_data.gd, and scripts/save_manager.gd.
"""

import os
import sys
import subprocess
import json
import re
import time
from collections import deque

def clean_exterior_padding(lines):
    H = len(lines)
    W = max(len(l) for l in lines)
    grid = [list(l.ljust(W)) for l in lines]
    
    p = None
    for r in range(H):
        for c in range(W):
            if grid[r][c] in ['@', '+']:
                p = (r, c)
                break
        if p: break
    if not p: return lines
    
    interior_floor = set()
    q = deque([p])
    visited = {p}
    while q:
        curr = q.popleft()
        interior_floor.add(curr)
        for dr, dc in [(-1,0), (1,0), (0,-1), (0,1)]:
            nr, nc = curr[0] + dr, curr[1] + dc
            if 0 <= nr < H and 0 <= nc < W:
                if (nr, nc) not in visited:
                    visited.add((nr, nc))
                    if grid[nr][nc] != '#':
                        q.append((nr, nc))
                        
    perimeter_walls = set()
    for fr, fc in interior_floor:
        for dr in [-1, 0, 1]:
            for dc in [-1, 0, 1]:
                nr, nc = fr + dr, fc + dc
                if 0 <= nr < H and 0 <= nc < W:
                    if grid[nr][nc] == '#':
                        perimeter_walls.add((nr, nc))
                        
    cleaned = []
    for r in range(H):
        row = ""
        for c in range(W):
            if (r, c) in interior_floor:
                row += grid[r][c]
            elif (r, c) in perimeter_walls:
                row += '#'
            else:
                row += ' '
        cleaned.append(row.rstrip())
        
    while cleaned and not cleaned[0].strip(): cleaned.pop(0)
    while cleaned and not cleaned[-1].strip(): cleaned.pop()
    if not cleaned: return lines
    min_col = min(len(r) - len(r.lstrip()) for r in cleaned if r.strip())
    return [r[min_col:] for r in cleaned]

def audit_solid_2x2(lines):
    H = len(lines)
    W = max(len(l) for l in lines)
    grid = [l.ljust(W) for l in lines]
    solid_2x2 = 0
    for r in range(1, H - 2):
        for c in range(1, W - 2):
            if (grid[r][c] == '#' and grid[r+1][c] == '#' and 
                grid[r][c+1] == '#' and grid[r+1][c+1] == '#'):
                solid_2x2 += 1
    return solid_2x2

def is_solid_rectangle(lines):
    H = len(lines)
    W = max(len(l) for l in lines)
    for r, l in enumerate(lines):
        if len(l) != W: return False
        if r == 0 or r == H - 1:
            if any(ch != '#' for ch in l): return False
        else:
            if l[0] != '#' or l[-1] != '#': return False
    return True

def solve_grid(grid_lines, max_states=120000):
    walls = set()
    goals = set()
    crates = []
    player = None
    for r, line in enumerate(grid_lines):
        for c, ch in enumerate(line):
            if ch == '#': walls.add((r, c))
            elif ch == '.': goals.add((r, c))
            elif ch == '$': crates.append((r, c))
            elif ch == '@': player = (r, c)
            elif ch == '*': crates.append((r, c)); goals.add((r, c))
            elif ch == '+': player = (r, c); goals.add((r, c))

    crates = tuple(sorted(crates))
    goals = frozenset(goals)
    if not player or len(crates) != len(goals) or len(crates) == 0:
        return None, "Invalid"

    visited = set([(player, crates)])
    q = deque([(player, crates, 0, 0, '')])
    states = 0
    t0 = time.time()
    while q:
        states += 1
        if states > max_states: return None, "Timeout"
        p, cr, moves, pushes, path = q.popleft()
        if set(cr) == goals:
            return {'moves': moves, 'pushes': pushes, 'path': path.lower(), 'time_s': time.time() - t0}, "OK"
        pr, pc = p
        cr_set = set(cr)
        for dr, dc, name in [(-1, 0, 'U'), (1, 0, 'D'), (0, -1, 'L'), (0, 1, 'R')]:
            nr, nc = pr + dr, pc + dc
            if (nr, nc) in walls: continue
            if (nr, nc) in cr_set:
                nnr, nnc = nr + dr, nc + dc
                if (nnr, nnc) in walls or (nnr, nnc) in cr_set: continue
                # Corner deadlock pruning
                if (nnr, nnc) not in goals:
                    up = (nnr - 1, nnc) in walls
                    dn = (nnr + 1, nnc) in walls
                    lt = (nnr, nnc - 1) in walls
                    rt = (nnr, nnc + 1) in walls
                    if (up and lt) or (up and rt) or (dn and lt) or (dn and rt):
                        continue
                new_cr = list(cr)
                new_cr.remove((nr, nc))
                new_cr.append((nnr, nnc))
                new_cr = tuple(sorted(new_cr))
                if ((nr, nc), new_cr) not in visited:
                    visited.add(((nr, nc), new_cr))
                    q.append(((nr, nc), new_cr, moves + 1, pushes + 1, path + name.lower()))
            else:
                if ((nr, nc), cr) not in visited:
                    visited.add(((nr, nc), cr))
                    q.append(((nr, nc), cr, moves + 1, pushes, path + name.lower()))
    return None, "Unsolvable"

def main():
    print("=" * 60)
    print("BUILDING AUTHENTIC SOKOBAN CAMPAIGN (PUSH-SCALED 4 -> 39)")
    print("=" * 60)

    # 1. Pinned Level 1
    with open('levels/level_01.sok') as f:
        l1_lines = [l.rstrip() for l in f.readlines() if l.strip()]
    sol1, _ = solve_grid(l1_lines)
    item_l1 = {
        'source': 'pinned_01',
        'lines': l1_lines,
        'text': "\n".join(l1_lines),
        'moves': sol1['moves'],
        'pushes': sol1['pushes'],
        'path': sol1['path']
    }

    # 2. Pinned Level 3
    with open('levels/level_03.sok') as f:
        l3_lines = [l.rstrip() for l in f.readlines() if l.strip()]
    sol3, _ = solve_grid(l3_lines)
    item_l3 = {
        'source': 'pinned_03',
        'lines': l3_lines,
        'text': "\n".join(l3_lines),
        'moves': sol3['moves'],
        'pushes': sol3['pushes'],
        'path': sol3['path']
    }

    # 3. Pinned Level 4: solid rectangular room for test_non_square_framing.gd
    with open('levels/archive/level_13.sok') as f:
        l4_lines = [l.rstrip() for l in f.readlines() if l.strip()]
    sol4, _ = solve_grid(l4_lines)
    item_l4 = {
        'source': 'archive_13_solid_rect',
        'lines': l4_lines,
        'text': "\n".join(l4_lines),
        'moves': sol4['moves'],
        'pushes': sol4['pushes'],
        'path': sol4['path']
    }

    # 4. Ref 15 (15.jpeg)
    ref15_lines = [
        " ###### ",
        " #    ##",
        "##.##$ #",
        "#..$   #",
        "#  #$  #",
        "#  @   #",
        "########"
    ]
    sol15, _ = solve_grid(ref15_lines)
    item_ref15 = {
        'source': 'ref_15_jpeg',
        'lines': ref15_lines,
        'text': "\n".join(ref15_lines),
        'moves': sol15['moves'],
        'pushes': sol15['pushes'],
        'path': sol15['path']
    }

    all_cands = []
    seen = {item_l1['text'], item_l3['text'], item_l4['text'], item_ref15['text']}

    def try_add(src, lines):
        cleaned = clean_exterior_padding(lines)
        if audit_solid_2x2(cleaned) > 0:
            return None
        txt = "\n".join(cleaned)
        if txt in seen:
            return None
        sol, msg = solve_grid(cleaned)
        if sol:
            seen.add(txt)
            cand = {
                'source': src,
                'lines': cleaned,
                'text': txt,
                'moves': sol['moves'],
                'pushes': sol['pushes'],
                'path': sol['path']
            }
            all_cands.append(cand)
            return cand
        return None

    # Load from HEAD~1
    print("Scanning HEAD~1 levels...")
    for i in range(1, 76):
        res = subprocess.run(["git", "show", f"HEAD~1:levels/level_{i:02d}.sok"], capture_output=True, text=True)
        if res.returncode == 0:
            lines = [l.rstrip('\r\n') for l in res.stdout.strip('\n').split('\n') if l.strip()]
            try_add(f"head_minus_1_{i:02d}", lines)

    # Load from levels/archive
    print("Scanning levels/archive/...")
    for i in range(1, 51):
        path = f"levels/archive/level_{i:02d}.sok"
        if os.path.exists(path):
            with open(path) as f:
                lines = [l.rstrip('\r\n') for l in f.readlines() if l.strip()]
            try_add(f"archive_{i:02d}", lines)

    print(f"Candidate pool size: {len(all_cands)} unique clean levels")

    # Group pool by pushes
    by_push = {}
    for c in all_cands:
        p = c['pushes']
        by_push.setdefault(p, []).append(c)

    for p in by_push:
        by_push[p].sort(key=lambda x: x['moves'])

    target_counts = {
        4: 2,  # item_l1 + 1 other
        5: 5,  # item_l3 + item_l4 + 3 others
        6: 5,
        7: 5,
        8: 7,
        9: 7,
        10: 5, # item_ref15 + 4 others
        11: 5,
        12: 5,
        13: 5,
        14: 7,
        15: 3,
        18: 1,
        20: 1,
        21: 1,
        22: 2,
        23: 1,
        25: 1,
        27: 1,
        28: 1,
        29: 1,
        30: 1,
        31: 1,
        32: 1,
        39: 1
    }

    assert sum(target_counts.values()) == 75, f"Sum is {sum(target_counts.values())}, expected 75"

    campaign = []

    for push_val in sorted(target_counts.keys()):
        needed = target_counts[push_val]
        selected_for_p = []

        if push_val == 4:
            selected_for_p.append(item_l1)
            remaining_needed = needed - 1
            available = by_push.get(4, [])
            selected_for_p.extend(available[:remaining_needed])
        elif push_val == 5:
            # Slot 3 is item_l3, Slot 4 is item_l4
            selected_for_p.append(item_l3)
            selected_for_p.append(item_l4)
            remaining_needed = needed - 2
            available = by_push.get(5, [])
            selected_for_p.extend(available[:remaining_needed])
        elif push_val == 10:
            selected_for_p.append(item_ref15)
            remaining_needed = needed - 1
            available = by_push.get(10, [])
            selected_for_p.extend(available[:remaining_needed])
        else:
            available = by_push.get(push_val, [])
            assert len(available) >= needed, f"Not enough levels for push={push_val}: need {needed}, have {len(available)}"
            selected_for_p.extend(available[:needed])

        # Preserve pinned slot order:
        if push_val == 4:
            rest = [x for x in selected_for_p if x['source'] != 'pinned_01']
            rest.sort(key=lambda x: x['moves'])
            selected_for_p = [item_l1] + rest
        elif push_val == 5:
            rest = [x for x in selected_for_p if x['source'] not in ['pinned_03', 'archive_13_solid_rect']]
            rest.sort(key=lambda x: x['moves'])
            # We want slot 3 to be item_l3 and slot 4 to be item_l4:
            selected_for_p = [item_l3, item_l4] + rest
        else:
            selected_for_p.sort(key=lambda x: x['moves'])

        campaign.extend(selected_for_p)

    assert len(campaign) == 75, f"Campaign length is {len(campaign)}, expected 75"
    assert campaign[0]['source'] == 'pinned_01', "Slot 1 must be pinned Level 1"
    assert campaign[2]['source'] == 'pinned_03', "Slot 3 must be pinned Level 3"
    assert campaign[3]['source'] == 'archive_13_solid_rect', "Slot 4 must be solid rect for test_non_square_framing.gd"

    # Verify monotonic pushes across all 75 levels:
    for i in range(len(campaign) - 1):
        p_curr = campaign[i]['pushes']
        p_next = campaign[i+1]['pushes']
        assert p_curr <= p_next, f"Push monotonicity violated at L{i+1} ({p_curr}p) -> L{i+2} ({p_next}p)!"

    # Verify 0 solid 2x2 walls across all 75 levels:
    for i, lvl in enumerate(campaign, start=1):
        s2 = audit_solid_2x2(lvl['lines'])
        assert s2 == 0, f"Solid 2x2 wall block found in Level {i:02d}!"

    print("\n" + "=" * 65)
    print("VERIFIED 75-LEVEL CAMPAIGN SUMMARY")
    print("=" * 65)
    print(f"{'Slot':4s} | {'Source':23s} | {'Moves':5s} | {'Pushes':6s} | {'Ratio':6s} | {'Dimensions':10s}")
    print("-" * 65)
    total_moves = 0
    total_pushes = 0
    for slot, lvl in enumerate(campaign, start=1):
        m = lvl['moves']
        p = lvl['pushes']
        total_moves += m
        total_pushes += p
        ratio = p / m * 100 if m > 0 else 0
        h = len(lvl['lines'])
        w = max(len(l) for l in lvl['lines'])
        print(f"L{slot:02d}  | {lvl['source']:23s} | {m:5d} | {p:6d} | {ratio:5.1f}% | {w}x{h}")

    print("-" * 65)
    print(f"Average moves: {total_moves/75:.1f}, Average pushes: {total_pushes/75:.1f}")
    print(f"Push range: {campaign[0]['pushes']} -> {campaign[-1]['pushes']}")

    # Apply changes to disk
    print("\nWriting level files to levels/level_XX.sok...")
    solutions = {}
    optimal_moves = []
    level_data_dict = {}

    for slot, lvl in enumerate(campaign, start=1):
        txt = lvl['text'] + "\n"
        with open(f"levels/level_{slot:02d}.sok", "w") as f:
            f.write(txt)
        solutions[str(slot)] = lvl['path'].lower()
        optimal_moves.append(lvl['moves'])
        level_data_dict[slot] = lvl['text']

    print("Writing levels/solutions.json...")
    with open("levels/solutions.json", "w") as f:
        json.dump(solutions, f, indent=2)

    print("Writing scripts/level_data.gd...")
    ld_lines = [
        "## Embedded fallback data for all 75 Sokoban levels.",
        "## Ensures levels always load on any platform or export package.",
        "",
        "const LEVELS: Dictionary = {"
    ]
    for slot in range(1, 76):
        ld_lines.append(f"\t{slot}: '{level_data_dict[slot]}',")
    ld_lines.append("}")
    ld_lines.append("")
    ld_lines.append("static func get_level_text(level_num: int) -> String:")
    ld_lines.append("\treturn LEVELS.get(level_num, \"\")")
    ld_lines.append("")

    with open("scripts/level_data.gd", "w") as f:
        f.write("\n".join(ld_lines))

    print("Writing scripts/save_manager.gd OPTIMAL_MOVES...")
    with open("scripts/save_manager.gd", "r") as f:
        save_mgr_code = f.read()

    opt_rows = []
    for i in range(0, len(optimal_moves), 10):
        chunk = optimal_moves[i:i+10]
        opt_rows.append("\t" + ", ".join(str(m) for m in chunk) + ("," if i + 10 < len(optimal_moves) else ""))

    repl_block = "# Mathematically verified optimal moves for all 75 levels\nconst OPTIMAL_MOVES: Array[int] = [\n" + "\n".join(opt_rows) + "\n]"
    pattern = r"# Mathematically verified optimal moves for all 75 levels\s+const OPTIMAL_MOVES: Array\[int\] = \[[^\]]+\]"
    new_code = re.sub(pattern, repl_block, save_mgr_code)
    assert new_code != save_mgr_code, "Failed to replace OPTIMAL_MOVES in save_manager.gd!"

    with open("scripts/save_manager.gd", "w") as f:
        f.write(new_code)

    print("\nCAMPAIGN SUCCESSFULLY BUILT AND SYNCHRONIZED!")

if __name__ == '__main__':
    main()
