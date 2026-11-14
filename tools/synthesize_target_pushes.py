#!/usr/bin/env python3
"""
tools/synthesize_target_pushes.py
Synthesizes compact high-difficulty puzzles specifically for P=12, P=14, and P=15.
"""

import sys
import os
import json
import time
import random

sys.path.insert(0, "tools")
sys.path.insert(0, "/home/snowz/.gemini/antigravity/brain/db19d3e6-5897-4bec-b12d-4a1222e63add/scratch")

from new_level_generator import TEMPLATES
from generate_all_templates import MORE_TEMPLATES, rot90, get_interior_floor
from synthesize_compact_hard_puzzles import synthesize_compact_retro

def main():
    pool_path = "/home/snowz/.gemini/antigravity/brain/db19d3e6-5897-4bec-b12d-4a1222e63add/scratch/proper_watertight_generated.json"
    with open(pool_path) as f:
        pool = json.load(f)

    seen = set("\n".join(c["lines"]) for c in pool)
    print(f"Current pool: {len(pool)} items")

    all_templates = []
    for name, tmpl, _ in TEMPLATES[1:]:
        all_templates.append((name, tmpl))
    for name, tmpl in MORE_TEMPLATES:
        all_templates.append((name, tmpl))

    compact_templates = []
    for name, tmpl in all_templates:
        lines0 = [l.rstrip() for l in tmpl.strip("\n").split("\n")]
        _, fl, _, _ = get_interior_floor(lines0)
        if 14 <= len(fl) <= 24:
            compact_templates.append((name, tmpl))

    variants = []
    for name, tmpl in compact_templates:
        lines0 = [l.rstrip() for l in tmpl.strip("\n").split("\n")]
        variants.append((f"{name}_0", lines0))
        variants.append((f"{name}_90", rot90(lines0)))
        variants.append((f"{name}_180", rot90(rot90(lines0))))
        variants.append((f"{name}_270", rot90(rot90(rot90(lines0)))))

    random.seed(555)
    random.shuffle(variants)

    targets = [12, 14, 15]
    for target_p in targets:
        added = 0
        print(f"\n--- Synthesizing for target P={target_p} ---")
        for vname, vlines in variants:
            cand = synthesize_compact_retro(vname, vlines, 4, min_pushes=target_p, max_attempts=12)
            if cand and cand["pushes"] == target_p:
                sig = "\n".join(cand["lines"])
                if sig not in seen:
                    seen.add(sig)
                    pool.append(cand)
                    added += 1
                    print(f"  + P={target_p} [{added}]: {cand['source']} (d={cand['density']:.2f}, mw={cand['max_walk']})")
                    if added >= 8:
                        break
        print(f"Added {added} candidates for P={target_p}")

    with open(pool_path, "w") as f:
        json.dump(pool, f, indent=2)
    print(f"\nSaved updated pool with {len(pool)} total items.")

if __name__ == "__main__":
    main()
