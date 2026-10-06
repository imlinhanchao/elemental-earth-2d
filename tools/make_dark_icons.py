#!/usr/bin/env python3
"""为深色主题生成墨色线稿图标的浅色版本。

扫描 assets/icons/*.svg，凡使用墨色线稿色 #3A352F 的图标，把墨色换成纸白、铜色换成提亮铜色，
写入 assets/icons/dark/ 同名文件。新增或修改线稿图标后运行一次，再用 Godot 重新导入。
彩色物品图标不处理 (两种主题通用)。
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "icons")
OUT = os.path.join(SRC, "dark")
SWAP = {"#3A352F": "#E6DED0", "#B0692A": "#D9994D"}


def main():
    os.makedirs(OUT, exist_ok=True)
    made = []
    for fn in sorted(os.listdir(SRC)):
        if not fn.endswith(".svg"):
            continue
        text = open(os.path.join(SRC, fn), encoding="utf-8").read()
        if "#3A352F" not in text.upper():
            continue
        for a, b in SWAP.items():
            text = re.sub(re.escape(a), b, text, flags=re.I)
        open(os.path.join(OUT, fn), "w", encoding="utf-8").write(text)
        made.append(fn)
    print("dark icons: %d -> %s" % (len(made), os.path.relpath(OUT, ROOT)))


if __name__ == "__main__":
    main()
