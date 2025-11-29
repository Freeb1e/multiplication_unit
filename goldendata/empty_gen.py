import numpy as np
import os

# --- 1. 定义配置 ---
ROWS = 1344
COLS = 8
DTYPE = np.uint16
MOD_MASK = 2**16  # 65536

FILE_BIN = 'B_matrix.bin'
FILE_TXT = 'B_matrix.txt'

print(f"--- B 矩阵生成器 (顺序序列) ---")
print(f"维度: ({ROWS}, {COLS})")
print(f"类型: {DTYPE.__name__} (16-bit)")
print("-" * 50)

# --- 2. 生成序列数据 ---
total_elements = ROWS * COLS
print(f"正在生成 {total_elements} 个顺序数据 (1, 2, 3...)...")

# 生成从 1 到 total_elements 的序列
# 注意：arange 的终点是开区间，所以要 +1
raw_sequence = np.arange(1, total_elements + 1, dtype=np.uint32)

# 执行取模操作 (虽然 10752 不会超过 65536，但为了逻辑严谨加上)
raw_sequence_mod = raw_sequence % MOD_MASK 

# 转换为 uint16 并重塑为矩阵形状
B_matrix = raw_sequence_mod.astype(DTYPE).reshape((ROWS, COLS))

print(f"✅ B 矩阵生成完毕。")
print(f"   B[0,0]    = {B_matrix[0,0]}")
print(f"   B[0,1]    = {B_matrix[0,1]}")
print(f"   B[End,End]= {B_matrix[-1,-1]}")

# --- 3. 保存文件 ---

# 保存 .bin (机器码，行优先存储)
B_matrix.tofile(FILE_BIN)
print(f"\n✅ 已保存二进制文件: {FILE_BIN} ({os.path.getsize(FILE_BIN)} bytes)")

# 保存 .txt (人类可读)
header_txt = f'B Matrix Sequence ({ROWS}x{COLS})\nValues: 1, 2, ..., {total_elements}'
np.savetxt(FILE_TXT, B_matrix, fmt='%5d', delimiter=' ', header=header_txt)
print(f"✅ 已保存文本文件:   {FILE_TXT}")

print("-" * 50)
print("完成。")