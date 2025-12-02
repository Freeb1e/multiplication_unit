import numpy as np
import os

# ==========================================================
# --- 1. 配置与加载数据 ---
# ==========================================================
ROWS_A      = 1344 
COMMON_DIM  = 1344
COLS_S_TR   = 1344 # S_tr 的列数
ROWS_S_TR   = 8    # S_tr 的行数 (即 Batch Size)

# 文件路径 (确保这些文件在当前目录下)
FILE_A = 'A_full.bin'
FILE_S = 'S_tr.bin'

print(f"--- 脉动阵列外积调试生成器 ---")

# 加载 A (1344 x 1344)
if not os.path.exists(FILE_A) or not os.path.exists(FILE_S):
    print(f"❌ 错误: 找不到 {FILE_A} 或 {FILE_S}。请先运行生成数据的脚本。")
    exit()

print(f"正在加载 {FILE_A} ...")
A_matrix = np.fromfile(FILE_A, dtype=np.uint16).reshape(ROWS_A, COMMON_DIM)

print(f"正在加载 {FILE_S} ...")
# S_tr 是 8 x 1344
S_tr_matrix = np.fromfile(FILE_S, dtype=np.uint8).reshape(ROWS_S_TR, COLS_S_TR)

print("✅ 数据加载完成。")

# ==========================================================
# --- 新增: 生成完整的 S_tr * A 结果 (Golden Reference) ---
# ==========================================================
print("\n正在计算完整的 S_tr * A 结果 (Golden Reference)...")
# 计算矩阵乘法: (8x1344) * (1344x1344) -> (8x1344)
# 使用 uint64 防止中间累加溢出
full_result_64 = np.dot(S_tr_matrix.astype(np.uint64), A_matrix.astype(np.uint64))
full_result = (full_result_64 % 65536).astype(np.uint16)

# 保存完整结果 (Hex)
with open('final_result.txt', 'w') as f:
    f.write("// Full Result Matrix (S_tr * A)\n")
    f.write(f"// Shape: {ROWS_S_TR} rows x {ROWS_A} columns\n")
    f.write("// Format: Hex uint16\n")
    
    # 打印列头
    f.write("      ")
    for c in range(16): f.write(f"Col_{c:<3} ")
    f.write("...\n")
    
    for r in range(ROWS_S_TR):
        f.write(f"Row_{r}: ")
        for c in range(ROWS_A):
            f.write(f"{full_result[r, c]:04X} ")
        f.write("\n")

# 保存完整结果 (Decimal)
with open('final_result_dec.txt', 'w') as f:
    f.write("// Full Result Matrix (S_tr * A)\n")
    f.write(f"// Shape: {ROWS_S_TR} rows x {ROWS_A} columns\n")
    f.write("// Format: Decimal uint16\n")
    
    # 打印列头
    f.write("      ")
    for c in range(16): f.write(f"Col_{c:<5} ")
    f.write("...\n")
    
    for r in range(ROWS_S_TR):
        f.write(f"Row_{r}: ")
        for c in range(ROWS_A):
            f.write(f"{full_result[r, c]:<6d} ")
        f.write("\n")

print(f"✅ 完整结果已保存至 'final_result.txt' 和 'final_result_dec.txt'")

# ==========================================================
# --- 2. 核心计算函数 (局部调试) ---
# ==========================================================
def calculate_partial_outer_product_sum(start_index, steps=4):
    """
    计算从 start_index 开始的 steps 个外积的和。
    公式: Sum = Sum_{k=i}^{i+steps-1} ( S_tr[:, k] * A[k, :] )
    """
    
    # 初始化累加器 (使用 uint32 防止溢出，最后再模)
    accumulator = np.zeros((ROWS_S_TR, ROWS_A), dtype=np.uint32)
    
    print(f"\n开始计算索引 i = {start_index} 到 {start_index + steps - 1} 的外积和 (共 {steps} 步)...")
    
    for k in range(start_index, start_index + steps):
        if k >= COMMON_DIM:
            print(f"⚠️ 警告: 索引 {k} 超出范围，跳过。")
            continue
            
        # 1. 获取向量
        s_vec = S_tr_matrix[:, k].astype(np.uint32).reshape(ROWS_S_TR, 1)
        a_vec = A_matrix[k, :].astype(np.uint32).reshape(1, ROWS_A)
        
        # 2. 计算外积
        outer_prod = np.dot(s_vec, a_vec)
        
        # 3. 累加
        accumulator += outer_prod
        
        # 打印部分调试信息
        print(f"  Step k={k}: S[{0},{k}]={s_vec[0,0]} * A[{k},{0}]={a_vec[0,0]} -> Prod={outer_prod[0,0]}")

    # 4. 模运算
    result_mod = accumulator % 65536
    return result_mod.astype(np.uint16)

# ==========================================================
# --- 3. 交互式循环 ---
# ==========================================================
while True:
    try:
        user_input = input("\n请输入起始索引 i (输入 q 退出): ").strip()
        if user_input.lower() == 'q':
            break
        
        start_idx = int(user_input)
        if start_idx < 0 or start_idx > COMMON_DIM:
            print("索引超出范围！")
            continue

        steps_input = input("请输入叠加次数 (默认为 4): ").strip()
        if steps_input == "":
            steps = 4
        else:
            steps = int(steps_input)
            
        if steps <= 0:
            print("步数必须大于0")
            continue
            
        # 计算 steps 步外积之和
        result_matrix = calculate_partial_outer_product_sum(start_idx, steps=steps)
        
        end_idx = start_idx + steps - 1

        # --- 输出结果到文件 (Hex) ---
        out_filename = "debugfile.txt"
        
        with open(out_filename, 'w') as f:
            f.write(f"// partial sum of outer products from k={start_idx} to {end_idx} (steps={steps})\n")
            f.write(f"// Shape: 8 rows (S dimension) x 1344 columns (A dimension)\n")
            f.write(f"// Each value is Hex uint16\n")
            
            f.write("      ")
            for c in range(16): 
                f.write(f"Col_{c:<3} ")
            f.write("...\n")
            
            for r in range(ROWS_S_TR):
                f.write(f"Row_{r}: ")
                for c in range(ROWS_A):
                    val = result_matrix[r, c]
                    f.write(f"{val:04X} ")
                f.write("\n")

        # --- 输出结果到文件 (Decimal) ---
        out_filename_dec = "debugdec.txt"
        
        with open(out_filename_dec, 'w') as f:
            f.write(f"// partial sum of outer products from k={start_idx} to {end_idx} (steps={steps})\n")
            f.write(f"// Shape: 8 rows (S dimension) x 1344 columns (A dimension)\n")
            f.write(f"// Each value is Decimal uint16\n")
            
            f.write("      ")
            for c in range(16): 
                f.write(f"Col_{c:<5} ")
            f.write("...\n")
            
            for r in range(ROWS_S_TR):
                f.write(f"Row_{r}: ")
                for c in range(ROWS_A):
                    val = result_matrix[r, c]
                    f.write(f"{val:<6d} ")
                f.write("\n")
                
        print(f"✅ Hex 结果已保存至: {out_filename}")
        print(f"✅ Dec 结果已保存至: {out_filename_dec}")
        
        # --- 在终端打印左上角预览 (8x8) ---
        print(f"预览 (Top-Left 8x8 Block) [Hex]:")
        print("       " + " ".join([f"C{c:<4}" for c in range(8)]))
        for r in range(8):
            vals = result_matrix[r, :8]
            hex_vals = " ".join([f"{v:04X} " for v in vals])
            print(f"Row {r}: {hex_vals}")
            
    except ValueError:
        print("请输入有效的整数。")
    except Exception as e:
        print(f"发生错误: {e}")

print("再见。")