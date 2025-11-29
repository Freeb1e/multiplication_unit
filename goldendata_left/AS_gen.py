import numpy as np
import os

# ==========================================================
# --- 1. 定义矩阵维度 (FrodoKEM-640 dimensions) ---
# ==========================================================
# A 现在是全尺寸方阵
ROWS_A      = 1344 
COMMON_DIM  = 1344
COLS_S      = 8    # S 的列数 (batch size usually 8)

# --- 2. 定义数据类型 (DTypes) ---
DTYPE_A = np.uint16  # A 是 16-bit
DTYPE_S = np.uint8   # S 是 8-bit
DTYPE_C = np.uint16  # 结果 C 是 16-bit

print(f"--- FrodoKEM Full Matrix 仿真数据生成器 ---")
print(f"配置维度:")
print(f"  A 矩阵 (完整):      ({ROWS_A}, {COMMON_DIM})   [类型: {DTYPE_A.__name__}]")
print(f"  S 矩阵 (逻辑):      ({COMMON_DIM}, {COLS_S})      [类型: {DTYPE_S.__name__}]")
print(f"  C 结果 (A * S):     ({ROWS_A}, {COLS_S})      [类型: {DTYPE_C.__name__}]")
print("-" * 50)

# ==========================================================
# --- 3. 生成随机测试数据 ---
# ==========================================================
np.random.seed(42) # 固定随机种子

print("正在生成数据 (这可能需要几秒钟)...")

# 1. 生成完整 A 矩阵 (1344 x 1344)
# 范围 [0, 2**16 - 1]
A_full = np.random.randint(0, 2**16, 
                           size=(ROWS_A, COMMON_DIM), 
                           dtype=DTYPE_A)

# 2. 生成 S 矩阵 (逻辑上是 1344 x 8)
# 范围 [0, 2**8 - 1]
S = np.random.randint(0, 2**8, 
                      size=(COMMON_DIM, COLS_S), 
                      dtype=DTYPE_S)

print("✅ 数据生成完毕。")
print(f"  A_full.shape: {A_full.shape} (约 {A_full.nbytes / 1024 / 1024:.2f} MB)")
print(f"  S.shape:      {S.shape}")

# ==========================================================
# --- 4. 计算预期的“黄金”结果 ---
# ==========================================================
# C = A * S
print("\n正在计算 Golden Result (矩阵乘法)...")
# 为了防止溢出，先转为 uint64 计算，然后模 2^16
A_64 = A_full.astype(np.uint64)
S_64 = S.astype(np.uint64)

C_result_64 = np.dot(A_64, S_64)
C_result_mod = C_result_64 % (2**16)
C_result = C_result_mod.astype(DTYPE_C)

print("✅ 计算完成。")
print(f"  C_result.shape: {C_result.shape}")

# ==========================================================
# --- 5. 生成机器文件 (.bin) ---
# ==========================================================
file_A = 'A_full.bin'
file_S = 'S_tr.bin' # 文件名注明了实际存储结构
file_C = 'C_full_1344x8.bin'

print(f"\n--- 保存二进制文件 (.bin) ---")

# 1. 保存 A (行优先，默认)
# A[0,0], A[0,1] ... A[0,1343], A[1,0] ...
A_full.tofile(file_A)

# 2. 保存 S (重点：转置存储 / 列优先)
# 逻辑 S 是 (1344, 8)。为了硬件读取方便（连续读一列），我们存 S.T
# 存储顺序: S[0,0], S[1,0]... S[1343,0], S[0,1]...
S_transpose_view = np.ascontiguousarray(S.T)
S_transpose_view.tofile(file_S)

# 3. 保存 C
C_result.tofile(file_C)

print(f"  -> {file_A} ({os.path.getsize(file_A)} bytes)")
print(f"     [存储: 行优先]")
print(f"  -> {file_S} ({os.path.getsize(file_S)} bytes)")
print(f"     [存储: **S的转置** / 列优先, 物理顺序为 Column 0, Column 1...]")
print(f"  -> {file_C} ({os.path.getsize(file_C)} bytes)")

# ==========================================================
# --- 6. 生成文本文件 (.txt) ---
#    注意：A 矩阵很大，写入 txt 会比较慢且文件很大
# ==========================================================
file_A_txt = 'A_full.txt'
file_S_txt = 'S_logical.txt'
file_C_txt = 'C_result.txt'

print("\n--- 正在生成人类可读文本 (.txt) ---")
print("  注意: A_full.txt 会比较大 (~10MB)，请耐心等待...")

# 保存 A (完整)
header_A = f'A Matrix Full ({ROWS_A}x{COMMON_DIM})'
np.savetxt(file_A_txt, A_full, fmt='%6d', delimiter=' ', header=header_A)

# 保存 S (逻辑形状 1344x8)
header_S = f'S Matrix Logical View ({COMMON_DIM}x{COLS_S})\nNOTE: The .bin file is TRANSPOSED ({COLS_S}x{COMMON_DIM})'
np.savetxt(file_S_txt, S, fmt='%4d', delimiter=' ', header=header_S)

# 保存 C
header_C = f'C Result Full ({ROWS_A}x{COLS_S})'
np.savetxt(file_C_txt, C_result, fmt='%6d', delimiter=' ', header=header_C)

print(f"  -> {file_A_txt}")
print(f"  -> {file_S_txt}")
print(f"  -> {file_C_txt}")

# ==========================================================
# --- 7. 生成 C[0,0] 详细调试 Trace ---
# ==========================================================
debug_file = 'debug_trace_C00.txt'

# C[0,0] 只与 A 的第0行 和 S 的第0列 有关
row_vec = A_full[0, :].astype(np.uint64)
col_vec = S[:, 0].astype(np.uint64)

accumulator = 0
mod_mask = 2**16

print(f"\n--- 正在生成 C[0,0] 累加轨迹 ---")
with open(debug_file, 'w') as f:
    header = (f"{'Step':<6} | {'A_val':<6} | {'S_val':<6} | "
              f"{'Prod':<12} | {'Acc(Dec)':<10} | {'Acc(Hex)':<8}")
    f.write(header + "\n")
    f.write("-" * len(header) + "\n")
    
    for k in range(COMMON_DIM):
        val_a = int(row_vec[k])
        val_s = int(col_vec[k])
        
        product = val_a * val_s
        accumulator = (accumulator + product) % mod_mask
        
        f.write(f"{k:<6d} | {val_a:<6d} | {val_s:<6d} | "
                f"{product:<12d} | {accumulator:<10d} | {accumulator:04X}\n")

print(f"✅ 调试日志已保存: '{debug_file}'")
print(f"   (用于验证硬件乘加器第一行第一列的计算过程)")
print("所有任务完成。")