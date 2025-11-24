import numpy as np
import os

# --- 1. 定义矩阵维度 ---
ROWS_A_BUFF = 4
COMMON_DIM = 1344
COLS_S = 4  # S 的列数

# --- 2. 定义数据类型 (DTypes) ---
DTYPE_A = np.uint16  # A_buffer 是 16-bit
DTYPE_S = np.uint8   # S 是 8-bit
DTYPE_C = np.uint16  # 结果 C 是 16-bit

print(f"--- FrodoKEM A*S (混合精度) 仿真数据生成器 ---")
print(f"配置维度:")
print(f"  A_buffer (A的4行): ({ROWS_A_BUFF}, {COMMON_DIM}) [类型: {DTYPE_A.__name__}]")
print(f"  S 矩阵 (逻辑维度):  ({COMMON_DIM}, {COLS_S})    [类型: {DTYPE_S.__name__}]")
print(f"  C 结果:             ({ROWS_A_BUFF}, {COLS_S})      [类型: {DTYPE_C.__name__}]")
print("-" * 50)

# --- 3. 生成随机测试数据 ---
np.random.seed(42) # 固定随机种子

# 生成 A_buffer 矩阵，元素范围 [0, 2**16 - 1]
A_buffer = np.random.randint(0, 2**16, 
                            size=(ROWS_A_BUFF, COMMON_DIM), 
                            dtype=DTYPE_A)

# 生成 S 矩阵 (逻辑上是 1344x4)，元素范围 [0, 2**8 - 1]
S = np.random.randint(0, 2**8, 
                    size=(COMMON_DIM, COLS_S), 
                    dtype=DTYPE_S)

print("✅ 成功生成 A_buffer 和 S 测试数据。")
print(f"  A_buffer.shape: {A_buffer.shape}")
print(f"  S.shape:        {S.shape}")

# --- 4. 计算预期的“黄金”结果 ---
# C = A_buffer * S
# 注意：这里计算依然使用逻辑维度 (1344x4)，不受存储顺序影响
A_buffer_64 = A_buffer.astype(np.uint64)
S_64 = S.astype(np.uint64)

C_result_64 = np.dot(A_buffer_64, S_64)
C_result_mod = C_result_64 % (2**16)
C_result = C_result_mod.astype(DTYPE_C)

print("\n--- 预期计算结果 (C = A * S mod 2^16) ---")
print(f"C_result.shape: {C_result.shape}")
print(C_result)
print("-" * 50)

# ==========================================================
# --- 5. [重点修改] 将输入矩阵存入 .bin 文件 ---
# ==========================================================
file_A = 'A_buffer.bin'
file_S = 'S_transposed.bin' # 改名以体现存储结构
file_C_golden = 'C_golden.bin'

# 1. 保存 A (行优先，默认)
A_buffer.tofile(file_A)

# 2. 保存 S (列优先 / 转置存储)
# 逻辑 S 是 (1344, 4)。
# 我们需要按 S 的列来存储，也就是先存 Column 0，再存 Column 1...
# 这等价于保存 S 的转置 (S.T) 的行。
# S.T 的形状是 (4, 1344)。
S_transpose_view = np.ascontiguousarray(S.T) # 必须确保内存连续
S_transpose_view.tofile(file_S)

# 3. 保存 Golden C
C_result.tofile(file_C_golden)

print(f"✅ 机器文件(.bin)已保存:")
print(f"  -> {file_A} ({os.path.getsize(file_A)} bytes)")
print(f"     [存储顺序: 行优先 A[0,0], A[0,1]...]")
print(f"  -> {file_S} ({os.path.getsize(file_S)} bytes)")
print(f"     [存储顺序: **S的转置** / 列优先 S[0,0], S[1,0], S[2,0]...]")
print(f"  -> {file_C_golden} ({os.path.getsize(file_C_golden)} bytes)")

# ==========================================================
# --- 6. 将矩阵存入 .txt 文件 (人类阅读 - 保持逻辑形状) ---
# ==========================================================
file_A_txt = 'A_buffer.txt'
file_S_txt = 'S.txt'
file_C_txt = 'C_golden.txt'

print("\n--- 正在生成人类可读的十进制文本文件 (.txt) ---")

np.savetxt(file_A_txt, A_buffer, fmt='%6d', delimiter=' ', header=f'A_buffer Decimal ({ROWS_A_BUFF}x{COMMON_DIM})')
# S 依然保存为 1344x4 的样子，方便人类对照公式理解，但在 Header 中注明了 Bin 文件的不同
header_S = f'S Matrix Logical View ({COMMON_DIM}x{COLS_S})\nNOTE: The .bin file is TRANSPOSED ({COLS_S}x{COMMON_DIM})'
np.savetxt(file_S_txt, S, fmt='%4d', delimiter=' ', header=header_S)

np.savetxt(file_C_txt, C_result, fmt='%6d', delimiter=' ', header=f'C Result ({ROWS_A_BUFF}x{COLS_S})')

print(f"  -> {file_A_txt}")
print(f"  -> {file_S_txt}")
print(f"  -> {file_C_txt}")
print("-" * 50)

# ==========================================================
# --- 7. C[0,0] 逐步累加调试 (每步取模) ---
# ==========================================================
debug_file_mod = 'debug_trace_C00_mod_step.txt'

row_vec = A_buffer[0, :].astype(np.uint64)
col_vec = S[:, 3].astype(np.uint64) # 取 S 的第0列，这在 bin 文件中是存储在最开头的那一段数据

accumulator_16bit = 0
common_dim_len = len(row_vec)
mod_mask = 2**16

print(f"\n--- 正在生成 C[0,0] 逐步累加轨迹 (每一步都 Mod 2^16) ---")
with open(debug_file_mod, 'w') as f:
    header = (f"{'Step':<6} | {'A_val':<6} | {'S_val':<6} | "
              f"{'Prod(Full)':<12} | {'Acc(Dec)':<10} | {'Acc(Hex)':<8}")
    f.write(header + "\n")
    f.write("-" * len(header) + "\n")
    
    for k in range(common_dim_len):
        val_a = row_vec[k]
        val_s = col_vec[k]
        product = val_a * val_s
        accumulator_16bit = (accumulator_16bit + product) % mod_mask
        
        line = (f"{k:<6d} | {val_a:<6d} | {val_s:<6d} | "
                f"{product:<12d} | {accumulator_16bit:<10d} | {accumulator_16bit:04X}")
        f.write(line + "\n")

print(f"✅ 调试日志已保存到: '{debug_file_mod}'")
print(f"   验证: Bin文件中 S 的前 {common_dim_len} 个字节对应 S[0..1343, 0]")