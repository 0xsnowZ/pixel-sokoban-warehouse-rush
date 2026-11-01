import re

with open("scripts/localization_manager.gd", "r") as f:
    loc_code = f.read()

keys_in_loc = set(re.findall(r'"([A-Z0-9_]+)":\s*\{', loc_code))
print(f"Found {len(keys_in_loc)} keys in localization_manager.gd")

files_to_scan = [
    "scenes/game.gd",
    "scripts/main_menu.gd",
    "scenes/end_screen.gd",
    "scenes/splash_screen.gd",
    "scripts/achievement_manager.gd",
    "scripts/save_manager.gd"
]

missing = {}
for path in files_to_scan:
    with open(path, "r") as f:
        code = f.read()
    found_keys = re.findall(r'tr_text\("([A-Z0-9_]+)"', code)
    found_keys += re.findall(r'["\'](?:name_key|desc_key)["\']:\s*["\']([A-Z0-9_]+)["\']', code)
    
    for k in found_keys:
        if k not in keys_in_loc:
            if k not in missing:
                missing[k] = []
            missing[k].append(path)

print(f"\nMissing Translation Keys ({len(missing)} total):")
for k, paths in sorted(missing.items()):
    print(f"  - {k} (used in: {', '.join(set(paths))})")

