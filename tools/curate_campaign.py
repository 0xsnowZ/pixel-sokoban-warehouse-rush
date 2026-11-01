import sys
sys.path.insert(0, 'tools')
from new_level_generator import solve_forward

# 1. Tutorial 2: 1 crate, 8 moves, 3 pushes
tut2_lines = [
    ' #####',
    ' #   #',
    ' # $ #',
    '## # ###',
    '#   .  #',
    '# @ ####',
    '####'
]

# Read all archive levels
arch_levels = {}
for i in range(1, 51):
    f = f'/home/snowz/godot/levels/archive/level_{i:02d}.sok'
    with open(f) as fp:
        lines = [l.rstrip() for l in fp.read().strip('\n').split('\n')]
    walls, floor, goals, crates, player = set(), set(), set(), [], None
    for r, l in enumerate(lines):
        for col, ch in enumerate(l):
            if ch == '#': walls.add((r, col))
            elif ch == '.': goals.add((r, col)); floor.add((r, col))
            elif ch == '$': crates.append((r, col)); floor.add((r, col))
            elif ch == '*': crates.append((r, col)); goals.add((r, col)); floor.add((r, col))
            elif ch == '@': player = (r, col); floor.add((r, col))
            elif ch == '+': player = (r, col); goals.add((r, col)); floor.add((r, col))
            elif ch == ' ': floor.add((r, col))
    res = solve_forward(walls, floor, goals, player, crates, max_states=60000)
    assert res is not None, f"Level {i} failed to solve!"
    arch_levels[i] = {
        'id': f'Archive L{i:02d}',
        'crates': len(crates),
        'moves': res['moves'],
        'pushes': res['pushes'],
        'states': res['states'],
        'lines': lines
    }

# Also solve tut2
w, f, g, c, p = set(), set(), set(), [], None
for r, l in enumerate(tut2_lines):
    for col, ch in enumerate(l):
        if ch == '#': w.add((r, col))
        elif ch == '.': g.add((r, col)); f.add((r, col))
        elif ch == '$': c.append((r, col)); f.add((r, col))
        elif ch == '@': p = (r, col); f.add((r, col))
        elif ch == ' ': f.add((r, col))
res_tut2 = solve_forward(w, f, g, p, c)
tut2_obj = {
    'id': 'Tutorial 2 - Corner Nav',
    'crates': 1,
    'moves': res_tut2['moves'],
    'pushes': res_tut2['pushes'],
    'states': res_tut2['states'],
    'lines': tut2_lines
}

# The Curated 50 Sequence mapping (1-indexed level -> source)
# Notice: Archive L17 (4 crates, 17 moves, 4 pushes) and Archive L18 (2 crates, 17 moves, 5 pushes)
# We replace old L02 (which was a 4-crate shocker at level 2) with our gentle 1-crate Tutorial 2!
# And Old L02 (Pinwheel Cross, 4 crates, 12 moves, 7 pushes) moves to Level 14 as the exciting 4-crate intro!
sequence_sources = [
    # --- CHAPTER 0: CARGO BAY (Levels 1-15) ---
    ('Archive L01', arch_levels[1]),    # 1 crate, 5 moves
    ('Tutorial 2', tut2_obj),           # 1 crate, 8 moves  (Replaces old L02 4-crate shocker!)
    ('Archive L03', arch_levels[3]),    # 2 crates, 10 moves
    ('Archive L04', arch_levels[4]),    # 2 crates, 13 moves
    ('Archive L05', arch_levels[5]),    # 2 crates, 14 moves
    ('Archive L06', arch_levels[6]),    # 2 crates, 14 moves
    ('Archive L15', arch_levels[15]),   # 2 crates, 16 moves
    ('Archive L18', arch_levels[18]),   # 2 crates, 17 moves
    ('Archive L11', arch_levels[11]),   # 3 crates, 15 moves (Intro 3 crates)
    ('Archive L13', arch_levels[13]),   # 3 crates, 16 moves
    ('Archive L16', arch_levels[16]),   # 3 crates, 17 moves (Cargo Bay Peak 1)
    ('Archive L19', arch_levels[19]),   # 3 crates, 17 moves
    ('Archive L20', arch_levels[20]),   # 3 crates, 17 moves
    ('Archive L02', arch_levels[2]),    # 4 crates, 12 moves (Intro 4 crates - Pinwheel Cross!)
    ('Archive L07', arch_levels[7]),    # 4 crates, 14 moves (Cargo Bay Chapter Boss!)

    # --- CHAPTER 1: COLD STORAGE (Levels 16-35) ---
    ('Archive L08', arch_levels[8]),    # 4 crates, 15 moves, 4 pushes
    ('Archive L09', arch_levels[9]),    # 4 crates, 15 moves, 6 pushes
    ('Archive L10', arch_levels[10]),   # 4 crates, 15 moves, 7 pushes
    ('Archive L12', arch_levels[12]),   # 4 crates, 16 moves, 3 pushes
    ('Archive L14', arch_levels[14]),   # 4 crates, 16 moves, 6 pushes (Peak 1)
    ('Archive L21', arch_levels[21]),   # 3 crates, 17 moves, 6 pushes (Breather)
    ('Archive L17', arch_levels[17]),   # 4 crates, 17 moves, 4 pushes
    ('Archive L22', arch_levels[22]),   # 4 crates, 18 moves, 9 pushes
    ('Archive L23', arch_levels[23]),   # 3 crates, 19 moves, 7 pushes
    ('Archive L24', arch_levels[24]),   # 3 crates, 19 moves, 8 pushes
    ('Archive L26', arch_levels[26]),   # 4 crates, 20 moves, 4 pushes
    ('Archive L27', arch_levels[27]),   # 3 crates, 20 moves, 5 pushes
    ('Archive L28', arch_levels[28]),   # 4 crates, 20 moves, 5 pushes
    ('Archive L29', arch_levels[29]),   # 4 crates, 20 moves, 5 pushes
    ('Archive L32', arch_levels[32]),   # 4 crates, 21 moves, 9 pushes (Peak 2)
    ('Archive L31', arch_levels[31]),   # 3 crates, 21 moves, 7 pushes (Breather)
    ('Archive L33', arch_levels[33]),   # 4 crates, 22 moves, 6 pushes
    ('Archive L34', arch_levels[34]),   # 4 crates, 22 moves, 8 pushes
    ('Archive L38', arch_levels[38]),   # 4 crates, 23 moves, 12 pushes
    ('Archive L25', arch_levels[25]),   # 5 crates, 20 moves, 3 pushes (Cold Storage Boss - Intro 5 crates!)

    # --- CHAPTER 2: CYBER DEPOT (Levels 36-50) ---
    ('Archive L35', arch_levels[35]),   # 3 crates, 22 moves, 9 pushes
    ('Archive L36', arch_levels[36]),   # 3 crates, 22 moves, 9 pushes
    ('Archive L39', arch_levels[39]),   # 3 crates, 24 moves, 3 pushes
    ('Archive L40', arch_levels[40]),   # 3 crates, 24 moves, 10 pushes (Peak 1)
    ('Archive L30', arch_levels[30]),   # 5 crates, 21 moves, 5 pushes (Breather)
    ('Archive L41', arch_levels[41]),   # 4 crates, 25 moves, 13 pushes
    ('Archive L42', arch_levels[42]),   # 4 crates, 25 moves, 13 pushes
    ('Archive L43', arch_levels[43]),   # 3 crates, 27 moves, 9 pushes
    ('Archive L44', arch_levels[44]),   # 4 crates, 27 moves, 9 pushes
    ('Archive L45', arch_levels[45]),   # 3 crates, 27 moves, 14 pushes
    ('Archive L46', arch_levels[46]),   # 4 crates, 28 moves, 10 pushes
    ('Archive L47', arch_levels[47]),   # 4 crates, 28 moves, 11 pushes
    ('Archive L48', arch_levels[48]),   # 4 crates, 29 moves, 11 pushes (Pre-Climax)
    ('Archive L49', arch_levels[49]),   # 4 crates, 30 moves, 8 pushes  (Climax)
    ('Archive L50', arch_levels[50]),   # 3 crates, 32 moves, 11 pushes (Grand Master Finale)
]

assert len(sequence_sources) == 50, f"Expected 50 levels, got {len(sequence_sources)}"

# Check for duplicates
seen_levels = set()
for label, data in sequence_sources:
    assert label not in seen_levels, f"Duplicate level {label} in campaign!"
    seen_levels.add(label)

print("All 50 levels are strictly unique!")

# Print table
print("\n" + "="*70)
print("             REFACTORED 50-LEVEL CAMPAIGN PROGRESSION")
print("="*70)
print(f"{'Lvl':3s} | {'Chapter':12s} | {'Source':15s} | {'Crates':6s} | {'Moves':5s} | {'Pushes':6s} | Note")
print("-"*70)

optimal_moves_array = []
for i, (label, data) in enumerate(sequence_sources):
    lvl = i + 1
    ch = 'Cargo Bay' if lvl <= 15 else ('Cold Storage' if lvl <= 35 else 'Cyber Depot')
    c = data['crates']
    m = data['moves']
    p = data['pushes']
    optimal_moves_array.append(m)
    
    note = ""
    if lvl == 1: note = "⭐ Tutorial 1 (Push forward)"
    elif lvl == 2: note = "⭐ Tutorial 2 (Around the corner)"
    elif lvl == 3: note = "⭐ Tutorial 3 (Dual crates)"
    elif lvl == 9: note = "📦 Intro 3 Crates"
    elif lvl == 14: note = "📦 Intro 4 Crates (Pinwheel Cross)"
    elif lvl == 15: note = "🏆 CARGO BAY BOSS"
    elif lvl == 21: note = "🍃 Cold Storage Breather"
    elif lvl == 30: note = "⚡ Cold Storage Peak"
    elif lvl == 35: note = "🏆 COLD STORAGE BOSS (Intro 5 Crates)"
    elif lvl == 41: note = "🍃 Cyber Depot Breather"
    elif lvl == 48: note = "🔥 Pre-Climax"
    elif lvl == 49: note = "🔥 Climax"
    elif lvl == 50: note = "👑 GRAND MASTER FINALE"
    
    print(f"{lvl:3d} | {ch:12s} | {label:15s} | {c:6d} | {m:5d} | {p:6d} | {note}")

print("="*70)
print("\nNew OPTIMAL_MOVES array for SaveManager:")
print(optimal_moves_array)

# Write out all 50 files
for i, (label, data) in enumerate(sequence_sources):
    lvl = i + 1
    path = f"/home/snowz/godot/levels/level_{lvl:02d}.sok"
    with open(path, 'w') as f:
        f.write("\n".join(data['lines']) + "\n")

print(f"\nSuccessfully wrote all 50 level files to /home/snowz/godot/levels/level_01.sok..level_50.sok!")
