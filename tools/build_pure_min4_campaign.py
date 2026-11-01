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

print("Parsing anchor handcrafted clean levels...")
l1_quad = parse_and_solve([
    ' #####',
    '##. .##',
    '# $ $ #',
    '#  @  #',
    '# $ $ #',
    '##. .##',
    ' #####'
], 'Tutorial Quad Distribution (4c)')

with open('levels/archive/level_02.sok') as f:
    arch_02_lines = [l.rstrip() for l in f.read().strip('\n').split('\n')]
arch_02 = parse_and_solve(arch_02_lines, 'Pinwheel Cross (4c)')

with open('levels/archive/level_22.sok') as f:
    arch_22_lines = [l.rstrip() for l in f.read().strip('\n').split('\n')]
arch_22 = parse_and_solve(arch_22_lines, 'Twin Chambers (4c)')

seen_layouts = set()
for p in [l1_quad, arch_02, arch_22]:
    seen_layouts.add('\n'.join(p['lines']))

print("Generating multi-seed candidate pool...")
start_time = time.time()

early_pool = [l1_quad, arch_02]
mid_pool = [arch_22]
high_pool = []

SEEDS = [42, 101, 777, 1337, 2026, 8888, 9999, 12345, 54321]

for s in SEEDS:
    random.seed(s)
    for name, tmpl, c_opts in TEMPLATES:
        lines = [l.rstrip() for l in tmpl.strip('\n').split('\n')]
        height = len(lines)
        walls = set()
        floor = set()
        possible_goals = []
        for r in range(height):
            for col in range(len(lines[r])):
                ch = lines[r][col]
                if ch == '#': walls.add((r, col))
                elif ch == ' ': floor.add((r, col))
                elif ch == '.': floor.add((r, col)); possible_goals.append((r, col))
        
        for c in [4, 5]:
            if len(floor) < c + 4: continue
            goals_pool = list(possible_goals) if len(possible_goals) >= c else list(floor)

            for attempt in range(50):
                goals = tuple(sorted(random.sample(goals_pool, c)))
                cur_crates = list(goals)
                player_candidates = [
                    (cr[0] + dr, cr[1] + dc)
                    for cr in cur_crates
                    for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]
                    if (cr[0] + dr, cr[1] + dc) in floor and (cr[0] + dr, cr[1] + dc) not in cur_crates
                ]
                if not player_candidates: continue
                cur_p = random.choice(player_candidates)

                num_pulls = random.randint(30, 240)
                for step in range(num_pulls):
                    pulls = []
                    for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                        c_pos = (cur_p[0] - dr, cur_p[1] - dc)
                        p_next = (cur_p[0] + dr, cur_p[1] + dc)
                        if c_pos in cur_crates and p_next in floor and p_next not in cur_crates:
                            pulls.append((c_pos, p_next))
                    walks = []
                    for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                        p_next = (cur_p[0] + dr, cur_p[1] + dc)
                        if p_next in floor and p_next not in cur_crates:
                            walks.append(p_next)
                    if pulls and random.random() < 0.72:
                        c_pos, p_next = random.choice(pulls)
                        cur_crates.remove(c_pos)
                        cur_crates.append(cur_p)
                        cur_p = p_next
                    elif walks:
                        cur_p = random.choice(walks)
                    else: break

                    if len(set(cur_crates).intersection(set(goals))) == 0 and cur_p not in goals:
                        grid_lines = format_grid(lines, walls, goals, cur_p, cur_crates)
                        k = '\n'.join(grid_lines)
                        if k in seen_layouts: continue
                        res = solve_forward(walls, floor, goals, cur_p, cur_crates, max_states=35000)
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
                            if 10 <= m <= 17 and c == 4:
                                early_pool.append(puz)
                            if 15 <= m <= 24 and c == 4:
                                mid_pool.append(puz)
                            if m >= 20:
                                high_pool.append(puz)
                            break

print(f"Generated pools in {time.time() - start_time:.1f}s:")
print(f"  Early pool (10-17m): {len(early_pool)}")
print(f"  Mid pool   (15-24m): {len(mid_pool)}")
print(f"  High pool  (20-35m): {len(high_pool)}")

# Chapter 0 Targets (Levels 1 - 15)
CH0_TARGETS = [10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 12, 14, 15, 16, 17]
# Chapter 1 Targets (Levels 16 - 35)
CH1_TARGETS = [15, 16, 16, 17, 17, 18, 15, 18, 19, 19, 20, 20, 21, 21, 22, 18, 22, 23, 23, 24]
# Chapter 2 Targets (Levels 36 - 50)
CH2_TARGETS = [20, 21, 22, 23, 23, 21, 24, 25, 25, 26, 27, 28, 29, 31, 34]

used_layouts = set()

def pick_from_pool(pool, tgt_moves, disfavor_tmpl=None):
    best_item = None
    best_score = 999999
    for p in pool:
        k = '\n'.join(p['lines'])
        if k in used_layouts: continue
        diff = abs(p['moves'] - tgt_moves)
        score = diff * 10
        if disfavor_tmpl and p['template'] == disfavor_tmpl:
            score += 30
        if score < best_score:
            best_score = score
            best_item = p
            if diff == 0 and (not disfavor_tmpl or p['template'] != disfavor_tmpl):
                break
    assert best_item is not None, f"Could not find candidate for {tgt_moves} moves!"
    used_layouts.add('\n'.join(best_item['lines']))
    return best_item

campaign = []

# --- CHAPTER 0 ---
# L1 is fixed as l1_quad
campaign.append(l1_quad)
used_layouts.add('\n'.join(l1_quad['lines']))

for lvl in range(2, 16):
    if lvl == 4:
        campaign.append(arch_02)
        used_layouts.add('\n'.join(arch_02['lines']))
        continue
    tgt = CH0_TARGETS[lvl - 1]
    prev_tmpl = campaign[-1]['template']
    p = pick_from_pool(early_pool, tgt, disfavor_tmpl=prev_tmpl)
    campaign.append(p)

# --- CHAPTER 1 ---
for lvl in range(16, 36):
    tgt = CH1_TARGETS[lvl - 16]
    prev_tmpl = campaign[-1]['template']
    p = pick_from_pool(mid_pool, tgt, disfavor_tmpl=prev_tmpl)
    campaign.append(p)

# --- CHAPTER 2 ---
for lvl in range(36, 51):
    tgt = CH2_TARGETS[lvl - 36]
    prev_tmpl = campaign[-1]['template']
    p = pick_from_pool(high_pool, tgt, disfavor_tmpl=prev_tmpl)
    campaign.append(p)

print(f"\nFinal Campaign assembled: {len(campaign)} levels!")

campaign_moves = []
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
    campaign_moves.append(p['moves'])
    ch_name = "Cargo Bay" if lvl <= 15 else ("Cold Storage" if lvl <= 35 else "Cyber Depot")
    print(f"L{lvl:02d} [{ch_name:<12}]: {p['name']:<28} | {dollar_cnt} crates | {p['moves']}m {p['pushes']}p")

# Write out all 50 files
for i, p in enumerate(campaign):
    lvl = i + 1
    path = f'levels/level_{lvl:02d}.sok'
    with open(path, 'w') as f:
        f.write('\n'.join(p['lines']) + '\n')

print("\nWrote all 50 levels successfully!")
print(f"OPTIMAL_MOVES = {campaign_moves}")
