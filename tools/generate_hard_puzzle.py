#!/usr/bin/env python3
"""
tools/generate_hard_puzzle.py
Artisanal, Archetype-Driven Sokoban Level Synthesizer for Pixel Sokoban: Warehouse Rush.
Generates genuine, high-depth, non-random puzzles one by one using spatial blueprints,
directed reachable retrograde search, topological dependency ordering, and deadlock analysis.
"""

import sys
import os
import argparse
import random
import time
from collections import deque
import json

# ==============================================================================
# 1. ARCHITECTURAL BLUEPRINTS WITH FUNCTIONAL ZONES
# ==============================================================================
ARCHETYPES = {
    # Archetype 1: Rotary Orbital Hub
    "rotary": {
        "name": "Rotary Orbital Hub",
        "description": "Corridor loop around central column requiring cyclic crate permutation.",
        "blueprint": """
  #####
###   ###
#   #   #
#       #
#   #   #
###   ###
  #####
""",
        "default_crates": 4
    },

    # Archetype 2: Dual-Chamber Airlock
    "airlock": {
        "name": "Dual-Chamber Airlock",
        "description": "Two distinct rooms connected by a narrow bottleneck with passing niches.",
        "blueprint": """
##### #####
#   ###   #
#         #
#   ###   #
##### #####
""",
        "default_crates": 4
    },

    # Archetype 3: Serpentine Docking Slipway
    "slipway": {
        "name": "Serpentine Docking Slipway",
        "description": "Parallel loading slips with staging pockets requiring reverse packing order.",
        "blueprint": """
  ######
  #    #
###    #
#    # #
#  ### #
#      #
########
""",
        "default_crates": 4
    },

    # Archetype 4: Crossroads Matrix (T-Depot)
    "crossroads": {
        "name": "Crossroads Matrix",
        "description": "Perpendicular intersecting corridors where crates block cross-traffic.",
        "blueprint": """
#########
#       #
###   ###
  #   #
  #   #
  #####
""",
        "default_crates": 4
    },

    # Archetype 5: Compact Micro-Vault (Corner Alcove)
    "micro": {
        "name": "Compact Micro-Vault",
        "description": "Dense, tight geometry with high deadlock density and zero wasted walking.",
        "blueprint": """
  #######
  #     #
###  #  #
#    #  #
#       #
#########
""",
        "default_crates": 4
    },

    # Archetype 6: Corner Cargo Nook
    "nook": {
        "name": "Corner Cargo Nook",
        "description": "Recessed cargo nook with tight perimeter maneuvering lanes.",
        "blueprint": """
  ######
  #    #
###    #
#      #
#    ###
######
""",
        "default_crates": 4
    }
}

# ==============================================================================
# 2. GRID PARSER & INTERIOR FLOOD FILL
# ==============================================================================

def extract_interior(tmpl_str):
    lines = [l.rstrip() for l in tmpl_str.strip('\n').split('\n')]
    H = len(lines)
    W = max(len(l) for l in lines)
    grid = []
    grid.append([' '] * (W + 2))
    for l in lines:
        grid.append(list(l.ljust(W)) + [' '])
        grid[-1].insert(0, ' ')
    grid.append([' '] * (W + 2))

    ext = set()
    q = deque([(0, 0)])
    ext.add((0, 0))
    while q:
        r, c = q.popleft()
        for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nr, nc = r + dr, c + dc
            if 0 <= nr < H + 2 and 0 <= nc < W + 2:
                if (nr, nc) not in ext and grid[nr][nc] != '#':
                    ext.add((nr, nc))
                    q.append((nr, nc))

    interior_floor = set()
    walls = set()
    for r in range(1, H + 1):
        for c in range(1, W + 1):
            ch = grid[r][c]
            pos = (r - 1, c - 1)
            if ch == '#':
                walls.add(pos)
            elif (r, c) not in ext:
                interior_floor.add(pos)

    return lines, walls, interior_floor

def manhattan(p1, p2):
    return abs(p1[0] - p2[0]) + abs(p1[1] - p2[1])

def get_reachable(player, floor, walls, crates_set):
    reachable = set()
    q = deque([player])
    visited = {player}
    while q:
        cur = q.popleft()
        reachable.add(cur)
        for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nb = (cur[0] + dr, cur[1] + dc)
            if nb in floor and nb not in walls and nb not in crates_set and nb not in visited:
                visited.add(nb)
                q.append(nb)
    return reachable

# ==============================================================================
# 3. HIGH-SPEED FORWARD SOLVER & DEADLOCK DETECTOR
# ==============================================================================

def solve_sokoban(walls, floor, goals, player, crates, max_states=25000):
    crates = tuple(sorted(crates))
    goals_set = frozenset(goals)
    visited = set([(player, crates)])
    q = deque([(player, crates, 0, 0, '')])
    states = 0
    start = time.time()
    deadlocks_encountered = 0

    def is_blocked(pos):
        return pos in walls or pos not in floor

    dirs = [
        (-1, 0, 'u'),
        (1, 0, 'd'),
        (0, -1, 'l'),
        (0, 1, 'r')
    ]

    while q:
        states += 1
        if states > max_states:
            return None
        p, cr, moves, pushes, path = q.popleft()
        if set(cr) == goals_set:
            return {
                'solvable': True,
                'moves': moves,
                'pushes': pushes,
                'states': states,
                'deadlocks': deadlocks_encountered,
                'path': path,
                'time_s': time.time() - start
            }
        pr, pc = p
        cr_set = set(cr)
        for dr, dc, ch in dirs:
            nr, nc = pr + dr, pc + dc
            if (nr, nc) in walls or (nr, nc) not in floor:
                continue
            if (nr, nc) in cr_set:
                nnr, nnc = nr + dr, nc + dc
                if (nnr, nnc) in walls or (nnr, nnc) not in floor or (nnr, nnc) in cr_set:
                    continue
                # Corner deadlock pruning
                if (nnr, nnc) not in goals_set:
                    w_up = is_blocked((nnr - 1, nnc))
                    w_dn = is_blocked((nnr + 1, nnc))
                    w_lt = is_blocked((nnr, nnc - 1))
                    w_rt = is_blocked((nnr, nnc + 1))
                    if (w_up and w_lt) or (w_up and w_rt) or (w_dn and w_lt) or (w_dn and w_rt):
                        deadlocks_encountered += 1
                        continue

                # 2x2 deadlock pruning
                is_2x2_dead = False
                for dr2, dc2 in [(0, 0), (-1, 0), (0, -1), (-1, -1)]:
                    r0, c0 = nnr + dr2, nnc + dc2
                    cells = [(r0, c0), (r0 + 1, c0), (r0, c0 + 1), (r0 + 1, c0 + 1)]
                    all_solid = True
                    has_non_goal_crate = False
                    for cell in cells:
                        if is_blocked(cell):
                            continue
                        is_cr = (cell == (nnr, nnc)) or (cell in cr_set and cell != (nr, nc))
                        if is_cr:
                            if cell not in goals_set:
                                has_non_goal_crate = True
                        else:
                            all_solid = False
                            break
                    if all_solid and has_non_goal_crate:
                        is_2x2_dead = True
                        break

                if is_2x2_dead:
                    deadlocks_encountered += 1
                    continue

                new_cr = tuple(sorted((cr_set - {(nr, nc)}) | {(nnr, nnc)}))
                state = ((nr, nc), new_cr)
                if state not in visited:
                    visited.add(state)
                    q.append(((nr, nc), new_cr, moves + 1, pushes + 1, path + ch))
            else:
                state = ((nr, nc), cr)
                if state not in visited:
                    visited.add(state)
                    q.append(((nr, nc), cr, moves + 1, pushes, path + ch))

    return None

def format_grid(lines, walls, goals, player, crates):
    H = len(lines)
    W = max(len(l) for l in lines)
    grid = []
    c_set = set(crates)
    g_set = set(goals)

    for r in range(H):
        row = []
        for c in range(W):
            pos = (r, c)
            if pos in walls:
                row.append('#')
            elif pos == player and pos in g_set:
                row.append('+')
            elif pos == player:
                row.append('@')
            elif pos in c_set and pos in g_set:
                row.append('*')
            elif pos in c_set:
                row.append('$')
            elif pos in g_set:
                row.append('.')
            elif r < len(lines) and c < len(lines[r]) and lines[r][c] != ' ':
                row.append(' ')
            else:
                row.append(' ')
        grid.append(''.join(row).rstrip())
    return grid

# ==============================================================================
# 4. DIRECTED REACHABLE RETROGRADE SYNTHESIZER
# ==============================================================================

def synthesize_archetype_puzzle(archetype_key, num_crates=4, target_moves=(25, 52), target_pushes=(10, 20), max_attempts=80):
    """
    Synthesizes a hard puzzle one by one using reachable retrograde pull walks with snapshot sampling.
    """
    arch = ARCHETYPES.get(archetype_key, ARCHETYPES["airlock"])
    lines, walls, floor = extract_interior(arch["blueprint"])
    floor_list = list(floor)

    if len(floor_list) < num_crates + 5:
        return None

    best_candidate = None
    best_score = -1.0
    seen_layouts = set()

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

        # Retrograde pulls using reachability flood fill
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

            # Disperse crates away from goals
            if len(c_set.intersection(goal_set)) > 0:
                off_pulls = [p for p in pulls if p[1] in goal_set and p[0] not in goal_set]
                chosen = random.choice(off_pulls) if off_pulls else random.choice(pulls)
            else:
                keep_off = [p for p in pulls if p[0] not in goal_set]
                pool = keep_off if keep_off else pulls
                pool.sort(key=lambda x: x[3], reverse=True)
                chosen = pool[0] if random.random() < 0.65 else random.choice(pool[:min(3, len(pool))])

            cur_crates.remove(chosen[1])
            cur_crates.append(chosen[0])
            player = chosen[2]

            # Collect candidate snapshots where no crates on goals
            if len(set(cur_crates).intersection(goal_set)) == 0 and player not in goal_set:
                cur_reach = get_reachable(player, floor, walls, set(cur_crates))
                can_push = False
                for cr in cur_crates:
                    for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                        p_from = (cr[0] - dr, cr[1] - dc)
                        p_to = (cr[0] + dr, cr[1] + dc)
                        if p_from in cur_reach and p_to in floor and p_to not in cur_crates and p_to not in walls:
                            can_push = True
                            break
                    if can_push:
                        break

                if can_push:
                    g_lines = format_grid(lines, walls, goals, player, cur_crates)
                    k = '\n'.join(g_lines)
                    if k not in seen_layouts:
                        seen_layouts.add(k)
                        candidates.append((step, tuple(goals), player, tuple(cur_crates), g_lines, k))

        # Test candidate snapshots from steps >= 6
        for step, g_cand, p_cand, c_cand, g_lines, k in reversed(candidates):
            if step < 6:
                continue
            res = solve_sokoban(walls, floor, g_cand, p_cand, c_cand, max_states=18000)
            if not res or not res["solvable"]:
                continue

            moves = res["moves"]
            pushes = res["pushes"]
            push_ratio = float(pushes) / float(max(moves, 1))

            if push_ratio < 0.30:
                continue

            if moves < target_moves[0]:
                continue

            m_fit = 1.0 - min(abs(moves - (target_moves[0] + target_moves[1]) // 2) / 40.0, 1.0)
            score = (moves * 1.0) + (pushes * 2.5) + (push_ratio * 40.0) + (res["deadlocks"] * 0.4) + (m_fit * 25.0)

            if score > best_score:
                best_score = score
                best_candidate = {
                    "archetype": arch["name"],
                    "archetype_key": archetype_key,
                    "crates": num_crates,
                    "moves": moves,
                    "pushes": pushes,
                    "push_ratio": push_ratio,
                    "path": res["path"],
                    "states": res["states"],
                    "deadlocks": res["deadlocks"],
                    "score": score,
                    "lines": g_lines,
                    "text": k,
                    "goals": g_cand,
                    "crates_list": c_cand,
                    "player": p_cand
                }

                if target_moves[0] <= moves <= target_moves[1] and target_pushes[0] <= pushes <= target_pushes[1]:
                    return best_candidate

    return best_candidate

# ==============================================================================
# 5. LEVEL FILE EXPORT & CAMPAIGN INTEGRATION
# ==============================================================================

def export_level(puz, level_num):
    sok_path = f"levels/level_{level_num:02d}.sok"
    with open(sok_path, "w") as f:
        f.write(puz["text"] + "\n")
    print(f"  [SAVED] {sok_path}")

    # Update solutions.json
    sols_path = "levels/solutions.json"
    with open(sols_path, "r") as f:
        sols = json.load(f)
    sols[str(level_num)] = puz["path"].lower()
    with open(sols_path, "w") as f:
        json.dump(sols, f, indent=2)
    print(f"  [UPDATED] {sols_path} with key '{level_num}' ({len(puz['path'])} moves)")

    # Update scripts/level_data.gd
    with open("scripts/level_data.gd", "r") as f:
        lines = f.readlines()
    escaped = puz["text"].replace("\\", "\\\\").replace("\n", "\\n")
    new_entry = f"\t{level_num}: '{escaped}',\n" if level_num < 75 else f"\t{level_num}: '{escaped}'\n"

    updated_lines = []
    target_prefix = f"\t{level_num}:"
    found = False
    for line in lines:
        if line.startswith(target_prefix):
            updated_lines.append(new_entry)
            found = True
        else:
            updated_lines.append(line)
    if found:
        with open("scripts/level_data.gd", "w") as f:
            f.writelines(updated_lines)
        print(f"  [UPDATED] scripts/level_data.gd embedded entry {level_num}")

    # Update scripts/save_manager.gd optimal moves
    with open("scripts/save_manager.gd", "r") as f:
        save_code = f.read()

    import re
    m = re.search(r"const OPTIMAL_MOVES: Array\[int\] = \[([\s\S]*?)\]", save_code)
    if m:
        vals = [int(v.strip()) for v in m.group(1).replace("\n", ",").split(",") if v.strip().isdigit()]
        if level_num - 1 < len(vals):
            vals[level_num - 1] = puz["moves"]
            formatted = "const OPTIMAL_MOVES: Array[int] = [\n"
            for i in range(0, len(vals), 10):
                formatted += "\t" + ", ".join(str(x) for x in vals[i:i+10]) + (",\n" if i + 10 < len(vals) else "\n")
            formatted += "]"
            save_code = save_code[:m.start()] + formatted + save_code[m.end():]
            with open("scripts/save_manager.gd", "w") as f:
                f.write(save_code)
            print(f"  [UPDATED] scripts/save_manager.gd par index {level_num - 1} -> {puz['moves']}")

def render_preview_image(puz, out_path):
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("  [WARN] PIL not available for image preview")
        return

    tile_sz = 44
    lines = puz["lines"]
    H = len(lines)
    W = max(len(l) for l in lines)
    img_w = W * tile_sz + 40
    img_h = H * tile_sz + 90

    img = Image.new("RGBA", (img_w, img_h), (18, 14, 26, 255))
    draw = ImageDraw.Draw(img)

    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 13)
        font_sub = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 11)
    except:
        font = ImageFont.load_default()
        font_sub = ImageFont.load_default()

    draw.text((20, 12), f"{puz['archetype']} ({puz['crates']} Crates)", font=font, fill=(240, 200, 90))
    draw.text((20, 32), f"Optimal: {puz['moves']} moves • {puz['pushes']} pushes • {puz['push_ratio']*100:.1f}% density", font=font_sub, fill=(200, 215, 240))

    ox = 20
    oy = 60

    try:
        wall_tex = Image.open("assets/wall_cyber_depot.png").convert("RGBA").resize((tile_sz, tile_sz))
        floor1 = Image.open("assets/floor_tile_1.png").convert("RGBA").resize((tile_sz, tile_sz))
        floor2 = Image.open("assets/floor_tile_2.png").convert("RGBA").resize((tile_sz, tile_sz))
        crate_tex = Image.open("assets/crate_normal.png").convert("RGBA").resize((tile_sz, tile_sz))
        goal_tex = Image.open("assets/goal_pad.png").convert("RGBA").resize((tile_sz, tile_sz))
        player_tex = Image.open("assets/player_down.png").convert("RGBA").resize((int(tile_sz*0.85), int(tile_sz*0.85)))
    except:
        wall_tex = floor1 = floor2 = crate_tex = goal_tex = player_tex = None

    for r, l in enumerate(lines):
        for c, ch in enumerate(l):
            tx = ox + c * tile_sz
            ty = oy + r * tile_sz
            if ch == ' ':
                continue
            if floor1:
                ft = floor1 if (r + c) % 2 == 0 else floor2
                img.alpha_composite(ft, (tx, ty))

            if ch == '#':
                if wall_tex: img.alpha_composite(wall_tex, (tx, ty))
                else: draw.rectangle([tx, ty, tx + tile_sz, ty + tile_sz], fill=(50, 40, 70))
            elif ch in ('.', '+', '*'):
                if goal_tex: img.alpha_composite(goal_tex, (tx, ty))
                else: draw.ellipse([tx+8, ty+8, tx+tile_sz-8, ty+tile_sz-8], fill=(0, 200, 100))
            if ch in ('$', '*'):
                if crate_tex: img.alpha_composite(crate_tex, (tx, ty))
                else: draw.rectangle([tx+6, ty+6, tx+tile_sz-6, ty+tile_sz-6], fill=(180, 120, 40))
            if ch in ('@', '+'):
                if player_tex:
                    px = tx + (tile_sz - player_tex.size[0]) // 2
                    py = ty + (tile_sz - player_tex.size[1]) // 2
                    img.alpha_composite(player_tex, (px, py))
                else:
                    draw.ellipse([tx+10, ty+10, tx+tile_sz-10, ty+tile_sz-10], fill=(220, 50, 50))

    img.save(out_path)
    print(f"  [RENDERED] Preview image: {out_path}")

# ==============================================================================
# 6. CLI INTERFACE
# ==============================================================================

def main():
    parser = argparse.ArgumentParser(description="Artisanal Sokoban Level Synthesizer (Pixel Sokoban)")
    parser.add_argument("--archetype", choices=list(ARCHETYPES.keys()) + ["auto"], default="auto",
                        help="Architectural puzzle blueprint to use")
    parser.add_argument("--crates", type=int, choices=[4, 5], default=4,
                        help="Number of crates (4 or 5)")
    parser.add_argument("--difficulty", choices=["medium", "hard", "master"], default="hard",
                        help="Target puzzle difficulty")
    parser.add_argument("--level", type=int, default=None,
                        help="Target level number to replace/create (e.g. 37)")
    parser.add_argument("--preview", action="store_true",
                        help="Render high-res PNG preview")
    parser.add_argument("--test", action="store_true",
                        help="Run automated test suite across all archetypes")

    args = parser.parse_args()

    if args.test:
        print("=" * 60)
        print("RUNNING AUTOMATED ARCHETYPE SYNTHESIS TESTS")
        print("=" * 60)
        successes = 0
        for k in ARCHETYPES.keys():
            print(f"\nTesting archetype '{k}' ({ARCHETYPES[k]['name']})...")
            puz = synthesize_archetype_puzzle(k, 4, target_moves=(24, 45), target_pushes=(9, 18), max_attempts=50)
            if puz:
                print(f"  SUCCESS: {puz['moves']}m, {puz['pushes']}p, ratio: {puz['push_ratio']*100:.1f}%, states: {puz['states']}")
                successes += 1
            else:
                print(f"  FAILED to synthesize '{k}'")
        print(f"\nCompleted: {successes}/{len(ARCHETYPES)} archetypes synthesized successfully.")
        return

    diff_targets = {
        "medium": ((25, 36), (9, 14)),
        "hard": ((32, 50), (11, 18)),
        "master": ((45, 65), (15, 24))
    }
    t_moves, t_pushes = diff_targets[args.difficulty]

    chosen_arch = args.archetype
    if chosen_arch == "auto":
        chosen_arch = random.choice(list(ARCHETYPES.keys()))

    print("=" * 65)
    print(f"SYNTHESIZING BESPOKE PUZZLE: Archetype={chosen_arch.upper()}, Crates={args.crates}, Difficulty={args.difficulty.upper()}")
    print("=" * 65)

    puz = synthesize_archetype_puzzle(chosen_arch, args.crates, target_moves=t_moves, target_pushes=t_pushes, max_attempts=120)
    if not puz:
        puz = synthesize_archetype_puzzle(chosen_arch, args.crates, target_moves=(24, 55), target_pushes=(9, 22), max_attempts=80)

    if not puz:
        print("Could not generate a puzzle matching the exact criteria. Try adjusting difficulty or archetype.")
        return

    print("\n--- SYNTHESIZED LEVEL PREVIEW ---")
    print(puz["text"])
    print("\n--- METRICS DASHBOARD ---")
    print(f"  Archetype       : {puz['archetype']}")
    print(f"  Crates Count    : {puz['crates']} crates (0 dummy, 0 player-on-goal)")
    print(f"  Optimal Moves   : {puz['moves']} moves")
    print(f"  Optimal Pushes  : {puz['pushes']} pushes")
    print(f"  Push Density    : {puz['push_ratio']*100:.1f}% of moves are direct crate pushes")
    print(f"  Deadlock Traps  : {puz['deadlocks']} dangerous irreversible branches")
    print(f"  Search States   : {puz['states']} states explored")
    print(f"  Solution String : {puz['path'][:35]}... ({len(puz['path'])} moves)")

    if args.preview or args.level:
        preview_out = f"/home/snowz/.gemini/antigravity/brain/f5ae7af8-879e-4866-bb7e-de37bc6d1ca9/synthesized_puzzle_preview.png"
        render_preview_image(puz, preview_out)

    if args.level:
        print(f"\nCommitting level to campaign at Level {args.level}...")
        export_level(puz, args.level)
        print("Level committed successfully!")

if __name__ == "__main__":
    main()
