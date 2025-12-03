import numpy as np
import os

def process_matrices(file_a_path, file_b_path, output_bin_path, output_txt_path):
    # --- 1. 参数配置 ---
    ROWS = 8
    COLS = 1344
    DTYPE = np.uint16  # 无符号16位

    # 检查输入文件是否存在
    if not os.path.exists(file_a_path) or not os.path.exists(file_b_path):
        print(f"错误: 找不到输入文件 '{file_a_path}' 或 '{file_b_path}'")
        return

    print(f"正在读取文件: {file_a_path} 和 {file_b_path} ...")

    # --- 2. 读取二进制文件 ---
    # fromfile 读取出来是一维数组，需要 reshape 成 (8, 1344)
    try:
        mat_a = np.fromfile(file_a_path, dtype=DTYPE).reshape(ROWS, COLS)
        mat_b = np.fromfile(file_b_path, dtype=DTYPE).reshape(ROWS, COLS)
    except ValueError as e:
        print(f"错误: 文件大小与预期的矩阵尺寸 ({ROWS}x{COLS}) 不匹配。")
        print(f"详细信息: {e}")
        return

    # --- 3. 矩阵相加 ---
    # 注意：这里结果仍然保持 uint16。如果 60000 + 10000，结果会溢出回绕。
    # 如果你想防止溢出，可以将类型转为 np.uint32，但在存回 bin 时需要决定是截断还是存为32位。
    # 这里默认按照题目暗示（adderB.bin 应该也是同格式）保持 uint16。
    result_mat = mat_a + mat_b

    print("计算完成。正在生成输出文件...")

    # --- 4. 生成 adderB.bin ---
    # tofile 会将数据以二进制流形式写入
    result_mat.tofile(output_bin_path)
    print(f"-> 已生成二进制文件: {output_bin_path}")

    # --- 5. 生成 txt 文件 (10进制) ---
    # fmt='%d' 表示整数，delimiter=' ' 表示用空格隔开
    np.savetxt(output_txt_path, result_mat, fmt='%d', delimiter=' ')
    print(f"-> 已生成文本文件: {output_txt_path}")
    print("处理完毕。")

# --- 生成测试数据 (如果你没有现成文件，可以取消注释运行下面这几行生成 dummy data) ---
def generate_dummy_data(filename, value):
    rows, cols = 8, 1344
    # 创建全为 value 的矩阵
    data = np.full((rows, cols), value, dtype=np.uint16)
    data.tofile(filename)
    print(f"已生成测试文件: {filename}")

if __name__ == "__main__":
    # 输入文件名 (请修改为你实际的文件名)
    input_file_1 = "debugfile.bin"
    input_file_2 = "B_matrix.bin"
    
    # 如果你没有文件，取消下面两行注释来生成测试数据
    # generate_dummy_data(input_file_1, 100) # 矩阵全是 100
    # generate_dummy_data(input_file_2, 5)   # 矩阵全是 5

    # 执行处理
    process_matrices(
        file_a_path=input_file_1,
        file_b_path=input_file_2,
        output_bin_path="adderB.bin",
        output_txt_path="adderB.txt"
    )