import sys
import os
import random
sys.path.insert(0, 'tools')
from new_level_generator import TEMPLATES, generate_puzzles, solve_forward

random.seed(42)

# L1: 4 crates (3 secured on goals, 1 active) -> 5 moves, 3 pushes
l1_lines = [
    '######',
    '#   .#',
    '# $ *#',
    '# @**#',
    '#    #',
    '######'
]

# L2: 4 crates (symmetrical quad distribution) -> 10 moves, 4 pushes
l2_lines = [
    ' #####',
    '##. .##',
    '# $ $ #',
    '#  @  #',
    '# $ $ #',
    '##. .##',
    ' #####'
]

# L45 candidate: Corner Alcove 4c, 27 moves, 11 pushes
l45_lines = [
    '  #######',
    '  #.  $ #',
    '###. #  #',
    '#  $$#$ #',
    '#  .+   #',
    '#########'
]

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
    res = solve_forward(walls, floor, goals, player, crates, max_states=80000)
    assert res is not None, f"Failed to solve {name}!"
    return {
        'name': name,
        'crates': len(crates),
        'moves': res['moves'],
        'pushes': res['pushes'],
        'states': res['states'],
        'lines': lines
    }

l1_puz = parse_and_solve(l1_lines, 'Tutorial 1 (4-Crate Focus)')
l2_puz = parse_and_solve(l2_lines, 'Tutorial 2 (Quad Distribution)')
l45_puz = parse_and_solve(l45_lines, 'Corner Alcove (4c)')

# Collect archive 4+ crate levels
arch_puzzles = {}
for i in range(1, 51):
    f = f'/home/snowz/godot/levels/archive/level_{i:02d}.sok'
    with open(f) as fp:
        lines = [l.rstrip() for l in fp.read().strip('\n').split('\n')]
    crates_count = sum(l.count('$') + l.count('*') for l in lines)
    if crates_count >= 4:
        p = parse_and_solve(lines, f'Archive L{i:02d}')
        arch_puzzles[i] = p

print(f"Archive 4+ crate levels available: {len(arch_puzzles)}")

# Generate fresh 4 and 5 crate levels across templates
fresh_pool = []
for name, tmpl, crates_list in TEMPLATES:
    for c in [4, 5]:
        puzs = generate_puzzles(tmpl, name, c, count=6, min_moves=11, max_moves=60)
        for p in puzs:
            fresh_pool.append({
                'name': f"{name} ({c}c)",
                'crates': c,
                'moves': p['moves'],
                'pushes': p['pushes'],
                'states': p['states'],
                'lines': p['lines']
            })

print(f"Fresh 4+ crate levels generated: {len(fresh_pool)}")

seen_layouts = set()
unique_fresh = []
for p in fresh_pool:
    k = '\n'.join(p['lines'])
    if k not in seen_layouts:
        seen_layouts.add(k)
        unique_fresh.append(p)

used_fresh = set()
def pick_fresh(tgt_moves, min_crates=4, max_crates=5, disfavor_name=""):
    best = None
    best_diff = 999
    best_idx = -1
    for i, p in enumerate(unique_fresh):
        if i in used_fresh:
            continue
        if min_crates <= p['crates'] <= max_crates:
            diff = abs(p['moves'] - tgt_moves)
            if p['name'] == disfavor_name:
                diff += 5
            if diff < best_diff:
                best_diff = diff
                best = p
                best_idx = i
                if diff == 0:
                    break
    if best is not None:
        used_fresh.add(best_idx)
    return best

campaign = [
    # --- CHAPTER 0: CARGO BAY (Levels 1-15) ---
    l1_puz,                                         # L01: 4c, 5m (Tutorial 1)
    l2_puz,                                         # L02: 4c, 10m (Tutorial 2)
    pick_fresh(11, 4, 4),                          # L03: 4c, 11m
    arch_puzzles[2],                               # L04: 4c, 12m (Pinwheel Cross!)
    pick_fresh(12, 4, 4),                          # L05: 4c, 12m
    pick_fresh(13, 4, 4),                          # L06: 4c, 13m
    pick_fresh(13, 4, 4),                          # L07: 4c, 13m
    arch_puzzles[7],                               # L08: 4c, 14m
    pick_fresh(14, 4, 4),                          # L09: 4c, 14m
    arch_puzzles[8],                               # L10: 4c, 15m (Peak 1)
    pick_fresh(12, 4, 4),                          # L11: 4c, 12m (Breather)
    pick_fresh(14, 4, 4),                          # L12: 4c, 14m
    arch_puzzles[9],                               # L13: 4c, 15m
    arch_puzzles[12],                              # L14: 4c, 16m
    arch_puzzles[17],                              # L15: 4c, 17m (Cargo Bay Boss)

    # --- CHAPTER 1: COLD STORAGE (Levels 16-35) ---
    arch_puzzles[10],                              # L16: 4c, 15m
    pick_fresh(15, 4, 4),                          # L17: 4c, 15m
    arch_puzzles[14],                              # L18: 4c, 16m
    pick_fresh(16, 4, 4),                          # L19: 4c, 16m
    pick_fresh(17, 4, 4),                          # L20: 4c, 17m
    pick_fresh(15, 4, 4),                          # L21: 4c, 15m (Breather)
    pick_fresh(17, 4, 4),                          # L22: 4c, 17m
    arch_puzzles[22],                              # L23: 4c, 18m
    pick_fresh(19, 4, 4),                          # L24: 4c, 19m
    arch_puzzles[25],                              # L25: 5c, 20m (Intro 5 crates!)
    arch_puzzles[26],                              # L26: 4c, 20m
    arch_puzzles[30],                              # L27: 5c, 21m
    arch_puzzles[32],                              # L28: 4c, 21m
    arch_puzzles[33],                              # L29: 4c, 22m
    arch_puzzles[38],                              # L30: 4c, 23m (Cold Storage Peak 2)
    pick_fresh(18, 4, 4),                          # L31: 4c, 18m (Breather)
    arch_puzzles[34],                              # L32: 4c, 22m
    pick_fresh(24, 4, 4),                          # L33: 4c, 24m
    pick_fresh(24, 5, 5),                          # L34: 5c, 24m
    arch_puzzles[41],                              # L35: 4c, 25m (Cold Storage Boss)

    # --- CHAPTER 2: CYBER DEPOT (Levels 36-50) ---
    pick_fresh(21, 4, 4),                          # L36: 4c, 21m
    pick_fresh(22, 5, 5),                          # L37: 5c, 22m
    pick_fresh(23, 5, 5),                          # L38: 5c, 23m
    pick_fresh(24, 4, 4),                          # L39: 4c, 24m
    arch_puzzles[42],                              # L40: 4c, 25m (Peak 1)
    arch_puzzles[28],                              # L41: 4c, 20m (Breather)
    pick_fresh(25, 4, 4),                          # L42: 4c, 25m
    pick_fresh(25, 5, 5),                          # L43: 5c, 25m
    arch_puzzles[44],                              # L44: 4c, 27m
    l45_puz,                                       # L45: 4c, 27m (Corner Alcove)
    arch_puzzles[46],                              # L46: 4c, 28m
    pick_fresh(28, 5, 5),                          # L47: 5c, 28m
    arch_puzzles[47],                              # L48: 4c, 28m (Pre-Climax)
    arch_puzzles[48],                              # L49: 4c, 29m (Climax)
    arch_puzzles[49],                              # L50: 4c, 30m (Grand Master Finale)
]

assert len(campaign) == 50, f"Expected 50 levels, got {len(campaign)}"

# Check for duplicate layouts
unique_check = set()
for idx, p in enumerate(campaign):
    key = '\n'.join(p['lines'])
    assert key not in unique_check, f"Level {idx+1} is a duplicate layout!"
    unique_check.add(key)

print(f"Verified: All 50 levels have unique layouts!")

print("\n" + "="*74)
print("       REFACTORED 50-LEVEL CAMPAIGN (MINIMUM 4 CRATES PER LEVEL)")
print("="*74)
print(f"{'Lvl':3s} | {'Chapter':12s} | {'Source':26s} | {'Crates':6s} | {'Moves':5s} | {'Pushes':6s}")
print("-"*74)

optimal_moves = []
for i, p in enumerate(campaign):
    assert p['crates'] >= 4, f"Level {i+1} has {p['crates']} crates, which is < 4!"
    lvl = i + 1
    ch = 'Cargo Bay' if lvl <= 15 else ('Cold Storage' if lvl <= 35 else 'Cyber Depot')
    print(f"{lvl:3d} | {ch:12s} | {p['name']:26s} | {p['crates']:6d} | {p['moves']:5d} | {p['pushes']:6d}")
    optimal_moves.append(p['moves'])

print("="*74)
print(f"Verified: All 50 levels have >= 4 crates! (Min: {min(p['crates'] for p in campaign)}, Max: {max(p['crates'] for p in campaign)})")
print(f"\nNew OPTIMAL_MOVES array:\n{optimal_moves}\n")

# Write out levels to disk
for i, p in enumerate(campaign):
    lvl = i + 1
    path = f"/home/snowz/godot/levels/level_{lvl:02d}.sok"
    with open(path, 'w') as f:
        f.write('\n'.join(p['lines']) + '\n')

print("All 50 level files updated on disk!")
