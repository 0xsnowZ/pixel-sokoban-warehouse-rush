from PIL import Image
import numpy as np

im = Image.open('/home/snowz/godot/ref_levels/14.jpeg').convert('RGB')
arr = np.array(im)

# Let's test grid origins
# In 14.jpeg, bottom row ends right before cyan bar (y=236)
# If dy ~ 24, 236 - 9*24 = 20. Exactly 20!
# Along x, w=314. Left margin ~ 50, right ~ 266, (266-50)/9 = 24.
# Let's test y0 in [18, 20, 22], x0 in [45, 48, 51], step ~ 23.5..24.5
y0 = 20
x0 = 48
step_y = (235 - 20) / 9.0
step_x = (265 - 48) / 9.0

print(f"step_x={step_x:.2f}, step_y={step_y:.2f}")

for r in range(9):
    row_str = ""
    for c in range(9):
        cy = int(y0 + (r + 0.5) * step_y)
        cx = int(x0 + (c + 0.5) * step_x)
        rgb = arr[cy-3:cy+4, cx-3:cx+4].mean(axis=(0,1))
        # classify
        # Blue circle:
        if rgb[2] > 130 and rgb[2] > rgb[0] + 50:
            row_str += " . "
        elif rgb[0] > 70 and rgb[1] > 100 and rgb[2] > 80: # Crate
            row_str += " $ "
        elif rgb[1] > 110 and rgb[1] > rgb[0] + 30: # Grass
            row_str += "   "
        elif rgb[0] > 80 and rgb[2] > 70: # Brick wall
            row_str += " # "
        elif rgb[0] < 50 and rgb[2] < 70 and rgb[1] < 100: # Tree
            row_str += " T "
        elif rgb[1] > 80 and rgb[2] > 100: # Player
            row_str += " @ "
        else:
            row_str += " ? "
    print(f"R{r}: {row_str}")

