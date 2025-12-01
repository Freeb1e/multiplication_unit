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
# --- 2. 核心计算函数 ---
# ==========================================================
def calculate_partial_outer_product_sum(start_index, steps=4):
    """
    计算从 start_index 开始的 steps 个外积的和。
    公式: Sum = Sum_{k=i}^{i+steps-1} ( S_tr[:, k] * A[k, :] )
    
    Dimensions:
      S_tr[:, k] shape is (8,)  -> View as (8, 1)
      A[k, :]    shape is (1344,) -> View as (1, 1344)
      Outer Prod shape is (8, 1344)
    """
    
    # 初始化累加器 (使用 uint32 防止溢出，最后再模)
    accumulator = np.zeros((ROWS_S_TR, ROWS_A), dtype=np.uint32)
    
    print(f"\n开始计算索引 i = {start_index} 到 {start_index + steps - 1} 的外积和 (共 {steps} 步)...")
    
    for k in range(start_index, start_index + steps):
        if k >= COMMON_DIM:
            print(f"⚠️ 警告: 索引 {k} 超出范围，跳过。")
            continue
            
        # 1. 获取向量
        # S_vec: S_tr 的第 k 列 (大小 8)
        # 对应硬件：从 S Buffer 中读出的一列数据
        s_vec = S_tr_matrix[:, k].astype(np.uint32).reshape(ROWS_S_TR, 1)
        
        # A_vec: A 的第 k 行 (大小 1344)
        # 对应硬件：从 A Buffer 中读出的一行数据
        a_vec = A_matrix[k, :].astype(np.uint32).reshape(1, ROWS_A)
        
        # 2. 计算外积 (8 x 1) * (1 x 1344) = (8 x 1344)
        # 对应硬件：脉动阵列在该时钟周期内所有 PE 的乘法操作
        outer_prod = np.dot(s_vec, a_vec)
        
        # 3. 累加
        accumulator += outer_prod
        
        # 打印部分调试信息 (打印每一步中第一个PE的值)
        print(f"  Step k={k}: S[{0},{k}]={s_vec[0,0]} * A[{k},{0}]={a_vec[0,0]} -> Prod={outer_prod[0,0]}")

    # 4. 模运算 (FrodoKEM 是 mod 2^16)
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

        # 新增：询问叠加次数
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
        out_filename = "debugfile.txt"  # 修改文件名
        
        with open(out_filename, 'w') as f:
            f.write(f"// partial sum of outer products from k={start_idx} to {end_idx} (steps={steps})\n")
            f.write(f"// Shape: 8 rows (S dimension) x 1344 columns (A dimension)\n")
            f.write(f"// Each value is Hex uint16\n")
            
            # 打印列头
            f.write("      ")
            for c in range(16): # 只打印前16列的头用于预览
                f.write(f"Col_{c:<3} ")
            f.write("...\n")
            
            for r in range(ROWS_S_TR):
                f.write(f"Row_{r}: ")
                # 写入所有数据
                for c in range(ROWS_A):
                    val = result_matrix[r, c]
                    f.write(f"{val:04X} ")
                f.write("\n")

        # --- 输出结果到文件 (Decimal) ---
        out_filename_dec = "debugdec.txt" # 修改文件名
        
        with open(out_filename_dec, 'w') as f:
            f.write(f"// partial sum of outer products from k={start_idx} to {end_idx} (steps={steps})\n")
            f.write(f"// Shape: 8 rows (S dimension) x 1344 columns (A dimension)\n")
            f.write(f"// Each value is Decimal uint16\n")
            
            # 打印列头
            f.write("      ")
            for c in range(16): # 只打印前16列的头用于预览
                f.write(f"Col_{c:<5} ")
            f.write("...\n")
            
            for r in range(ROWS_S_TR):
                f.write(f"Row_{r}: ")
                # 写入所有数据
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