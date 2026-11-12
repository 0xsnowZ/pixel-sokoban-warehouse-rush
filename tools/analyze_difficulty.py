#!/usr/bin/env python3
import json
import glob
import os

with open("levels/solutions.json") as f:
    solutions = json.load(f)

print(f"{'Level':<6} | {'Size':<7} | {'Crates':<6} | {'Moves':<6} | {'Pushes':<6} | {'Solution'}")
print("-" * 75)

level_stats = []

for i in range(1, 76):
    sok_path = f"levels/level_{i:02d}.sok"
    if not os.path.exists(sok_path):
        print(f"Missing {sok_path}")
        continue
    
    with open(sok_path) as f:
        lines = [l.rstrip("\r\n") for l in f if l.strip()]
    
    h = len(lines)
    w = max(len(l) for l in lines)
    
    crates = 0
    goals = 0
    for row in lines:
        for ch in row:
            if ch in ['$', '*']:
                crates += 1
            if ch in ['.', '+', '*']:
                goals += 1
                
    sol = solutions.get(str(i), "")
    # In sokoban notation, sometimes pushes are uppercase, moves lowercase,
    # or all lowercase. Let's simulate the moves to count actual pushes!
    
    # Simulate on level
    grid = [list(l.ljust(w)) for l in lines]
    px, py = -1, -1
    for y in range(h):
        for x in range(w):
            if grid[y][x] in ['@', '+']:
                px, py = x, y
                break
        if px != -1:
            break
            
    pushes = 0
    moves = len(sol)
    
    # Direction map
    dmap = {
        'u': (0, -1), 'd': (0, 1), 'l': (-1, 0), 'r': (1, 0),
        'U': (0, -1), 'D': (0, 1), 'L': (-1, 0), 'R': (1, 0)
    }
    
    for ch in sol:
        dx, dy = dmap.get(ch, (0, 0))
        nx, ny = px + dx, py + dy
        if 0 <= ny < h and 0 <= nx < w:
            if grid[ny][nx] in ['$', '*']:
                pushes += 1
                bx, by = nx + dx, ny + dy
                # move crate
                grid[by][bx] = '*' if grid[by][bx] == '.' else '$'
                grid[ny][nx] = '.' if grid[ny][nx] == '*' else ' '
            px, py = nx, ny

    level_stats.append({
        "level": i,
        "width": w,
        "height": h,
        "crates": crates,
        "moves": moves,
        "pushes": pushes,
        "solution": sol
    })

for s in level_stats:
    print(f"{s['level']:<6} | {s['width']}x{s['height']:<4} | {s['crates']:<6} | {s['moves']:<6} | {s['pushes']:<6} | {s['solution'][:20]}...")

