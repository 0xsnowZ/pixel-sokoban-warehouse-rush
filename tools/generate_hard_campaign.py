import sys
import os
import random
import time
from collections import deque

sys.path.insert(0, 'tools')
from new_level_generator import TEMPLATES, solve_forward, format_grid

# Properly closed version of Pinwheel Cross
PINWHEEL_CLOSED = '''
  #####
  #   #
  #   ###
###     #
#       #
###   ###
  #   #
  #####
'''

# Update TEMPLATES with closed Pinwheel
UPDATED_TEMPLATES = []
for name, tmpl, c_list in TEMPLATES:
    if name == 'Pinwheel Cross':
        UPDATED_TEMPLATES.append((name, PINWHEEL_CLOSED, [3, 4]))
    else:
        UPDATED_TEMPLATES.append((name, tmpl, c_list))

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
            orig_r, orig_c = r - 1, c - 1
            if ch == '#':
                walls.add((orig_r, orig_c))
            elif (r, c) not in ext:
                interior_floor.add((orig_r, orig_c))
    return lines, walls, interior_floor

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

def manhattan(p1, p2):
    return abs(p1[0] - p2[0]) + abs(p1[1] - p2[1])

def parse_and_solve_file(path, name):
    with open(path) as f:
        lines = [l.rstrip() for l in f.read().strip('\n').split('\n')]
    walls, floor, goals, crates, player = set(), set(), set(), [], None
    for r, l in enumerate(lines):
        for c, ch in enumerate(l):
            if ch == '#': walls.add((r, c))
            elif ch == '.': goals.add((r, c)); floor.add((r, c))
            elif ch == '$': crates.append((r, c)); floor.add((r, c))
            elif ch == '*': crates.append((r, c)); goals.add((r, c)); floor.add((r, c))
            elif ch == '@': player = (r, c); floor.add((r, c))
            elif ch == '+': player = (r, c); goals.add((r, c)); floor.add((r, c))
            elif ch == ' ': floor.add((r, c))
    res = solve_forward(walls, floor, goals, player, crates, max_states=45000)
    assert res is not None, f"Failed to solve {path}!"
    assert len(set(crates).intersection(goals)) == 0, f"{path} contains crates on goals!"
    assert player not in goals, f"{path} has player on goal!"
    assert len(crates) >= 4, f"{path} has less than 4 crates!"
    return {
        'name': name,
        'template': name,
        'crates': len(crates),
        'moves': res['moves'],
        'pushes': res['pushes'],
        'states': res['states'],
        'lines': lines
    }

def generate_tiered_candidates():
    print("=" * 60)
    print("STARTING MULTI-TIER HARD CANDIDATE GENERATION")
    print("=" * 60)

    # L01 is Tutorial Quad
    l1 = parse_and_solve_file('levels/level_01.sok', 'Tutorial Quad (4c)')
    print(f"L01 Tutorial Quad: {l1['moves']}m, {l1['pushes']}p, {l1['states']} states")

    tier1 = []  # 6 <= pushes <= 10, moves <= 26
    tier2 = []  # 10 <= pushes <= 13, moves 24-38
    tier3 = []  # 13 <= pushes <= 20+, moves 35-60

    seen_layouts = {'\n'.join(l1['lines'])}

    # Add archive level 2 if valid
    try:
        arc02 = parse_and_solve_file('levels/archive/level_02.sok', 'Archive L02')
        k = '\n'.join(arc02['lines'])
        seen_layouts.add(k)
        tier1.append(arc02)
        print(f"Archive L02: {arc02['pushes']}p, {arc02['moves']}m -> Tier 1")
    except Exception:
        pass

    SELECTED_TEMPLATES = [
        'Stepped L-Room', 'Corner Nook', 'S-Corridor', 'Stepped Depot',
        'Castle Keep', 'T-Depot', 'Airlock Chambers', 'Diamond Depot',
        'Fortress Vault', 'Pocket S-Bend', 'Cruciform Depot', 'Extended L-Bay',
        'Corner Alcove', 'Pillar Yard', 'Pinwheel Cross'
    ]

    SEEDS = [42, 101, 777, 1337, 2026, 8888, 9999, 12345, 54321, 98765, 31415, 27182]

    start_time = time.time()

    for s in SEEDS:
        random.seed(s)
        for tmpl_tuple in UPDATED_TEMPLATES:
            name, tmpl_str, _ = tmpl_tuple
            if name not in SELECTED_TEMPLATES:
                continue

            lines, walls, floor = extract_interior(tmpl_str)
            floor_list = list(floor)

            for num_c in [4, 5]:
                if len(floor_list) < num_c + 7:
                    continue

                for attempt in range(15):
                    seed_tile = random.choice(floor_list)
                    goals = tuple(sorted(sorted(floor_list, key=lambda p: manhattan(p, seed_tile))[:num_c]))
                    goal_set = set(goals)
                    crates = list(goals)
                    empty = [p for p in floor if p not in goal_set]

                    cands = [p for p in empty if any(manhattan(p, c) == 1 for c in crates)]
                    if not cands:
                        continue
                    player = random.choice(cands)

                    gc_r = sum(g[0] for g in goals) / float(num_c)
                    gc_c = sum(g[1] for g in goals) / float(num_c)

                    walk_cands = []

                    for step in range(85):
                        c_set = set(crates)
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
                            pool.sort(key=lambda x: x[3], reverse=True)
                            chosen = pool[0] if random.random() < 0.65 else random.choice(pool[:min(3, len(pool))])

                        p_pos, c_pos, p_next = chosen[:3]
                        crates.remove(c_pos)
                        crates.append(p_pos)
                        player = p_next

                        if len(set(crates).intersection(goal_set)) == 0 and player not in goal_set:
                            cur_reach = get_reachable(player, floor, walls, set(crates))
                            can_push = False
                            for cr in crates:
                                for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                                    p_from = (cr[0] - dr, cr[1] - dc)
                                    p_to = (cr[0] + dr, cr[1] + dc)
                                    if p_from in cur_reach and p_to in floor and p_to not in crates and p_to not in walls:
                                        can_push = True
                                        break
                                if can_push: break

                            if can_push:
                                grid_lines = format_grid(lines, walls, goals, player, crates)
                                k = '\n'.join(grid_lines)
                                if k not in seen_layouts:
                                    walk_cands.append((step, tuple(goals), player, tuple(crates), grid_lines, k))

                    # Evaluate candidate states
                    # Prioritize deeper steps to discover high push counts
                    walk_cands.sort(key=lambda x: x[0], reverse=True)
                    for step, g_cand, p_cand, c_cand, g_lines, k in walk_cands[:3]:
                        if k in seen_layouts:
                            continue
                        res = solve_forward(walls, floor, g_cand, p_cand, c_cand, max_states=28000)
                        if res and res['solvable']:
                            seen_layouts.add(k)
                            puz = {
                                'name': f"{name} ({num_c}c)",
                                'template': name,
                                'crates': num_c,
                                'moves': res['moves'],
                                'pushes': res['pushes'],
                                'states': res['states'],
                                'lines': g_lines,
                                'step': step
                            }
                            p = res['pushes']
                            m = res['moves']

                            if p >= 13 and len(tier3) < 40:
                                tier3.append(puz)
                                print(f"[T3 #{len(tier3)}] {name} ({num_c}c): {p}p, {m}m, {res['states']}st (step {step})")
                            elif 10 <= p <= 13 and len(tier2) < 40:
                                tier2.append(puz)
                                print(f"[T2 #{len(tier2)}] {name} ({num_c}c): {p}p, {m}m, {res['states']}st (step {step})")
                            elif 6 <= p <= 10 and m <= 26 and len(tier1) < 25:
                                tier1.append(puz)
                                print(f"[T1 #{len(tier1)}] {name} ({num_c}c): {p}p, {m}m, {res['states']}st (step {step})")

                    if len(tier1) >= 20 and len(tier2) >= 35 and len(tier3) >= 35:
                        break
                if len(tier1) >= 20 and len(tier2) >= 35 and len(tier3) >= 35:
                    break
            if len(tier1) >= 20 and len(tier2) >= 35 and len(tier3) >= 35:
                break
        if len(tier1) >= 20 and len(tier2) >= 35 and len(tier3) >= 35:
            break

    print(f"\nCompleted pool generation in {time.time() - start_time:.1f}s:")
    print(f"  Tier 1 (Pushes 6-10, Moves <=26) : {len(tier1)}")
    print(f"  Tier 2 (Pushes 10-13, Moves 24-38): {len(tier2)}")
    print(f"  Tier 3 (Pushes 13-18+, Moves 35+): {len(tier3)}")

    return l1, tier1, tier2, tier3

def select_best(pool, target_pushes, target_moves, min_c, max_c, last_tmpl=None):
    best_cand = None
    best_score = float('inf')
    for cand in pool:
        if not (min_c <= cand['crates'] <= max_c):
            continue
        tmpl_penalty = 40.0 if cand['template'] == last_tmpl else 0.0
        p_diff = abs(cand['pushes'] - target_pushes)
        m_diff = abs(cand['moves'] - target_moves)
        score = (p_diff * 4.0) + (m_diff * 1.0) + tmpl_penalty
        if score < best_score:
            best_score = score
            best_cand = cand
    if not best_cand:
        cands_in_range = [c for c in pool if min_c <= c['crates'] <= max_c]
        best_cand = cands_in_range[0] if cands_in_range else pool[0]
    pool.remove(best_cand)
    return best_cand

def assemble_hard_campaign(l1, tier1, tier2, tier3):
    print("\n" + "=" * 60)
    print("ASSEMBLING RIGOROUS 50-LEVEL HARD CAMPAIGN")
    print("=" * 60)

    campaign = [l1]

    # Chapter 0 (Levels 2-15)
    # L02 - L10: strictly from Tier 1 (pushes 6 -> 10)
    # L11: Breather (pushes 8-9)
    # L12 - L15: from Tier 2 (pushes 10 -> 13)
    CH0_SPECS = [
        # (pushes, moves, min_c, max_c, pool)
        (6, 14, 4, 4, tier1),   # L02
        (7, 16, 4, 4, tier1),   # L03
        (8, 17, 4, 4, tier1),   # L04
        (8, 19, 4, 4, tier1),   # L05
        (9, 20, 4, 4, tier1),   # L06
        (9, 22, 4, 4, tier1),   # L07
        (10, 23, 4, 4, tier1),  # L08
        (10, 24, 4, 4, tier1),  # L09
        (10, 26, 4, 4, tier1),  # L10
        (8, 18, 4, 4, tier1),   # L11 (Breather)
        (11, 28, 4, 4, tier2),  # L12
        (11, 29, 4, 4, tier2),  # L13
        (12, 30, 4, 4, tier2),  # L14
        (13, 34, 4, 4, tier2),  # L15 (Cargo Bay Boss)
    ]

    for p_tgt, m_tgt, min_c, max_c, pool in CH0_SPECS:
        lvl_num = len(campaign) + 1
        cand = select_best(pool, p_tgt, m_tgt, min_c, max_c, campaign[-1]['template'])
        campaign.append(cand)
        print(f"Level {lvl_num:02d}: {cand['name']} | {cand['crates']}c | {cand['pushes']}p, {cand['moves']}m | {cand['states']} states")

    # Chapter 1 (Levels 16-35)
    # L16 - L20: Tier 2 (pushes 10-12)
    # L21: Tier 2 (5-crate intro, pushes 11-12)
    # L22: Breather (4c, pushes 9-10)
    # L23 - L30: Tier 2 / early Tier 3 (pushes 12-14)
    # L31: Breather (pushes 10-11)
    # L32 - L35: strictly Tier 3 (pushes 13-15)
    CH1_SPECS = [
        (10, 27, 4, 5, tier2),  # L16
        (11, 28, 4, 5, tier2),  # L17
        (11, 30, 4, 5, tier2),  # L18
        (12, 32, 4, 5, tier2),  # L19
        (12, 34, 4, 5, tier2),  # L20
        (11, 32, 5, 5, tier2),  # L21 (5-crate intro)
        (10, 26, 4, 5, tier2),  # L22 (Breather)
        (12, 33, 4, 5, tier2),  # L23
        (12, 35, 5, 5, tier2),  # L24
        (13, 34, 4, 5, tier2),  # L25
        (13, 36, 5, 5, tier2),  # L26
        (13, 37, 4, 5, tier2),  # L27
        (13, 38, 5, 5, tier2),  # L28
        (13, 38, 4, 5, tier2),  # L29
        (14, 38, 5, 5, tier3),  # L30
        (11, 28, 4, 5, tier2),  # L31 (Breather)
        (13, 36, 4, 5, tier3),  # L32
        (14, 38, 4, 5, tier3),  # L33
        (14, 40, 5, 5, tier3),  # L34
        (15, 42, 4, 5, tier3),  # L35 (Cold Storage Boss)
    ]

    for p_tgt, m_tgt, min_c, max_c, pool in CH1_SPECS:
        lvl_num = len(campaign) + 1
        cand = select_best(pool, p_tgt, m_tgt, min_c, max_c, campaign[-1]['template'])
        campaign.append(cand)
        print(f"Level {lvl_num:02d}: {cand['name']} | {cand['crates']}c | {cand['pushes']}p, {cand['moves']}m | {cand['states']} states")

    # Chapter 2 (Levels 36-50)
    # ALL 15 LEVELS STRICTLY FROM TIER 3!
    # Pushes 13 to 18+, moves 36 to 55+
    CH2_SPECS = [
        (13, 37, 4, 5, tier3),  # L36
        (13, 38, 4, 5, tier3),  # L37
        (14, 39, 4, 5, tier3),  # L38
        (14, 40, 4, 5, tier3),  # L39
        (14, 41, 4, 5, tier3),  # L40
        (12, 35, 4, 5, tier3),  # L41 (Breather)
        (14, 42, 4, 5, tier3),  # L42
        (15, 43, 4, 5, tier3),  # L43
        (15, 44, 4, 5, tier3),  # L44
        (15, 45, 4, 5, tier3),  # L45
        (16, 46, 4, 5, tier3),  # L46
        (16, 48, 4, 5, tier3),  # L47
        (16, 50, 4, 5, tier3),  # L48
        (17, 52, 4, 5, tier3),  # L49
        (18, 55, 4, 5, tier3),  # L50 (Grand Finale Climax Boss)
    ]

    for p_tgt, m_tgt, min_c, max_c, pool in CH2_SPECS:
        lvl_num = len(campaign) + 1
        cand = select_best(pool, p_tgt, m_tgt, min_c, max_c, campaign[-1]['template'])
        campaign.append(cand)
        print(f"Level {lvl_num:02d}: {cand['name']} | {cand['crates']}c | {cand['pushes']}p, {cand['moves']}m | {cand['states']} states")

    return campaign

def write_and_update(campaign):
    print("\n" + "=" * 60)
    print("WRITING LEVEL FILES AND UPDATING SAVE_MANAGER")
    print("=" * 60)

    optimal_moves = []
    for idx, puz in enumerate(campaign):
        lvl_num = idx + 1
        path = f"levels/level_{lvl_num:02d}.sok"
        content = '\n'.join(puz['lines']) + '\n'
        with open(path, 'w') as f:
            f.write(content)
        optimal_moves.append(puz['moves'])

        # Verify no dummy crates
        assert content.count('*') == 0, f"Level {lvl_num} has dummy crates (*)"
        assert content.count('+') == 0, f"Level {lvl_num} has player on goal (+)"
        assert content.count('$') >= 4, f"Level {lvl_num} has fewer than 4 crates"

    print(f"Successfully wrote 50 level files.")
    print("Optimal moves list:")
    print(optimal_moves)

    # Update save_manager.gd
    with open('scripts/save_manager.gd', 'r') as f:
        content = f.read()

    formatted_array = "const OPTIMAL_MOVES: Array[int] = [\n"
    for i in range(0, 50, 10):
        chunk = optimal_moves[i:i+10]
        formatted_array += "\t" + ", ".join(str(m) for m in chunk)
        if i + 10 < 50:
            formatted_array += ",\n"
        else:
            formatted_array += "\n"
    formatted_array += "]"

    import re
    new_content = re.sub(r"const OPTIMAL_MOVES: Array\[int\] = \[[\s\S]*?\]", formatted_array, content)
    with open('scripts/save_manager.gd', 'w') as f:
        f.write(new_content)
    print("Updated scripts/save_manager.gd with exact optimal moves.")

if __name__ == '__main__':
    l1, tier1, tier2, tier3 = generate_tiered_candidates()
    campaign = assemble_hard_campaign(l1, tier1, tier2, tier3)
    write_and_update(campaign)
