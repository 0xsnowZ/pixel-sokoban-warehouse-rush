import sys
import time
from collections import deque
from tools.test_ref_architectures import solve_grid

def test_variations():
    candidates = []

    # 1. Bay 2x2 Family
    # Variations in width (7 to 9), loop height (1 or 2), player pos, crate offsets
    for w in [7, 8, 9]:
        for loop_h in [1, 2]:
            for bay_side in ['left', 'right', 'center']:
                lines = []
                top_wall = "#" * w
                lines.append(top_wall)
                for _ in range(loop_h):
                    lines.append("#" + " " * (w - 2) + "#")
                
                # Crate row: 3 or 4 crates
                # If w=7: 3 crates; if w=8: 3 or 4 crates; if w=9: 4 crates
                cr_cnt = 4
                cr_str = "$" * cr_cnt
                rem = (w - 2) - cr_cnt
                if rem < 0: continue
                # Place cr_str
                for cr_offset in range(rem + 1):
                    mid = "#" + " " * cr_offset + cr_str + " " * (rem - cr_offset) + "#"
                    
                    # Bay row 1 and 2
                    # We need 4 goals in 2x2
                    for bay_offset in range(w - 2 - 2 + 1):
                        g_row1 = list("#" + " " * (w - 2) + "#")
                        g_row2 = list("#" + " " * (w - 2) + "#")
                        g_row1[1 + bay_offset] = '.'
                        g_row1[2 + bay_offset] = '.'
                        g_row2[1 + bay_offset] = '.'
                        g_row2[2 + bay_offset] = '.'
                        
                        # Add player in row 2 or row 1
                        for p_col in range(1, w - 1):
                            if p_col in [1 + bay_offset, 2 + bay_offset]: continue
                            g_row2_p = list(g_row2)
                            g_row2_p[p_col] = '@'
                            
                            grid = [top_wall]
                            for _ in range(loop_h):
                                grid.append("#" + " " * (w - 2) + "#")
                            grid.append(mid)
                            grid.append("".join(g_row1))
                            grid.append("".join(g_row2_p))
                            grid.append(top_wall)
                            
                            candidates.append(("Bay2x2", grid))

    print(f"Generated {len(candidates)} Bay2x2 candidate templates.")
    
    # Let's test a sample of them
    solved_list = []
    for tag, grid in candidates:
        res, msg = solve_grid(grid, max_states=40000)
        if res and res['moves'] >= 20 and res['pushes'] >= 8:
            solved_list.append((res['moves'], res['pushes'], res['states'], grid))
            if len(solved_list) >= 20:
                break
                
    print(f"Found {len(solved_list)} high-difficulty Bay2x2 levels!")
    for m, p, s, g in solved_list[:5]:
        print(f"\nSolved: {m}m, {p}p ({s} states)")
        for l in g:
            print(f"  {l}")

if __name__ == '__main__':
    test_variations()
