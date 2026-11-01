import sys
import random
import time
from collections import deque
import json
import os

random.seed(42)

def solve_forward(walls, floor, goals, player, crates, max_states=45000):
    crates = tuple(sorted(crates))
    goals = frozenset(goals)
    visited = set([(player, crates)])
    q = deque([(player, crates, 0, 0, '')])
    states = 0
    start = time.time()
    
    def is_blocked(pos):
        return pos in walls or pos not in floor

    while q:
        states += 1
        if states > max_states:
            return None
        p, cr, moves, pushes, path = q.popleft()
        if set(cr) == goals:
            return {
                'solvable': True,
                'moves': moves,
                'pushes': pushes,
                'states': states,
                'path': path,
                'time_s': time.time() - start
            }
        pr, pc = p
        cr_set = set(cr)
        for dr, dc, name in [(-1, 0, 'U'), (1, 0, 'D'), (0, -1, 'L'), (0, 1, 'R')]:
            nr, nc = pr + dr, pc + dc
            if (nr, nc) in walls or (nr, nc) not in floor:
                continue
            if (nr, nc) in cr_set:
                nnr, nnc = nr + dr, nc + dc
                if (nnr, nnc) in walls or (nnr, nnc) not in floor or (nnr, nnc) in cr_set:
                    continue
                # Corner deadlock pruning
                if (nnr, nnc) not in goals:
                    w_up = is_blocked((nnr-1, nnc))
                    w_dn = is_blocked((nnr+1, nnc))
                    w_lt = is_blocked((nnr, nnc-1))
                    w_rt = is_blocked((nnr, nnc+1))
                    if (w_up and w_lt) or (w_up and w_rt) or (w_dn and w_lt) or (w_dn and w_rt):
                        continue
                
                # 2x2 deadlock pruning
                is_2x2_dead = False
                for dr2, dc2 in [(0, 0), (-1, 0), (0, -1), (-1, -1)]:
                    r0, c0 = nnr + dr2, nnc + dc2
                    cells = [(r0, c0), (r0+1, c0), (r0, c0+1), (r0+1, c0+1)]
                    all_solid = True
                    has_non_goal_crate = False
                    for cell in cells:
                        if is_blocked(cell):
                            continue
                        is_cr = (cell == (nnr, nnc)) or (cell in cr_set and cell != (nr, nc))
                        if is_cr:
                            if cell not in goals:
                                has_non_goal_crate = True
                        else:
                            all_solid = False
                            break
                    if all_solid and has_non_goal_crate:
                        is_2x2_dead = True
                        break
                if is_2x2_dead:
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
    return None

def format_grid(template_lines, walls, goals, player, crates):
    height = len(template_lines)
    width = max(len(l) for l in template_lines)
    grid = []
    crate_set = set(crates)
    for r in range(height):
        row = []
        for c in range(width):
            pos = (r, c)
            if pos in walls:
                row.append('#')
            elif pos == player and pos in goals:
                row.append('+')
            elif pos == player:
                row.append('@')
            elif pos in crate_set and pos in goals:
                row.append('*')
            elif pos in crate_set:
                row.append('$')
            elif pos in goals:
                row.append('.')
            elif (r < len(template_lines) and c < len(template_lines[r]) and template_lines[r][c] == ' ') or pos in walls:
                row.append(' ')
            else:
                row.append(' ')
        grid.append(''.join(row).rstrip())
    return grid

TEMPLATES = [
    # 1. Pinwheel Cross
    ('Pinwheel Cross', '''
  ###
  # #
  # ####
###    #
#      #
#### # #
   # #
   ###
''', [3, 4]),

    # 2. Stepped L-Shape
    ('Stepped L-Room', '''
#####
#   #
#   ###
#     #
#   ###
#   #
#...#
#####
''', [2, 3]),

    # 3. Corner Nook
    ('Corner Nook', '''
  #####
###   #
#     #
#     #
#   ###
#   #
#####
''', [2, 3]),

    # 4. S-Winding Corridor
    ('S-Corridor', '''
  #####
  #   #
  #   ##
### #  #
#   #  #
#   # ##
#      #
########
''', [2, 3]),

    # 5. Twin Pillar Room
    ('Pillar Hall', '''
######
#    #
# ## #
#    #
# ## #
#    #
######
''', [3, 4]),

    # 6. Central Column Donut
    ('Island Loop', '''
#######
#     #
# ### #
# # # #
# ### #
#     #
#######
''', [2, 3, 4]),

    # 7. Asymmetric Dock
    ('Stepped Depot', '''
  ######
  #    #
###    #
#      #
#    ###
######
''', [3, 4]),

    # 8. Twin Bays
    ('Twin Bays', '''
########
#  #   #
#      #
#  #   #
########
''', [3, 4]),

    # 9. Narrow Shaft
    ('Vertical Shaft', '''
######
#    #
# ## #
#  # #
#  # #
#    #
######
''', [2, 3]),

    # 10. Castle Keep
    ('Castle Keep', '''
 #####
##   ##
#     #
#     #
##   ##
  #####
''', [3, 4]),

    # 11. T-Junction Depot
    ('T-Depot', '''
#########
#       #
###   ###
  #   #
  #   #
  #####
''', [2, 3]),

    # 12. Airlock Double Chamber
    ('Airlock Chambers', '''
##### #####
#   ###   #
#         #
#   ###   #
##### #####
''', [2, 3, 4]),

    # 13. Diamond Depot
    ('Diamond Depot', '''
   ###
  ## ##
 ##   ##
##     ##
#       #
##     ##
 ##   ##
  #####
''', [3, 4]),

    # 14. Zigzag Corridor
    ('Zigzag Run', '''
  #####
  #   #
###   #
#   ###
#   #
### ###
  # #
  ###
''', [2, 3]),

    # 15. Fortress Vault
    ('Fortress Vault', '''
  #####
 ##   ##
##  #  ##
#       #
##     ##
  #######
''', [3, 4]),

    # 16. S-Bend with Pocket
    ('Pocket S-Bend', '''
  ######
  #    #
###    #
#    # #
#  ### #
#      #
########
''', [3, 4]),

    # 17. Stepped Cross
    ('Cruciform Depot', '''
  #####
  #   #
###   ###
#       #
#       #
###   ###
  #   #
  #####
''', [3, 4]),

    # 18. Extended L-Bay
    ('Extended L-Bay', '''
######
#    ###
#      #
###    #
  #    #
  ######
''', [2, 3]),

    # 19. Master Ring Chamber
    ('Grand Ring', '''
 #######
##     ##
#  ###  #
#  # #  #
#  ###  #
##     ##
 #######
''', [3, 4, 5]),

    # 20. Corner Alcove
    ('Corner Alcove', '''
  #######
  #     #
###  #  #
#    #  #
#       #
#########
''', [2, 3, 4]),

    # 21. Double Wing
    ('Double Wing', '''
#######
#     ###
#  #    #
#  #  # #
###     #
  #######
''', [3, 4]),

    # 22. Central Pillar Yard
    ('Pillar Yard', '''
  #######
###     #
#   #   #
#   #   #
#     ###
#######
''', [2, 3, 4])
]

def generate_puzzles(template_str, name, num_crates, count=5, min_moves=8, max_moves=60):
    lines = [l.rstrip() for l in template_str.strip('\n').split('\n')]
    height = len(lines)
    width = max(len(l) for l in lines)
    walls = set()
    floor = set()
    possible_goals = []
    
    for r in range(height):
        line = lines[r]
        for c in range(len(line)):
            ch = line[c]
            if ch == '#': walls.add((r, c))
            elif ch == ' ': floor.add((r, c))
            elif ch == '.':
                floor.add((r, c))
                possible_goals.append((r, c))
                
    if len(possible_goals) < num_crates:
        possible_goals = list(floor)
        
    found = []
    attempts = 0
    max_attempts = 120
    while len(found) < count and attempts < max_attempts:
        attempts += 1
        goals = tuple(sorted(random.sample(possible_goals, num_crates)))
        crates = list(goals)
        player_candidates = []
        for cr in crates:
            for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                p = (cr[0] + dr, cr[1] + dc)
                if p in floor and p not in crates:
                    player_candidates.append(p)
        if not player_candidates: continue
        cur_p = random.choice(player_candidates)
        cur_crates = list(crates)
        
        # Pull walk
        num_pulls = random.randint(25, 120)
        for _ in range(num_pulls):
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
                    
            if pulls and random.random() < 0.70:
                c_pos, p_next = random.choice(pulls)
                cur_crates.remove(c_pos)
                cur_crates.append(cur_p)
                cur_p = p_next
            elif walks:
                cur_p = random.choice(walks)
            else:
                break
                
        if set(cur_crates) == set(goals):
            continue
            
        res = solve_forward(walls, floor, goals, cur_p, cur_crates, max_states=30000)
        if res and res['solvable'] and min_moves <= res['moves'] <= max_moves:
            grid_lines = format_grid(lines, walls, goals, cur_p, cur_crates)
            
            # Composite difficulty
            floor_len = max(len(floor), 1)
            tightness = num_crates / (floor_len / 4.0)
            push_density = res['pushes'] / float(max(res['moves'], 1))
            score = (res['moves'] * 0.8) + (res['pushes'] * 1.2) + (num_crates * 6.0) + (push_density * 10.0) + (tightness * 15.0)
            
            puzzle_obj = {
                'name': name,
                'moves': res['moves'],
                'pushes': res['pushes'],
                'states': res['states'],
                'crates': num_crates,
                'path': res['path'],
                'score': score,
                'lines': grid_lines
            }
            # Avoid duplicate layouts or exact same moves/pushes in same template
            if not any(p['moves'] == res['moves'] and p['pushes'] == res['pushes'] and p['crates'] == num_crates for p in found):
                found.append(puzzle_obj)
    return found

print("Generator functions ready.")

def run_campaign_generation():
    print("Generating candidate puzzle pool across templates...")
    pool = []
    
    # Handcrafted tutorials
    tutorials = [
        # L1: 1 crate, 5 moves
        {
            'name': 'Tutorial 1 - Straight Push',
            'crates': 1,
            'lines': [
                '######',
                '#   .#',
                '# $  #',
                '# @  #',
                '#    #',
                '######'
            ]
        },
        # L2: 1 crate, 8 moves
        {
            'name': 'Tutorial 2 - Around the Bend',
            'crates': 1,
            'lines': [
                ' #####',
                ' #   #',
                ' # $ #',
                '## # ###',
                '#   .  #',
                '# @ ####',
                '####'
            ]
        },
        # L3: 2 crates, 10 moves
        {
            'name': 'Tutorial 3 - Dual Cargo',
            'crates': 2,
            'lines': [
                '  #####',
                '###   #',
                '# $ . #',
                '# @# ##',
                '# $ . #',
                '#######'
            ]
        },
        # L4: 2 crates, 10 moves (slightly more tactical)
        {
            'name': 'Tutorial 4 - Clear the Way',
            'crates': 2,
            'lines': [
                '#####',
                '#   #',
                '#   ###',
                '# $   #',
                '# @ ###',
                '# $ #',
                '# ..#',
                '#####'
            ]
        }
    ]
    
    solved_tutorials = []
    for t in tutorials:
        lines = t['lines']
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
        res = solve_forward(walls, floor, goals, player, crates)
        assert res is not None
        score = (res['moves'] * 0.8) + (res['pushes'] * 1.2) + (t['crates'] * 6.0)
        solved_tutorials.append({
            'name': t['name'],
            'moves': res['moves'],
            'pushes': res['pushes'],
            'states': res['states'],
            'crates': t['crates'],
            'path': res['path'],
            'score': score,
            'lines': lines
        })
        print(f"Tutorial '{t['name']}': {res['moves']} moves, {res['pushes']} pushes")

    # Generate across templates
    t0 = time.time()
    for name, tmpl, crate_opts in TEMPLATES:
        for num_c in crate_opts:
            puzs = generate_puzzles(tmpl, name, num_c, count=4, min_moves=11, max_moves=55)
            pool.extend(puzs)
            print(f"  Template '{name}' ({num_c} crates): generated {len(puzs)} puzzles")
    
    print(f"\nGenerated pool size: {len(pool)} puzzles in {time.time()-t0:.1f}s")
    
    # Target slots specification for levels 5 to 50 (indices 4 to 49)
    # Each slot defines (min_crates, max_crates, target_moves_min, target_moves_max, is_peak, is_breather)
    slots = [
        # L5
        (2, 2, 12, 14, False, False),
        # L6
        (2, 2, 13, 15, False, False),
        # L7 (Intro 3 crates)
        (3, 3, 13, 15, False, False),
        # L8
        (3, 3, 15, 17, False, False),
        # L9
        (3, 3, 16, 18, False, False),
        # L10 (Cargo Bay Peak)
        (3, 3, 18, 20, True, False),
        # L11 (Cargo Bay Breather)
        (2, 3, 14, 15, False, True),
        # L12
        (3, 3, 16, 18, False, False),
        # L13
        (3, 3, 17, 19, False, False),
        # L14 (Intro 4 crates)
        (4, 4, 18, 20, False, False),
        # L15 (Cargo Bay Finale)
        (4, 4, 20, 22, True, False),
        
        # --- CHAPTER 1: COLD STORAGE (L16-L35) ---
        # L16
        (3, 3, 16, 18, False, False),
        # L17
        (3, 3, 17, 19, False, False),
        # L18
        (3, 4, 18, 20, False, False),
        # L19
        (3, 4, 19, 21, False, False),
        # L20 (Cold Storage Peak 1)
        (4, 4, 21, 23, True, False),
        # L21 (Cold Storage Breather)
        (3, 3, 17, 19, False, True),
        # L22
        (3, 4, 19, 21, False, False),
        # L23
        (3, 4, 20, 22, False, False),
        # L24
        (4, 4, 21, 23, False, False),
        # L25
        (4, 4, 22, 24, False, False),
        # L26
        (4, 4, 23, 25, False, False),
        # L27
        (4, 4, 24, 26, False, False),
        # L28
        (4, 4, 25, 27, False, False),
        # L29
        (4, 4, 26, 28, False, False),
        # L30 (Cold Storage Peak 2)
        (4, 5, 27, 29, True, False),
        # L31 (Cold Storage Breather)
        (3, 4, 20, 22, False, True),
        # L32
        (4, 4, 24, 26, False, False),
        # L33
        (4, 4, 25, 27, False, False),
        # L34
        (4, 4, 26, 28, False, False),
        # L35 (Cold Storage Finale)
        (4, 5, 28, 30, True, False),
        
        # --- CHAPTER 2: CYBER DEPOT (L36-L50) ---
        # L36
        (3, 4, 23, 25, False, False),
        # L37
        (4, 4, 24, 26, False, False),
        # L38
        (4, 4, 25, 27, False, False),
        # L39
        (4, 4, 26, 28, False, False),
        # L40 (Cyber Depot Peak 1)
        (4, 5, 29, 31, True, False),
        # L41 (Cyber Depot Breather)
        (3, 4, 22, 24, False, True),
        # L42
        (4, 4, 26, 28, False, False),
        # L43
        (4, 4, 27, 29, False, False),
        # L44
        (4, 5, 28, 30, False, False),
        # L45
        (4, 5, 29, 31, False, False),
        # L46
        (4, 5, 30, 32, False, False),
        # L47
        (4, 5, 31, 33, False, False),
        # L48
        (4, 5, 32, 34, False, False),
        # L49 (Pre-Climax)
        (4, 5, 33, 35, False, False),
        # L50 (Grand Finale)
        (4, 5, 34, 40, True, False)
    ]
    
    selected_campaign = list(solved_tutorials)
    used_indices = set()
    last_template_name = ""
    
    for slot_idx, slot in enumerate(slots):
        min_c, max_c, m_min, m_max, is_peak, is_breather = slot
        level_num = len(selected_campaign) + 1
        
        # Find candidates matching criteria
        candidates = []
        for i, p in enumerate(pool):
            if i in used_indices:
                continue
            if min_c <= p['crates'] <= max_c and m_min <= p['moves'] <= m_max:
                penalty = 0
                if p['name'] == last_template_name:
                    penalty += 50 # Disfavor same consecutive template
                candidates.append((penalty, p['score'], i, p))
                
        # If strict window has no candidate, relax move window slightly
        if not candidates:
            for i, p in enumerate(pool):
                if i in used_indices:
                    continue
                if min_c <= p['crates'] <= max_c and (m_min - 2) <= p['moves'] <= (m_max + 2):
                    penalty = 10
                    if p['name'] == last_template_name:
                        penalty += 50
                    candidates.append((penalty, p['score'], i, p))
                    
        # If still empty, relax crate count
        if not candidates:
            for i, p in enumerate(pool):
                if i in used_indices:
                    continue
                if (m_min - 3) <= p['moves'] <= (m_max + 3):
                    penalty = 25
                    candidates.append((penalty, p['score'], i, p))
                    
        assert candidates, f"No candidates found for level {level_num}!"
        candidates.sort(key=lambda x: (x[0], x[1])) # Pick lowest penalty, best score
        chosen_idx = candidates[0][2]
        chosen_puzzle = candidates[0][3]
        
        used_indices.add(chosen_idx)
        last_template_name = chosen_puzzle['name']
        selected_campaign.append(chosen_puzzle)
        print(f"Lvl {level_num:02d}: {chosen_puzzle['name']:18s} | {chosen_puzzle['crates']} crates | {chosen_puzzle['moves']} moves | {chosen_puzzle['pushes']} pushes")

    print(f"\nSuccessfully selected all 50 campaign levels!")
    optimal_moves = [p['moves'] for p in selected_campaign]
    print(f"Optimal moves array: {optimal_moves}")
    
    # Save to disk
    os.makedirs('/home/snowz/godot/levels', exist_ok=True)
    for idx, p in enumerate(selected_campaign):
        lvl_num = idx + 1
        path = f'/home/snowz/godot/levels/level_{lvl_num:02d}.sok'
        with open(path, 'w') as f:
            f.write('\n'.join(p['lines']) + '\n')
            
    print("All 50 level files written to /home/snowz/godot/levels/level_01.sok..level_50.sok")
    
    # Return optimal moves for save_manager.gd
    return optimal_moves

if __name__ == '__main__':
    run_campaign_generation()
