import sys
import os
import random
import time
from collections import deque

sys.path.insert(0, 'tools')
from new_level_generator import TEMPLATES, solve_forward, format_grid

def parse_and_solve(lines, name):
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
    assert res is not None, f"Failed to solve {name}!"
    assert len(set(crates).intersection(goals)) == 0, f"{name} contains crates on goals!"
    assert player not in goals, f"{name} has player on goal!"
    assert len(crates) >= 4, f"{name} has less than 4 crates!"
    return {
        'name': name,
        'template': name,
        'crates': len(crates),
        'moves': res['moves'],
        'pushes': res['pushes'],
        'states': res['states'],
        'lines': lines
    }

# L1: Handcrafted Tutorial Quad with crate at (2, 2) directly above player (2, 3)
with open('levels/level_01.sok') as f:
    l1_lines = [l.rstrip() for l in f.read().strip('\n').split('\n')]
l1_quad = parse_and_solve(l1_lines, 'Tutorial Quad (4c)')

with open('levels/archive/level_02.sok') as f:
    arch_02_lines = [l.rstrip() for l in f.read().strip('\n').split('\n')]
arch_02 = parse_and_solve(arch_02_lines, 'Pinwheel Cross (4c)')

seen_layouts = set()
for p in [l1_quad, arch_02]:
    seen_layouts.add('\n'.join(p['lines']))

early_pool = [l1_quad, arch_02]
mid_pool = []
high_pool = []

print("Generating high difficulty candidate pool across all templates...")
start_time = time.time()

SEEDS = [42, 101, 777, 1337, 2026, 8888, 9999, 12345, 54321, 98765]

for s in SEEDS:
    random.seed(s)
    for name, tmpl, _ in TEMPLATES:
        lines = [l.rstrip() for l in tmpl.strip('\n').split('\n')]
        height = len(lines)
        walls = set()
        floor = set()
        for r in range(height):
            for col in range(len(lines[r])):
                ch = lines[r][col]
                if ch == '#': walls.add((r, col))
                elif ch in [' ', '.']: floor.add((r, col))

        # 4, 5, and 6 crates
        for c in [4, 5, 6]:
            if len(floor) < c + 7: continue

            for attempt in range(40):
                goals = tuple(sorted(random.sample(list(floor), c)))
                crates = list(goals)
                empty_floor = [p for p in floor if p not in crates]
                if not empty_floor: continue
                player = random.choice(empty_floor)

                # Macro pull with reachable area exploration
                for step in range(130):
                    crates_set = set(crates)
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

                    all_pulls = []
                    for p_pos in reachable:
                        for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                            c_pos = (p_pos[0] - dr, p_pos[1] - dc)
                            p_next = (p_pos[0] + dr, p_pos[1] + dc)
                            if c_pos in crates_set and p_next in floor and p_next not in crates_set:
                                all_pulls.append((p_pos, c_pos, p_next))

                    if not all_pulls: break

                    goal_pulls = [p for p in all_pulls if p[1] in goals and p[0] not in goals]
                    off_goal_pulls = [p for p in all_pulls if p[0] not in goals]

                    if goal_pulls:
                        p_pos, c_pos, p_next = random.choice(goal_pulls)
                    elif off_goal_pulls:
                        p_pos, c_pos, p_next = random.choice(off_goal_pulls)
                    else:
                        p_pos, c_pos, p_next = random.choice(all_pulls)

                    crates.remove(c_pos)
                    crates.append(p_pos)
                    player = p_next

                    if len(set(crates).intersection(set(goals))) == 0 and player not in goals:
                        grid_lines = format_grid(lines, walls, goals, player, crates)
                        k = '\n'.join(grid_lines)
                        if k in seen_layouts: continue
                        res = solve_forward(walls, floor, goals, player, crates, max_states=35000)
                        if res and res['solvable']:
                            seen_layouts.add(k)
                            puz = {
                                'name': f"{name} ({c}c)",
                                'template': name,
                                'crates': c,
                                'moves': res['moves'],
                                'pushes': res['pushes'],
                                'states': res['states'],
                                'lines': grid_lines
                            }
                            m = res['moves']
                            if 9 <= m <= 19 and c == 4:
                                early_pool.append(puz)
                            if 16 <= m <= 26 and c in [4, 5]:
                                mid_pool.append(puz)
                            if m >= 20 and c in [4, 5, 6]:
                                high_pool.append(puz)
                            break

print(f"Generated pools in {time.time() - start_time:.1f}s:")
print(f"  Early pool (4c, 9-19m)  : {len(early_pool)}")
print(f"  Mid pool   (4-5c, 16-26m) : {len(mid_pool)}")
print(f"  High pool  (4-6c, 20-38m) : {len(high_pool)}")

# Chapter Targets with High Difficulty curve:
# Chapter 0 (Cargo Bay): 4 crates, 9 to 18m
CH0_SPECS = [
    (9, 4, 4),   # L01 (Tutorial)
    (11, 4, 4),  # L02
    (12, 4, 4),  # L03
    (12, 4, 4),  # L04 (Pinwheel Cross arch_02)
    (13, 4, 4),  # L05
    (13, 4, 4),  # L06
    (14, 4, 4),  # L07
    (15, 4, 4),  # L08
    (15, 4, 4),  # L09
    (16, 4, 4),  # L10
    (13, 4, 4),  # L11 (Breather)
    (16, 4, 4),  # L12
    (17, 4, 4),  # L13
    (17, 4, 4),  # L14
    (18, 4, 4)   # L15 (Cargo Bay Boss)
]

# Chapter 1 (Cold Storage): 4 and 5 crates, 17 to 26m
CH1_SPECS = [
    (17, 4, 5),  # L16
    (18, 4, 5),  # L17
    (18, 4, 5),  # L18
    (19, 4, 5),  # L19
    (20, 4, 5),  # L20
    (20, 5, 5),  # L21 (5c intro)
    (17, 4, 5),  # L22 (Breather)
    (21, 4, 5),  # L23
    (21, 5, 5),  # L24
    (22, 4, 5),  # L25
    (22, 5, 5),  # L26
    (23, 5, 5),  # L27
    (23, 4, 5),  # L28
    (24, 5, 5),  # L29
    (24, 5, 5),  # L30
    (19, 4, 5),  # L31 (Breather)
    (25, 5, 5),  # L32
    (25, 5, 5),  # L33
    (26, 5, 5),  # L34
    (26, 5, 5)   # L35 (Cold Storage Boss)
]

# Chapter 2 (Cyber Depot): 5 and 6 crates, 24 to 38m
CH2_SPECS = [
    (24, 4, 5),  # L36
    (25, 5, 6),  # L37
    (26, 5, 6),  # L38
    (27, 5, 6),  # L39
    (28, 5, 6),  # L40
    (23, 4, 5),  # L41 (Breather)
    (28, 5, 6),  # L42
    (29, 5, 6),  # L43
    (30, 5, 6),  # L44
    (31, 5, 6),  # L45
    (32, 5, 6),  # L46
    (33, 5, 6),  # L47
    (34, 5, 6),  # L48
    (35, 5, 6),  # L49
    (36, 5, 6)   # L50 (Grand Finale Climax Boss)
]

used_layouts = set()

def pick_best_candidate(pool, tgt_moves, min_c, max_c, disfavor_tmpl=None):
    best_item = None
    best_score = 999999
    for p in pool:
        k = '\n'.join(p['lines'])
        if k in used_layouts: continue
        if not (min_c <= p['crates'] <= max_c): continue
        diff = abs(p['moves'] - tgt_moves)
        score = diff * 10
        if disfavor_tmpl and p['template'] == disfavor_tmpl:
            score += 25
        if score < best_score:
            best_score = score
            best_item = p
            if diff == 0 and (not disfavor_tmpl or p['template'] != disfavor_tmpl):
                break
    # Fallback to any crate count if strictly constrained
    if best_item is None:
        for p in pool:
            k = '\n'.join(p['lines'])
            if k in used_layouts: continue
            diff = abs(p['moves'] - tgt_moves)
            score = diff * 10
            if score < best_score:
                best_score = score
                best_item = p
    assert best_item is not None, f"Failed to pick candidate for {tgt_moves}m ({min_c}-{max_c}c)!"
    used_layouts.add('\n'.join(best_item['lines']))
    return best_item

campaign = []

# --- CHAPTER 0 ---
campaign.append(l1_quad)
used_layouts.add('\n'.join(l1_quad['lines']))

for lvl in range(2, 16):
    if lvl == 4:
        campaign.append(arch_02)
        used_layouts.add('\n'.join(arch_02['lines']))
        continue
    tgt_m, min_c, max_c = CH0_SPECS[lvl - 1]
    prev_tmpl = campaign[-1]['template']
    p = pick_best_candidate(early_pool, tgt_m, min_c, max_c, disfavor_tmpl=prev_tmpl)
    campaign.append(p)

# --- CHAPTER 1 ---
for lvl in range(16, 36):
    tgt_m, min_c, max_c = CH1_SPECS[lvl - 16]
    prev_tmpl = campaign[-1]['template']
    p = pick_best_candidate(mid_pool, tgt_m, min_c, max_c, disfavor_tmpl=prev_tmpl)
    campaign.append(p)

# --- CHAPTER 2 ---
for lvl in range(36, 51):
    tgt_m, min_c, max_c = CH2_SPECS[lvl - 36]
    prev_tmpl = campaign[-1]['template']
    p = pick_best_candidate(high_pool, tgt_m, min_c, max_c, disfavor_tmpl=prev_tmpl)
    campaign.append(p)

print(f"\nFinal High-Difficulty Campaign assembled: {len(campaign)} levels!")

campaign_moves = []
crate_summary = {4: 0, 5: 0, 6: 0}
for i, p in enumerate(campaign):
    lvl = i + 1
    content = '\n'.join(p['lines'])
    dollar_cnt = content.count('$')
    star_cnt = content.count('*')
    dot_cnt = content.count('.')
    plus_cnt = content.count('+')
    at_cnt = content.count('@')
    assert star_cnt == 0, f"L{lvl} has * crates!"
    assert plus_cnt == 0, f"L{lvl} has + player on goal!"
    assert at_cnt == 1, f"L{lvl} has {at_cnt} players!"
    assert dollar_cnt >= 4, f"L{lvl} has {dollar_cnt} crates (< 4)!"
    assert dot_cnt == dollar_cnt, f"L{lvl} goals != crates!"
    crate_summary[dollar_cnt] = crate_summary.get(dollar_cnt, 0) + 1
    campaign_moves.append(p['moves'])
    ch_name = "Cargo Bay" if lvl <= 15 else ("Cold Storage" if lvl <= 35 else "Cyber Depot")
    print(f"L{lvl:02d} [{ch_name:<12}]: {p['name']:<28} | {dollar_cnt} crates | {p['moves']:2d}m {p['pushes']:2d}p (states: {p['states']})")

print("\nCrate distribution across campaign:", crate_summary)
print(f"Optimal moves range: {min(campaign_moves)} to {max(campaign_moves)}, average: {sum(campaign_moves)/len(campaign_moves):.1f}")

# Write out all 50 files
for i, p in enumerate(campaign):
    lvl = i + 1
    path = f'levels/level_{lvl:02d}.sok'
    with open(path, 'w') as f:
        f.write('\n'.join(p['lines']) + '\n')

print("\nWrote all 50 levels successfully to levels/level_XX.sok!")
print(f"OPTIMAL_MOVES = {campaign_moves}")
