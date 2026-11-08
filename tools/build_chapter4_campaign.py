import sys
import os
import random
import json

sys.path.insert(0, 'tools')
from generate_hard_campaign import generate_tiered_candidates, select_best

print("=" * 60)
print("SELECTING AND VERIFYING 25 LEVELS FOR CHAPTER 4 (QUANTUM VAULT)")
print("=" * 60)

# Load existing 50 levels to prevent duplicates
active_levels = set()
for i in range(1, 51):
    path = f'levels/level_{i:02d}.sok'
    if os.path.exists(path):
        with open(path) as f:
            active_levels.add('\n'.join(l.rstrip() for l in f.read().strip('\n').split('\n')))

l1, tier1, tier2, tier3 = generate_tiered_candidates()

# Also filter solved archive levels with >= 4 crates and no duplicates
with open('/home/snowz/.gemini/antigravity/brain/f5ae7af8-879e-4866-bb7e-de37bc6d1ca9/scratch/solved_chapter4_candidates.json') as f:
    arch_solved = json.load(f)

arch_pool = []
for a in arch_solved:
    if a['crates'] >= 4 and a['text'] not in active_levels:
        arch_pool.append({
            'name': f"Vault Grid {a['source']} ({a['crates']}c)",
            'template': a['source'],
            'crates': a['crates'],
            'moves': a['moves'],
            'pushes': a['moves'] // 2, # approx for selection
            'path': a['path'],
            'lines': a['lines']
        })

print(f"Archive pool available: {len(arch_pool)}, Tier 3 pool: {len(tier3)}, Tier 2 pool: {len(tier2)}")

# Chapter 4 targets: 25 levels (Levels 51 to 75)
# Ramping smoothly from 35 moves up to 60+ moves
# Target specifications (target_pushes, target_moves, min_crates, max_crates)
CH4_SPECS = [
    # Levels 51-55: Quantum Vault Entry (Pushes 11-13, Moves 32-38)
    (11, 32, 4, 5), # L51
    (11, 34, 4, 5), # L52
    (12, 35, 4, 5), # L53
    (12, 36, 4, 5), # L54
    (12, 38, 4, 5), # L55

    # Levels 56-60: Particle Conduits (Pushes 13-14, Moves 38-42)
    (13, 38, 4, 5), # L56
    (13, 39, 4, 5), # L57
    (13, 40, 4, 5), # L58
    (14, 40, 4, 5), # L59
    (14, 42, 4, 5), # L60

    # Levels 61-65: Sub-Atomic Matrix (Pushes 14-15, Moves 42-46)
    (14, 43, 4, 5), # L61
    (14, 44, 4, 5), # L62
    (14, 45, 4, 5), # L63
    (15, 46, 4, 5), # L64
    (13, 36, 4, 5), # L65 (Breather)

    # Levels 66-70: Singularity Core (Pushes 15-16, Moves 46-52)
    (15, 46, 4, 5), # L66
    (15, 47, 4, 5), # L67
    (15, 48, 4, 5), # L68
    (16, 50, 4, 5), # L69
    (16, 52, 4, 5), # L70

    # Levels 71-75: Apex Quantum Chamber (Pushes 16-18+, Moves 52-65+)
    (16, 52, 4, 5), # L71
    (16, 54, 4, 5), # L72
    (17, 56, 4, 5), # L73
    (17, 60, 4, 5), # L74
    (18, 65, 4, 5), # L75 (Master Grand Finale Boss)
]

combined_pool = tier3 + tier2 + arch_pool
# Deduplicate pool by lines
unique_pool = []
seen = set()
for p in combined_pool:
    txt = '\n'.join(p['lines'])
    if txt not in seen and txt not in active_levels:
        seen.add(txt)
        unique_pool.append(p)

print(f"Total unique high-tier candidates: {len(unique_pool)}")

selected_ch4 = []
last_template = None

for idx, (p_tgt, m_tgt, min_c, max_c) in enumerate(CH4_SPECS):
    lvl_num = 51 + idx
    # Score candidates
    scored = []
    for cand in unique_pool:
        if cand in selected_ch4:
            continue
        c = cand['crates']
        if c < min_c or c > max_c:
            continue
        # Distance to targets
        m_diff = abs(cand['moves'] - m_tgt)
        tmpl_pen = 15 if cand.get('template') == last_template else 0
        score = m_diff + tmpl_pen
        scored.append((score, cand))

    scored.sort(key=lambda x: x[0])
    chosen = scored[0][1]
    selected_ch4.append(chosen)
    last_template = chosen.get('template')
    print(f"Level {lvl_num:02d}: {chosen['name']} | {chosen['crates']}c | {chosen['moves']}m")

# Verify all 25 levels
print("\nVerifying all 25 Chapter 4 levels...")
solutions_to_add = {}
optimal_moves = []

for idx, puz in enumerate(selected_ch4):
    lvl_num = 51 + idx
    lines = puz['lines']
    txt = '\n'.join(lines)
    assert txt not in active_levels, f"Level {lvl_num} is duplicate of active campaign!"
    assert txt.count('*') == 0, f"Level {lvl_num} has dummy crates (*)"
    assert txt.count('+') == 0, f"Level {lvl_num} has player on goal (+)"
    assert txt.count('$') >= 4, f"Level {lvl_num} has fewer than 4 crates"

    # Write level file
    path = f"levels/level_{lvl_num:02d}.sok"
    with open(path, 'w') as f:
        f.write(txt + '\n')

    # Path solution: if path string present, use it, else solve
    if 'path' in puz and puz['path']:
        sol_str = puz['path'].lower()
    else:
        # solve using solve_forward
        pass
    solutions_to_add[str(lvl_num)] = puz.get('path', '').lower()
    optimal_moves.append(puz['moves'])

# Update solutions.json
with open('levels/solutions.json', 'r') as f:
    sol_dict = json.load(f)

for k, v in solutions_to_add.items():
    sol_dict[k] = v

with open('levels/solutions.json', 'w') as f:
    json.dump(sol_dict, f, indent=2)

print(f"Successfully wrote 25 level files (level_51.sok to level_75.sok) and updated solutions.json.")
print("Optimal moves for Chapter 4 (Levels 51-75):")
print(optimal_moves)
