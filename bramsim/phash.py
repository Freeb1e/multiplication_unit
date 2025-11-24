#!/usr/bin/env python3
"""
phash.py

生成 10752 字节的随机数据并写入 Acache.txt（以二进制形式）。
"""
import secrets
from pathlib import Path


def main():
	mode = input("1 for martix A and 2 for S and 3 for E\n")
	if mode == "1":
		size = 10752
		name="Acache.bin"
	elif mode == "2":
		size = 10752
		name="Sbram.bin"
	elif mode == "3":
		size = 10752
		name="Ebram.bin"
	out = Path(__file__).parent /name
	# 使用 secrets 以获得加密强度的随机字节
	data = secrets.token_bytes(size)
	with out.open("wb") as f:
		f.write(data)
	print(f"Wrote {size} bytes to {out}")


if __name__ == "__main__":
	main()

