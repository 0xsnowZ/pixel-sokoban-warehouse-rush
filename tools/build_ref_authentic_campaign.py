import os
import re
import sys
import time
from collections import deque

def solve_grid(grid_lines, max_states=80000):
    walls = set()
    goals = set()
    crates = []
    player = None
    h = len(grid_lines)
    w = max(len(l) for l in grid_lines)
    
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
    if not player:
        return None, "No player"
    if len(crates) != len(goals) or len(crates) < 4:
        return None, f"Mismatch/Too few: {len(crates)} crates vs {len(goals)} goals"

    visited = set([(player, crates)])
    q = deque([(player, crates, 0, 0, '')])
    states = 0
    t0 = time.time()

    while q:
        states += 1
        if states > max_states:
            return None, f"TIMEOUT (> {max_states} states)"

        p, cr, moves, pushes, path = q.popleft()
        if set(cr) == goals:
            return {
                'moves': moves,
                'pushes': pushes,
                'states': states,
                'time_s': time.time() - t0,
                'path': path,
                'w': w,
                'h': h,
                'crates': len(crates)
            }, f"SOLVED: {moves}m, {pushes}p ({states} states in {time.time()-t0:.2f}s)"

        pr, pc = p
        cr_set = set(cr)
        for dr, dc, name in [(-1, 0, 'U'), (1, 0, 'D'), (0, -1, 'L'), (0, 1, 'R')]:
            nr, nc = pr + dr, pc + dc
            if (nr, nc) in walls: continue
            if (nr, nc) in cr_set:
                nnr, nnc = nr + dr, nc + dc
                if (nnr, nnc) in walls or (nnr, nnc) in cr_set: continue
                # Corner deadlock check
                if (nnr, nnc) not in goals:
                    up = (nnr - 1, nnc) in walls
                    dn = (nnr + 1, nnc) in walls
                    lt = (nnr, nnc - 1) in walls
                    rt = (nnr, nnc + 1) in walls
                    if (up and lt) or (up and rt) or (dn and lt) or (dn and rt):
                        continue
                # 2x2 deadlock check
                is_dead_2x2 = False
                for r0, c0 in [(nnr-1, nnc-1), (nnr-1, nnc), (nnr, nnc-1), (nnr, nnc)]:
                    cells = [(r0, c0), (r0+1, c0), (r0, c0+1), (r0+1, c0+1)]
                    all_blocked = True
                    has_nongoal = False
                    for cr_pos in cells:
                        if cr_pos in walls:
                            continue
                        is_cr = (cr_pos == (nnr, nnc)) or (cr_pos in cr_set and cr_pos != (nr, nc))
                        if is_cr:
                            if cr_pos not in goals:
                                has_nongoal = True
                        else:
                            all_blocked = False
                            break
                    if all_blocked and has_nongoal:
                        is_dead_2x2 = True
                        break
                if is_dead_2x2:
                    continue

                new_cr = list(cr)
                new_cr.remove((nr, nc))
                new_cr.append((nnr, nnc))
                new_cr = tuple(sorted(new_cr))
                if ((nr, nc), new_cr) not in visited:
                    visited.add(((nr, nc), new_cr))
                    q.append(((nr, nc), new_cr, moves + 1, pushes + 1, path + name))
            else:
                if ((nr, nc), cr) not in visited:
                    visited.add(((nr, nc), cr))
                    q.append(((nr, nc), cr, moves + 1, pushes, path + name.lower()))

    return None, f"UNSOLVABLE ({states} states in {time.time()-t0:.2f}s)"

def flip_h(lines):
    return [l[::-1] for l in lines]

def flip_v(lines):
    return lines[::-1]

def set_player_pos(lines, pr, pc):
    out = []
    for r, l in enumerate(lines):
        row = list(l)
        for c in range(len(row)):
            if row[c] == '@': row[c] = ' '
            elif row[c] == '+': row[c] = '.'
        if r == pr:
            if row[pc] == '.': row[pc] = '+'
            else: row[pc] = '@'
        out.append("".join(row))
    return out

# Define the 50 campaign levels
CAMPAIGN = {}

# --- CHAPTER 1: COLD STORAGE (Levels 1-10) ---
# 1. Level 1: Preserved Pinwheel (7x7, strictly test compatible)
CAMPAIGN[1] = [
    " ##### ",
    "##. .##",
    "# $ $ #",
    "# @   #",
    "# $ $ #",
    "##. .##",
    " ##### "
]

# 2. Ref Level 1 Authentic Pinwheel (9x8, 12m, 7p)
CAMPAIGN[2] = [
    "  ###   ",
    "  #.#   ",
    "  # ####",
    "###$ $ .#",
    "#. $ @##",
    "####$#  ",
    "   #.#  ",
    "   ###  "
]

# 3. Bay3x1 Loop (8x6, 18m, 5p)
CAMPAIGN[3] = [
    "########",
    "#     .#",
    "# $$$$ #",
    "# ...  #",
    "#   @###",
    "#####   "
]

# 4. The Courtyard (8x7, 21m, 8p)
CAMPAIGN[4] = [
    "########",
    "#  ..  #",
    "#  ..  #",
    "##$$$$##",
    "#  @   #",
    "#      #",
    "########"
]

# 5. TwinBay Deep 4 (9x6, 22m, 11p)
CAMPAIGN[5] = [
    "#########",
    "##.   .##",
    "##. $ .##",
    "#  $$$  #",
    "#   @   #",
    "#########"
]

# 6. Pinwheel V1 (8x9, 25m, 10p)
CAMPAIGN[6] = [
    "  ####  ",
    "  #..#  ",
    "###  ###",
    "# $ $  #",
    "#  @   #",
    "# $ $  #",
    "###  ###",
    "  #..#  ",
    "  ####  "
]

# 7. TwinTurnoutHub (8x7, 26m, 9p)
CAMPAIGN[7] = [
    "####### ",
    "# . . ##",
    "# $ $  #",
    "## @#$ #",
    "#  $ . #",
    "##.  ###",
    " #####  "
]

# 8. Bay2x2 V1 (9x6, 27m, 7p)
CAMPAIGN[8] = [
    "  ###### ",
    "  #    # ",
    "###$$$ # ",
    "#@ ..  ##",
    "#  ..$  #",
    "#########"
]

# 9. Snail 4cr (8x7, 28m, 6p)
CAMPAIGN[9] = [
    "########",
    "#@    .#",
    "# ###$##",
    "# #.$  #",
    "# #.$  #",
    "#   $ .#",
    "########"
]

# 10. Ref Level 9 Authentic (Chapter 1 Boss, 8x6, 29m, 9p)
CAMPAIGN[10] = [
    " ###### ",
    " #    # ",
    "##$$$ ##",
    "#  ..$ #",
    "#@ ..  #",
    "########"
]

# --- CHAPTER 2: CYBER DEPOT (Levels 11-20) ---
# 11. Bay2x3 with 4 crates (8x7, 28m, 8p)
CAMPAIGN[11] = [
    "  ######",
    "  #    #",
    "###$$$ #",
    "#@  ...#",
    "#   $ .#",
    "####  # ",
    "   #### "
]

# 12. Ref Level 7 Authentic Irregular (8x9, 28m, 13p)
CAMPAIGN[12] = [
    "  ####  ",
    "  #..#  ",
    "### .#  ",
    "#  $.#  ",
    "# $  ###",
    "#  $$  #",
    "#  @   #",
    "########",
    " #######"
]

# 13. Bay2x2 V2 (8x6, 30m, 10p)
CAMPAIGN[13] = [
    "########",
    "#     ##",
    "# $$$$ #",
    "# ..   #",
    "# ..@###",
    "######  "
]

# 14. Ref 14 Inspired 5-crate (9x7, 30m, 11p)
CAMPAIGN[14] = [
    "  ###### ",
    "  #    # ",
    "###$$$ # ",
    "#  $.. ##",
    "#@ $... #",
    "#####   #",
    "    #####"
]

# 15. Bay2x2 V2 (Start at (3, 6), 8x6, 31m, 10p)
CAMPAIGN[15] = set_player_pos(CAMPAIGN[13], 3, 6)

# 16. StaggeredMaze 4cr (8x7, 35m, 14p)
CAMPAIGN[16] = [
    "########",
    "#. $  .#",
    "#  #$  #",
    "# $#   #",
    "#@ $  .#",
    "#   # .#",
    "########"
]

# 17. Chute4 Ref04 (8x7, 36m, 15p)
CAMPAIGN[17] = [
    "  ##### ",
    "  #   # ",
    "### $ ##",
    "#  $  # ",
    "#@$$..# ",
    "### ..# ",
    "  ##### "
]

# 18. Bay2x2 V2 (Start at (1, 3), 8x6, 24m, 10p)
CAMPAIGN[18] = set_player_pos(CAMPAIGN[13], 1, 3)

# 19. Chute4 Ref04 flip_h (8x7, 36m, 15p)
CAMPAIGN[19] = flip_h(CAMPAIGN[17])

# 20. Ref Level 5 Authentic 2x3 Bay (Chapter 2 Boss, 5 crates, 8x7, 38m, 14p)
CAMPAIGN[20] = [
    "  ######",
    "  #    #",
    "###$$$ #",
    "#@ $...#",
    "#  $..##",
    "####  # ",
    "   #### "
]

# --- CHAPTER 3: NEON FOUNDRY (Levels 21-30) ---
# 21. Ref 7 flip_h (8x9, 28m, 13p)
CAMPAIGN[21] = flip_h(CAMPAIGN[12])

# 22. StaggeredMaze flip_h (8x7, 35m, 14p)
CAMPAIGN[22] = flip_h(CAMPAIGN[16])

# 23. Ref 5 flip_h (5 crates, 8x7, 38m, 14p)
CAMPAIGN[23] = flip_h(CAMPAIGN[20])

# 24. Bay2x2 V2 flip_h (8x6, 30m, 10p)
CAMPAIGN[24] = flip_h(CAMPAIGN[13])

# 25. Ref 14 Inspired flip_h (5 crates, 9x7, 30m, 11p)
CAMPAIGN[25] = flip_h(CAMPAIGN[14])

# Base TwinChute (7x8, 56m, 19p)
BASE_CHUTE = [
    "###### ",
    "# .  ##",
    "# $ $ #",
    "# # # #",
    "# $ $ #",
    "##  . #",
    " #@.. #",
    " ######"
]

# TwinChute variations with valid non-goal floor positions
CAMPAIGN[26] = set_player_pos(BASE_CHUTE, 1, 3) # 48m, 19p
CAMPAIGN[27] = set_player_pos(BASE_CHUTE, 1, 4) # 50m, 19p
CAMPAIGN[28] = set_player_pos(BASE_CHUTE, 2, 3) # 51m, 19p
CAMPAIGN[29] = set_player_pos(BASE_CHUTE, 3, 3) # 47m, 19p
CAMPAIGN[30] = set_player_pos(BASE_CHUTE, 4, 3) # Chapter 3 Boss (51m, 19p)

# --- CHAPTER 4: ORBITAL HUB (Levels 31-40) ---
CAMPAIGN[31] = set_player_pos(BASE_CHUTE, 5, 3) # 51m, 23p
CAMPAIGN[32] = set_player_pos(BASE_CHUTE, 5, 2) # 48m, 19p
CAMPAIGN[33] = set_player_pos(BASE_CHUTE, 5, 5) # 52m, 19p
CAMPAIGN[34] = set_player_pos(BASE_CHUTE, 1, 1) # 49m, 19p
CAMPAIGN[35] = set_player_pos(BASE_CHUTE, 2, 1) # 49m, 19p
CAMPAIGN[36] = set_player_pos(BASE_CHUTE, 2, 5) # 53m, 19p
CAMPAIGN[37] = set_player_pos(BASE_CHUTE, 3, 1) # 53m, 23p
CAMPAIGN[38] = set_player_pos(BASE_CHUTE, 3, 5) # 55m, 19p
CAMPAIGN[39] = set_player_pos(BASE_CHUTE, 4, 1) # 54m, 19p
CAMPAIGN[40] = set_player_pos(BASE_CHUTE, 4, 5) # Chapter 4 Boss (54m, 23p)

# --- CHAPTER 5: QUANTUM CORE (Levels 41-50) ---
BASE_CHUTE_FLIP = flip_h(BASE_CHUTE)
CAMPAIGN[41] = set_player_pos(BASE_CHUTE_FLIP, 1, 3) # 48m, 19p
CAMPAIGN[42] = set_player_pos(BASE_CHUTE_FLIP, 1, 5) # 50m, 19p
CAMPAIGN[43] = set_player_pos(BASE_CHUTE_FLIP, 2, 3) # 51m, 19p
CAMPAIGN[44] = set_player_pos(BASE_CHUTE_FLIP, 3, 3) # 47m, 19p
CAMPAIGN[45] = set_player_pos(BASE_CHUTE_FLIP, 4, 3) # 51m, 19p
CAMPAIGN[46] = set_player_pos(BASE_CHUTE_FLIP, 5, 3) # 51m, 23p
CAMPAIGN[47] = set_player_pos(BASE_CHUTE_FLIP, 5, 1) # 52m, 19p
CAMPAIGN[48] = set_player_pos(BASE_CHUTE_FLIP, 6, 1) # 54m, 23p
CAMPAIGN[49] = BASE_CHUTE_FLIP                      # 56m, 19p
CAMPAIGN[50] = BASE_CHUTE                           # 56m, 19p (Ultimate Masterpiece Climax)

print(f"Loaded {len(CAMPAIGN)} campaign levels. Beginning solver verification...")

optimal_moves = []
total_moves = 0
total_pushes = 0
failures = 0

t_start = time.time()
for lvl in range(1, 51):
    grid = CAMPAIGN[lvl]
    w = max(len(l) for l in grid)
    h = len(grid)
    
    # Check constraints
    crates = sum(l.count('$') + l.count('*') for l in grid)
    dummies = sum(l.count('*') for l in grid)
    player_on_goal = sum(l.count('+') for l in grid)
    
    if crates < 4:
        print(f"ERROR: Level {lvl:02d} has only {crates} crates!")
        failures += 1
    if dummies > 0:
        print(f"ERROR: Level {lvl:02d} has {dummies} dummy crates!")
        failures += 1
    if player_on_goal > 0:
        print(f"ERROR: Level {lvl:02d} has player starting on goal!")
        failures += 1
    if lvl > 1 and w == h:
        print(f"ERROR: Level {lvl:02d} is square ({w}x{h})!")
        failures += 1
        
    res, msg = solve_grid(grid, max_states=80000)
    if not res:
        print(f"FAIL: Level {lvl:02d} ({w}x{h}): {msg}")
        failures += 1
        optimal_moves.append(0)
    else:
        optimal_moves.append(res['moves'])
        total_moves += res['moves']
        total_pushes += res['pushes']
        print(f"Lvl {lvl:02d} ({w}x{h}, {crates}cr): {res['moves']:2d}m, {res['pushes']:2d}p ({res['states']:5d} states, {res['time_s']:.2f}s) ✓")

t_elapsed = time.time() - t_start
print("\n" + "=" * 60)
print(f"VERIFICATION SUMMARY: {50 - failures} / 50 levels verified solvable in {t_elapsed:.2f}s")
print(f"Total moves: {total_moves} (avg {total_moves/50:.1f} per level)")
print(f"Total pushes: {total_pushes} (avg {total_pushes/50:.1f} per level)")
print("=" * 60)

if failures > 0:
    print(f"Aborting write due to {failures} failures.")
    sys.exit(1)

# Write to disk
print("\nWriting verified level files to disk...")
for lvl in range(1, 51):
    path = f"/home/snowz/godot/levels/level_{lvl:02d}.sok"
    content = "\n".join(CAMPAIGN[lvl]) + "\n"
    with open(path, "w") as f:
        f.write(content)
print("All 50 level files written to res://levels/.")

# Update scripts/save_manager.gd
print("\nUpdating scripts/save_manager.gd OPTIMAL_MOVES...")
save_mgr_path = "/home/snowz/godot/scripts/save_manager.gd"
with open(save_mgr_path, "r") as f:
    code = f.read()

# Replace OPTIMAL_MOVES array
array_str = "const OPTIMAL_MOVES: Array[int] = [\n"
for i in range(0, 50, 10):
    chunk = optimal_moves[i:i+10]
    array_str += "\t" + ", ".join(str(m) for m in chunk) + ",\n"
array_str += "]"

new_code = re.sub(
    r"const OPTIMAL_MOVES: Array\[int\] = \[[^\]]*\]",
    array_str,
    code,
    flags=re.DOTALL
)

with open(save_mgr_path, "w") as f:
    f.write(new_code)
print("scripts/save_manager.gd successfully updated!")
