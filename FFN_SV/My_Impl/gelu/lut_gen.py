import numpy as np
from scipy.special import erf

def true_gelu(x):
    return x * 0.5 * (1 + erf(x / np.sqrt(2)))

boundaries = np.linspace(-4.0, 4.0, 33)  # 33 points = 32 segments

print(boundaries)

#Okay because each has a left and right point and we need the slope and y intercpet 
# y = mx + c       m = y2-1/x2-x1

M_LUT = []
C_LUT = []

for i in range(32):
    
    x1, x2 = boundaries[i], boundaries[i + 1]
    
    y1, y2 = true_gelu(x1), true_gelu(x2)
    
    y_diff = (y2-y1)
    x_diff = (x2-x1)
    
    m = y_diff/x_diff
    
    c = y1 - (m * x1)
    
    M_LUT.append(m)
    C_LUT.append(c)


def to_bf16(arry):
    slope_arr = np.array(arry, dtype=np.float32)
    bits = slope_arr.view(np.uint32)
    bf16 = (bits >> 16).astype(np.uint16)
    return bf16 

slopes = to_bf16(M_LUT)
intercept = to_bf16(C_LUT)

slopes_hex = [hex(x) for x in slopes]
intercept_hex = [hex(y) for y in intercept]

print(slopes_hex)
print(intercept_hex)