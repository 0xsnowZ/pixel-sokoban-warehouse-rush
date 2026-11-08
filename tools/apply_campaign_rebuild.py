import json
import re

with open('/home/snowz/.gemini/antigravity/brain/f5ae7af8-879e-4866-bb7e-de37bc6d1ca9/scratch/all_29_synthesized.json') as f:
    synth_29 = json.load(f)

# 1. Update level files
for lvl_str, data in synth_29.items():
    lvl_num = int(lvl_str)
    path = f"levels/level_{lvl_num:02d}.sok"
    content = "\n".join(data['lines']) + "\n"
    with open(path, 'w') as f:
        f.write(content)
    print(f"Updated {path}")

# 2. Update solutions.json
with open('levels/solutions.json', 'r') as f:
    solutions = json.load(f)

for lvl_str, data in synth_29.items():
    solutions[lvl_str] = data['path'].lower()

with open('levels/solutions.json', 'w') as f:
    json.dump(solutions, f, indent=2)
print("Updated levels/solutions.json")

# 3. Update scripts/level_data.gd
with open('scripts/level_data.gd', 'r') as f:
    ld_text = f.read()

for lvl_str, data in synth_29.items():
    lvl_num = int(lvl_str)
    grid_txt = "\n".join(data['lines'])
    pattern = rf"(\t{lvl_num}:\s*')(.*?)(')"
    replacement = rf"\g<1>{grid_txt}\g<3>"
    ld_text = re.sub(pattern, replacement, ld_text, flags=re.DOTALL)

with open('scripts/level_data.gd', 'w') as f:
    f.write(ld_text)
print("Updated scripts/level_data.gd")

# 4. Update scripts/save_manager.gd OPTIMAL_MOVES
with open('scripts/save_manager.gd', 'r') as f:
    sm_text = f.read()

# Parse current OPTIMAL_MOVES
m_arr = re.search(r'const OPTIMAL_MOVES:\s*Array\[int\]\s*=\s*\[(.*?)\]', sm_text, re.DOTALL)
if m_arr:
    raw_nums = [int(x.strip()) for x in m_arr.group(1).replace('\n', ',').split(',') if x.strip()]
    print(f"Current OPTIMAL_MOVES has {len(raw_nums)} items")
    for lvl_str, data in synth_29.items():
        idx = int(lvl_str) - 1
        raw_nums[idx] = data['moves']

    # Format nicely in rows of 10
    rows = []
    for i in range(0, len(raw_nums), 10):
        chunk = raw_nums[i:i+10]
        rows.append("\t" + ", ".join(str(x) for x in chunk) + ("," if i+10 < len(raw_nums) else ""))
    new_arr_str = "const OPTIMAL_MOVES: Array[int] = [\n" + "\n".join(rows) + "\n]"
    sm_text = re.sub(r'const OPTIMAL_MOVES:\s*Array\[int\]\s*=\s*\[(.*?)\]', new_arr_str, sm_text, flags=re.DOTALL)
    with open('scripts/save_manager.gd', 'w') as f:
        f.write(sm_text)
    print("Updated scripts/save_manager.gd OPTIMAL_MOVES")

print("All campaign files updated successfully.")
