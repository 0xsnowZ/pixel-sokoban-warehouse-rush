#!/usr/bin/env python3
"""
tools/apply_difficulty_scaling.py
Executes the approved 75-stage campaign difficulty progression overhaul.
Remaps all 75 levels so difficulty strictly scales from Stage 1 to Stage 75.
Synchronizes levels/*.sok, levels/solutions.json, scripts/level_data.gd, and scripts/save_manager.gd.
"""

import json
import os
import re

MAPPING = [
    # Slot 01-15 (Chapter 1: Cargo Bay - Score 39.0 to 64.0)
    1, 2, 3, 68, 60, 23, 62, 4, 74, 75,
    65, 72, 56, 9, 24,
    # Slot 16-35 (Chapter 2: Cold Storage - Score 64.0 to 75.0)
    58, 8, 71, 55, 22, 15, 70, 11, 7, 63,
    21, 5, 6, 66, 57, 10, 61, 73, 26, 13,
    # Slot 36-50 (Chapter 3: Cyber Depot - Score 76.0 to 89.5)
    18, 43, 67, 25, 12, 69, 59, 19, 14, 54,
    27, 37, 28, 52, 51,
    # Slot 51-75 (Chapter 4: Quantum Vault - Score 89.5 to 212.5)
    53, 16, 29, 17, 20, 64, 33, 31, 32, 30,
    36, 34, 35, 40, 38, 41, 39, 47, 42, 48,
    45, 44, 50, 49, 46
]

assert len(MAPPING) == 75, f"Mapping has {len(MAPPING)} items, expected 75"
assert len(set(MAPPING)) == 75, f"Mapping has duplicate levels: {len(set(MAPPING))} unique"

print("1. Reading original levels and solutions into memory...")
orig_levels = {}
for i in range(1, 76):
    path = f"levels/level_{i:02d}.sok"
    with open(path, "r", encoding="utf-8") as f:
        orig_levels[i] = f.read().strip("\r\n")

with open("levels/solutions.json", "r", encoding="utf-8") as f:
    orig_solutions = json.load(f)

# Build remapped datasets
remapped_levels = {}
remapped_solutions = {}
optimal_moves = []

for new_slot, orig_lvl in enumerate(MAPPING, start=1):
    level_txt = orig_levels[orig_lvl]
    sol_str = orig_solutions[str(orig_lvl)]
    remapped_levels[new_slot] = level_txt
    remapped_solutions[str(new_slot)] = sol_str
    optimal_moves.append(len(sol_str))

print("2. Writing reordered levels/level_XX.sok...")
for slot in range(1, 76):
    path = f"levels/level_{slot:02d}.sok"
    with open(path, "w", encoding="utf-8") as f:
        f.write(remapped_levels[slot] + "\n")

print("3. Writing reordered levels/solutions.json...")
with open("levels/solutions.json", "w", encoding="utf-8") as f:
    json.dump(remapped_solutions, f, indent=2)

print("4. Updating scripts/level_data.gd with embedded levels...")
level_data_lines = [
    "## Embedded fallback data for all 75 Sokoban levels.",
    "## Ensures levels always load on any platform or export package.",
    "",
    "const LEVELS: Dictionary = {"
]

for slot in range(1, 76):
    txt = remapped_levels[slot]
    level_data_lines.append(f"\t{slot}: '{txt}',")

level_data_lines.append("}")
level_data_lines.append("")
level_data_lines.append("static func get_level_text(level_num: int) -> String:")
level_data_lines.append("\treturn LEVELS.get(level_num, \"\")")
level_data_lines.append("")

with open("scripts/level_data.gd", "w", encoding="utf-8") as f:
    f.write("\n".join(level_data_lines))

print("5. Updating scripts/save_manager.gd with OPTIMAL_MOVES...")
with open("scripts/save_manager.gd", "r", encoding="utf-8") as f:
    save_mgr_content = f.read()

# Format optimal_moves in rows of 10
opt_lines = []
for i in range(0, len(optimal_moves), 10):
    chunk = optimal_moves[i:i+10]
    opt_lines.append("\t" + ", ".join(str(m) for m in chunk) + ("," if i + 10 < len(optimal_moves) else ""))

replacement_block = "# Mathematically verified optimal moves for all 75 levels\nconst OPTIMAL_MOVES: Array[int] = [\n" + "\n".join(opt_lines) + "\n]"

pattern = r"# Mathematically verified optimal moves for all 75 levels\s+const OPTIMAL_MOVES: Array\[int\] = \[[^\]]+\]"
new_save_mgr = re.sub(pattern, replacement_block, save_mgr_content)
assert new_save_mgr != save_mgr_content, "Failed to match OPTIMAL_MOVES block in save_manager.gd!"

with open("scripts/save_manager.gd", "w", encoding="utf-8") as f:
    f.write(new_save_mgr)

print("Migration applied successfully!")
print("New OPTIMAL_MOVES:")
print(replacement_block)

