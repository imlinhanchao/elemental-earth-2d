#!/usr/bin/env python3
"""把 Noto Sans SC 精简为游戏实际需要的字符集，保留可变字重轴。

字符集 = 项目内所有 .gd / .tscn / data/*.json 中出现的字符
       + GB2312 全部汉字 (6763 字，覆盖玩家自定义文本与动态拼接文案)
       + ASCII、全角标点、常用符号。
用法 (需 fonttools):
    python3 tools/subset_font.py
源字体放在 assets/fonts/source/ (带 .gdignore，不参与导入与导出)，输出 assets/fonts/NotoSansSC.ttf。
新增文案后若出现缺字，重新运行本脚本即可。
"""
import os
import sys
from fontTools import subset

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "fonts", "source", "NotoSansSC-VF.ttf")
OUT = os.path.join(ROOT, "assets", "fonts", "NotoSansSC.ttf")


def project_chars():
    chars = set()
    for base in ("src", "data", "tools", "tests"):
        for dp, _, files in os.walk(os.path.join(ROOT, base)):
            for fn in files:
                if fn.endswith((".gd", ".tscn", ".json", ".tres")):
                    with open(os.path.join(dp, fn), encoding="utf-8", errors="ignore") as f:
                        chars.update(f.read())
    return chars


def gb2312_hanzi():
    out = set()
    for hi in range(0xB0, 0xF8):
        for lo in range(0xA1, 0xFF):
            try:
                out.add(bytes([hi, lo]).decode("gb2312"))
            except UnicodeDecodeError:
                pass
    return out


def main():
    chars = project_chars() | gb2312_hanzi()
    chars |= {chr(c) for c in range(0x20, 0x7F)}           # ASCII
    chars |= {chr(c) for c in range(0x3000, 0x3040)}       # CJK 标点
    chars |= {chr(c) for c in range(0xFF00, 0xFFF0)}       # 全角字符
    chars |= {chr(c) for c in range(0x2000, 0x2070)}       # 通用标点
    chars |= {chr(c) for c in range(0x2190, 0x2200)}       # 箭头
    chars |= set("·×÷±°℃℉µ√∞≈≠≤≥①②③④⑤⑥⑦⑧⑨⑩")
    codepoints = sorted(ord(c) for c in chars if c.isprintable() or c == " ")

    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    opts.notdef_outline = True
    opts.hinting = False          # Godot 用自身光栅化，去掉 hinting 进一步减小体积
    font = subset.load_font(SRC, opts)
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=codepoints)
    sub.subset(font)
    subset.save_font(font, OUT, opts)
    print("glyph codepoints: %d" % len(codepoints))
    print("%s: %.1f MB -> %.1f MB" % (os.path.basename(OUT), os.path.getsize(SRC) / 1e6, os.path.getsize(OUT) / 1e6))
    return 0


if __name__ == "__main__":
    sys.exit(main())
