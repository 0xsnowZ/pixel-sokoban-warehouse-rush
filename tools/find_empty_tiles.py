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

print("Empty floor tiles in BASE_CHUTE:")
for r, line in enumerate(BASE_CHUTE):
    for c, ch in enumerate(line):
        if ch in ' @':
            print(f"({r}, {c}): '{ch}'")

def flip_h(lines): return [l[::-1] for l in lines]
BASE_CHUTE_FLIP = flip_h(BASE_CHUTE)
print("\nEmpty floor tiles in BASE_CHUTE_FLIP:")
for r, line in enumerate(BASE_CHUTE_FLIP):
    for c, ch in enumerate(line):
        if ch in ' @':
            # Check if inside walls
            left_w = any(BASE_CHUTE_FLIP[r][x] == '#' for x in range(c))
            right_w = any(BASE_CHUTE_FLIP[r][x] == '#' for x in range(c+1, len(line)))
            if left_w and right_w:
                print(f"({r}, {c}): '{ch}'")
