#!/usr/bin/env python3
"""为没有手绘图标的物品生成专属 SVG 图标，写入 assets/icons/items/<key>.svg。

规则：
- 形状按物品类型决定：矿石 → 多面矿块 / 晶簇 / 砂堆；金属单质与合金 → 锭；粉末类化合物 → 皿中粉堆；
  晶体类化合物 → 晶簇；液体 → 试剂瓶；气体 → 集气瓶；工具、容器、装置、奇观按名称逐类绘制；
  早期常见物品 (草木灰、木桶、坩埚、火种、耐火砖、生铁、煤、焦炭…) 在 HAND 中单独绘制。
- 颜色取物品名称或描述中的第一个颜色词 (如「深绿色粉末」→ 深绿)，没有颜色词时按 key 生成柔和色。
- 同形状、同颜色的物品再用 key 的哈希改变晶体数量、朝向与刻印，保证互不相同。
- 已有手绘图标 (assets/icons/res_<key>.svg 等) 的物品跳过。不使用 <text> (Godot 4.2 的 ThorVG 不支持)。

用法: python3 tools/make_item_icons.py，然后运行
    Godot --headless --editor --quit --path .
导入新图标 (.import 由本脚本预先写好，使用 svg/scale=3.0 + mipmaps)。
"""
import colorsys
import hashlib
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(ROOT, "assets", "icons")
OUT = os.path.join(ICONS, "items")
INK = "#2A2420"

COLOR_WORDS = [
    ("银白", "#D3D8DE"), ("银灰", "#A3AAB2"), ("深灰", "#5A5F66"), ("灰黑", "#44464A"), ("灰白", "#CDC9C1"),
    ("黄绿", "#A6BE48"), ("蓝绿", "#3B9A92"), ("墨绿", "#2E5C45"), ("深绿", "#2D6A3E"), ("翠绿", "#3DA45A"),
    ("暗红", "#8A2A22"), ("深红", "#A0252A"), ("橙红", "#D6552C"), ("红褐", "#8C4A2F"), ("黑褐", "#3C2D24"),
    ("米黄", "#E6D7A6"), ("淡黄", "#EEDF88"), ("亮黄", "#F0CC1C"), ("金黄", "#E3AF29"), ("天蓝", "#7CC2E6"),
    ("深蓝", "#2B4D98"), ("淡粉", "#ECB5C0"), ("无色", "#DCE9EF"), ("透明", "#DCE9EF"), ("赤", "#B8432E"),
    ("黑", "#2E2C2B"), ("白", "#F1EFE9"), ("灰", "#98948D"), ("红", "#C33A2F"), ("橙", "#DE782B"),
    ("黄", "#E6C239"), ("绿", "#4C984C"), ("蓝", "#3A6EC0"), ("紫", "#7A4EA6"), ("棕", "#88593A"),
    ("褐", "#785136"), ("银", "#C7CCD2"),
]
# 「金属」「合金」「粉末」等不是颜色词
COLOR_RE = re.compile("|".join(
    [re.escape(w) for w, _ in COLOR_WORDS] + [r"(?<!合)金(?!属|刚|字)", r"粉(?!末|状|尘|碎)"]))
COLOR_MAP = dict(COLOR_WORDS)
COLOR_MAP["金"] = "#D9A82B"
COLOR_MAP["粉"] = "#E59AAE"


def h(key, n):
    return int(hashlib.md5(key.encode()).hexdigest()[:8], 16) % n


def adj(hex_col, light=0.0, sat=1.0):
    r, g, b = (int(hex_col[i:i + 2], 16) / 255 for i in (1, 3, 5))
    hh, l, s = colorsys.rgb_to_hls(r, g, b)
    l = max(0.0, min(1.0, l + light))
    s = max(0.0, min(1.0, s * sat))
    r, g, b = colorsys.hls_to_rgb(hh, l, s)
    return "#%02X%02X%02X" % (round(r * 255), round(g * 255), round(b * 255))


def pick_color(item):
    for text in (item["name"], item.get("description", "")):
        m = COLOR_RE.search(text)
        if m:
            return COLOR_MAP[m.group(0)]
    hue = h(item["key"], 360) / 360.0
    r, g, b = colorsys.hls_to_rgb(hue, 0.55, 0.35)
    return "#%02X%02X%02X" % (round(r * 255), round(g * 255), round(b * 255))


def svg(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" '
            'stroke-linejoin="round" stroke-linecap="round">\n%s\n</svg>\n' % body)


def poly(pts, fill, w=2.0, stroke=INK, extra=""):
    return '<polygon points="%s" fill="%s" stroke="%s" stroke-width="%.1f"%s/>' % (
        " ".join("%g,%g" % p for p in pts), fill, stroke, w, extra)


def path(d, fill="none", w=2.0, stroke=INK, extra=""):
    return '<path d="%s" fill="%s" stroke="%s" stroke-width="%.1f"%s/>' % (d, fill, stroke, w, extra)


def circ(x, y, r, fill, w=2.0, stroke=INK, extra=""):
    return '<circle cx="%g" cy="%g" r="%g" fill="%s" stroke="%s" stroke-width="%.1f"%s/>' % (x, y, r, fill, stroke, w, extra)


def rect(x, y, ww, hh, fill, w=2.0, rx=0, stroke=INK, extra=""):
    return '<rect x="%g" y="%g" width="%g" height="%g" rx="%g" fill="%s" stroke="%s" stroke-width="%.1f"%s/>' % (
        x, y, ww, hh, rx, fill, stroke, w, extra)


def line(x1, y1, x2, y2, col=INK, w=2.0):
    return '<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="%s" stroke-width="%.1f"/>' % (x1, y1, x2, y2, col, w)


# ---------------------------------------------------------------- 通用形状

def ore(c, key):
    v = h(key, 4)
    jit = [(h(key + str(i), 7) - 3) for i in range(6)]
    body = [(32 + jit[0], 9), (52 + jit[1], 20), (54, 42 + jit[2]), (36 + jit[3], 55), (13, 49 + jit[4]), (9, 27 + jit[5])]
    top = [body[0], body[1], (34, 29), body[5]]
    right = [(34, 29), body[1], body[2], body[3], (32, 44)]
    matrix = "#8E8679" if v % 2 == 0 else "#7A7268"
    out = [poly(body, matrix), poly(top, adj(matrix, 0.12), 1.5), poly(right, adj(matrix, -0.10), 1.5)]
    # 矿物以斑块、脉或晶粒嵌在围岩中
    if v == 0:
        out += [poly([(18, 30), (28, 26), (31, 38), (21, 42)], c, 1.5), poly([(38, 36), (46, 32), (47, 44), (40, 47)], adj(c, -0.08), 1.5)]
    elif v == 1:
        out += [path("M14 34 Q26 28 34 36 T52 34", "none", 4.5, c), path("M14 34 Q26 28 34 36 T52 34", "none", 1.2, adj(c, 0.25))]
        out += [circ(22, 44, 3.5, c, 1.2)]
    elif v == 2:
        for i, (x, y) in enumerate([(19, 33), (27, 40), (37, 34), (44, 42), (31, 24)]):
            out.append(poly([(x, y - 5), (x + 4, y), (x, y + 5), (x - 4, y)], adj(c, 0.05 * (i % 2)), 1.2))
    else:
        out += [poly([(16, 26), (34, 20), (40, 36), (22, 44)], c, 1.5), line(18, 30, 34, 24, adj(c, 0.3), 1.5)]
    out.append(line(body[0][0], body[0][1], 34, 29, "#FFFFFF", 1.2))
    return svg("\n".join(out))


def crystals(c, key):
    n = 2 + h(key, 3)
    out = [path("M8 54 Q32 48 56 54", "none", 2.5, adj(c, -0.3))]
    xs = [24, 38, 30, 16, 46][:n]
    for i, x in enumerate(xs):
        top = 12 + h(key + str(i), 12) + i * 3
        w = 6 + h(key + "w" + str(i), 3)
        tilt = (h(key + "t" + str(i), 7) - 3)
        pts = [(x - w + tilt, 52), (x - w + tilt, top + 8), (x + tilt, top), (x + w + tilt, top + 8), (x + w + tilt, 52)]
        out.append(poly(pts, adj(c, -0.04 * i)))
        out.append(poly([(x + tilt, top), (x + w + tilt, top + 8), (x + w + tilt, 52), (x + tilt, 52)], adj(c, -0.12), 1.2))
        out.append(line(x - w / 2 + tilt, top + 10, x - w / 2 + tilt, 46, adj(c, 0.3), 1.2))
    return svg("\n".join(out))


def powder(c, key):
    v = h(key, 3)
    dish = '<ellipse cx="32" cy="46" rx="24" ry="8" fill="#EDE6D8" stroke="%s" stroke-width="2"/>' % INK
    heap = path("M12 46 C16 %d 26 %d 32 %d C38 %d 48 %d 52 46 Z" % (34 - v, 22 + v * 3, 21 + v * 2, 22 + v * 3, 34 - v), c)
    shade = path("M34 24 C40 26 48 34 50 45 L40 46 C40 38 38 30 34 24 Z", adj(c, -0.12), 0, "none")
    grains = "".join(circ(16 + i * 7 + v, 51 - (i % 2) * 2, 1.4, adj(c, -0.15), 0, "none") for i in range(5))
    hi = path("M22 36 C25 30 28 27 31 26", "none", 1.5, adj(c, 0.3))
    return svg("\n".join([dish, heap, shade, hi, grains]))


def sand_pile(c, key):
    out = [path("M6 52 C14 36 24 26 34 26 C44 26 52 38 58 52 Z", c)]
    for i in range(14):
        x = 12 + h(key + "x%d" % i, 40)
        y = 34 + h(key + "y%d" % i, 16)
        out.append(circ(x, y, 1.2, adj(c, -0.18 if i % 2 else 0.18), 0, "none"))
    return svg("\n".join(out))


def ingot(c, key):
    v = h(key, 4)
    out = [poly([(16, 20), (48, 20), (56, 32), (8, 32)], adj(c, 0.12)), poly([(8, 32), (56, 32), (50, 48), (14, 48)], adj(c, -0.08))]
    mark = adj(c, -0.3)
    # 刻印：圆 / 菱形 / 三角 / 双线，区分同色金属
    if v == 0:
        out.append(circ(32, 26, 3.2, "none", 1.6, mark))
    elif v == 1:
        out.append(poly([(32, 22), (36, 26), (32, 30), (28, 26)], "none", 1.6, mark))
    elif v == 2:
        out.append(poly([(32, 22), (36.5, 29), (27.5, 29)], "none", 1.6, mark))
    else:
        out += [line(26, 24, 38, 24, mark, 1.6), line(26, 28, 38, 28, mark, 1.6)]
    out.append(line(10, 32, 54, 32, "#FFFFFF", 1.2))
    return svg("\n".join(out))


def lump(c, key, porous=False, glossy=False):
    j = [h(key + str(i), 6) - 3 for i in range(5)]
    body = [(20 + j[0], 14), (44, 12 + j[1]), (54 + j[2], 30), (46, 50 + j[3]), (18, 52), (9 + j[4], 32)]
    out = [poly(body, c), poly([body[0], body[1], (36, 28), (16, 26)], adj(c, 0.10), 1.5)]
    if porous:
        for i in range(7):
            out.append(circ(16 + h(key + "p%d" % i, 30), 28 + h(key + "q%d" % i, 18), 1.6 + (i % 2), adj(c, -0.2), 0, "none"))
    if glossy:
        out += [line(22, 18, 34, 16, "#FFFFFF", 1.5), line(40, 34, 46, 44, adj(c, 0.35), 1.5)]
    return svg("\n".join(out))


def block(c, key):
    out = [poly([(14, 22), (36, 14), (52, 22), (30, 30)], adj(c, 0.14)), poly([(14, 22), (30, 30), (30, 52), (14, 44)], c),
           poly([(30, 30), (52, 22), (52, 44), (30, 52)], adj(c, -0.12))]
    if h(key, 2):
        out.append(line(18, 36, 26, 40, adj(c, -0.2), 1.2))
    return svg("\n".join(out))


def brick(c, key):
    out = [poly([(8, 30), (40, 20), (56, 26), (24, 36)], adj(c, 0.14)), poly([(8, 30), (24, 36), (24, 50), (8, 44)], adj(c, -0.04)),
           poly([(24, 36), (56, 26), (56, 40), (24, 50)], adj(c, -0.12)), line(36, 32, 36, 46, adj(c, -0.28), 1.2)]
    return svg("\n".join(out))


def liquid_bottle(c, key):
    v = h(key, 3)
    fill = adj(c, 0.0) if c != "#DCE9EF" else "#CFE3EE"
    if v == 0:  # 圆底烧瓶
        out = [rect(27, 8, 10, 4, "#B9A68A", 1.5, 1), path("M28 12 L28 26 C16 30 12 40 16 48 C20 56 44 56 48 48 C52 40 48 30 36 26 L36 12", "#F4F8FA"),
               path("M15 42 C16 52 48 52 49 42 C44 44 20 44 15 42 Z", fill, 1.5)]
    elif v == 1:  # 试剂瓶
        out = [rect(25, 8, 14, 6, "#B9A68A", 1.5, 2), path("M24 14 L40 14 L42 20 C48 22 50 26 50 32 L50 52 C50 55 14 55 14 52 L14 32 C14 26 16 22 22 20 Z", "#F4F8FA"),
               path("M15 34 L49 34 L49 52 C49 54 15 54 15 52 Z", fill, 1.5), rect(20, 38, 24, 8, "#FFFFFF", 1, 1, adj(fill, -0.2), ' fill-opacity="0.7"')]
    else:  # 锥形瓶
        out = [rect(27, 8, 10, 4, "#B9A68A", 1.5, 1), path("M28 12 L28 24 L12 52 L52 52 L36 24 L36 12", "#F4F8FA"),
               path("M18 42 L46 42 L52 52 L12 52 Z", fill, 1.5)]
    out.append(line(20, 30 if v != 2 else 34, 22, 26 if v != 2 else 30, "#FFFFFF", 1.5))
    return svg("\n".join(out))


def gas_jar(c, key):
    tint = c if c != "#DCE9EF" else "#E8F1F5"
    out = [rect(16, 10, 32, 5, "#B9A68A", 1.5, 2), path("M18 15 L46 15 L46 50 C46 55 18 55 18 50 Z", "#F4F8FA"),
           path("M19 18 L45 18 L45 50 C45 54 19 54 19 50 Z", tint, 0, "none", ' fill-opacity="0.45"')]
    v = h(key, 3)
    for i in range(2 + v):
        y = 26 + i * 8
        out.append(path("M%d %d C%d %d %d %d %d %d" % (22, y, 28, y - 5, 34, y + 5, 42, y - 1), "none", 2.2, adj(c, -0.1) if c != "#DCE9EF" else "#9DB4C0"))
    out.append(line(22, 20, 22, 46, "#FFFFFF", 1.5))
    return svg("\n".join(out))


def cloth(c, key):
    out = [path("M10 22 L44 16 L54 40 L20 48 Z", c), path("M44 16 L54 40 L50 44 L42 22 Z", adj(c, -0.12), 1.5)]
    for i in range(4):
        out.append(line(14 + i * 8, 22 - i, 22 + i * 8, 46 - i * 2, adj(c, -0.2), 1))
    for i in range(3):
        out.append(line(13, 28 + i * 7, 47, 22 + i * 7, adj(c, -0.2), 1))
    return svg("\n".join(out))


def sack(c, key):
    return svg("\n".join([path("M20 18 C14 26 12 40 16 50 C20 56 44 56 48 50 C52 40 50 26 44 18 Z", c),
                          path("M22 18 L42 18 L40 12 L24 12 Z", adj(c, -0.1), 1.5), line(22, 18, 42, 18, INK, 2.5),
                          rect(24, 32, 16, 10, adj(c, 0.15), 1.2, 1)]))


def paste(c, key):
    return svg("\n".join([path("M12 30 L52 30 L48 52 L16 52 Z", "#8A7A66"), '<ellipse cx="32" cy="30" rx="20" ry="6" fill="%s" stroke="%s" stroke-width="2"/>' % (c, INK),
                          path("M22 29 C28 24 36 34 42 28", "none", 1.5, adj(c, -0.2)), line(40, 12, 34, 28, "#8A5A36", 3)]))


# ---------------------------------------------------------------- 工具与容器

METAL_COLORS = {"石": "#8F8B84", "燧石": "#4A5560", "青铜": "#B5833A", "黄铜": "#D2AC3C", "铁": "#8A9099", "锰": "#9DA3AA",
                "钛": "#B8C2CC", "铬": "#C9D3DC", "铜": "#C8743F"}


def head_color(name):
    for k in ("燧石", "青铜", "黄铜", "铁", "锰", "钛", "铬", "铜", "石"):
        if k in name:
            return METAL_COLORS[k]
    return "#8A9099"


def axe(c):
    return svg("\n".join([line(18, 54, 40, 14, "#8A5A36", 5), path("M34 12 C42 8 54 12 56 24 C50 24 44 26 40 30 Z", c),
                          line(38, 14, 52, 20, adj(c, 0.3), 1.5)]))


def pickaxe(c):
    return svg("\n".join([line(16, 54, 44, 18, "#8A5A36", 5), path("M22 14 C34 10 50 18 56 32 L50 34 C44 24 34 18 22 18 Z", c),
                          line(26, 15, 46, 22, adj(c, 0.3), 1.5)]))


def shovel(c):
    return svg("\n".join([line(42, 10, 30, 36, "#8A5A36", 4.5), line(36, 10, 48, 12, "#8A5A36", 4),
                          path("M26 32 L38 38 L32 54 C28 58 18 54 18 48 Z", c)]))


def chisel(c):
    return svg("\n".join([rect(26, 8, 12, 24, "#8A5A36", 2, 3), poly([(27, 32), (37, 32), (36, 50), (32, 56), (28, 50)], c), line(30, 36, 30, 48, "#FFFFFF", 1.2)]))


def battery(c):
    return svg("\n".join([rect(18, 14, 28, 40, c, 2, 4), rect(26, 9, 12, 5, "#C9CED4", 1.5, 1),
                          path("M34 22 L27 35 L33 35 L29 46 L38 31 L32 31 Z", "#F2CE1D", 1.2)]))


def rod(c):
    return svg("\n".join([line(14, 52, 50, 12, INK, 7), line(14, 52, 50, 12, c, 4.5), line(16, 48, 46, 15, "#FFFFFF", 1)]))


def tube(c):
    return svg("\n".join([path("M26 8 L38 8 L38 50 C38 56 26 56 26 50 Z", "#F4F8FA"), path("M27 34 L37 34 L37 50 C37 54 27 54 27 50 Z", c, 1.5), line(29, 12, 29, 44, "#FFFFFF", 1.2)]))


def dish(c):
    return svg("\n".join(['<ellipse cx="32" cy="36" rx="24" ry="9" fill="#EDE6D8" stroke="%s" stroke-width="2"/>' % INK,
                          path("M8 36 C10 48 54 48 56 36", "#D8CDB8"), '<ellipse cx="32" cy="35" rx="16" ry="5" fill="%s" stroke="none"/>' % c]))


def cylinder(c):
    return svg("\n".join([rect(28, 6, 8, 6, "#C9CED4", 1.5), path("M22 18 C22 12 42 12 42 18 L42 52 C42 56 22 56 22 52 Z", c), rect(23, 28, 18, 6, adj(c, -0.2), 0, 0, "none")]))


def pump(c):
    return svg("\n".join([rect(14, 30, 36, 20, c, 2, 3), circ(32, 22, 10, adj(c, 0.1)), line(32, 22, 38, 16, INK, 2), rect(8, 36, 6, 8, "#8A9099", 1.5), rect(50, 36, 6, 8, "#8A9099", 1.5)]))


def mold(c):
    return svg("\n".join([poly([(10, 24), (46, 16), (56, 26), (20, 34)], adj(c, 0.12)), poly([(10, 24), (20, 34), (20, 48), (10, 38)], c),
                          poly([(20, 34), (56, 26), (56, 40), (20, 48)], adj(c, -0.12)), path("M24 25 L40 21 L46 25 L30 29 Z", adj(c, -0.3), 1.2)]))


def bellows(c):
    return svg("\n".join([path("M10 20 L40 26 L40 40 L10 46 Z", "#8A5A36"), path("M14 24 L36 28 M14 33 L36 33 M14 42 L36 38", "none", 1.5, "#C9A678"),
                          poly([(40, 28), (56, 32), (56, 34), (40, 38)], "#8A9099"), line(10, 20, 4, 14, "#8A5A36", 3), line(10, 46, 4, 52, "#8A5A36", 3)]))


def sieve(c):
    out = ['<ellipse cx="32" cy="32" rx="24" ry="12" fill="#C9A678" stroke="%s" stroke-width="2"/>' % INK,
           '<ellipse cx="32" cy="32" rx="19" ry="8" fill="#EDE6D8" stroke="%s" stroke-width="1.5"/>' % INK]
    for i in range(-3, 4):
        out.append(line(32 + i * 5, 25, 32 + i * 5, 39, "#9A8A70", 1))
    out.append(line(14, 32, 50, 32, "#9A8A70", 1))
    return svg("\n".join(out))


def javelin(c):
    return svg("\n".join([line(8, 56, 48, 16, "#8A5A36", 3.5), poly([(46, 18), (56, 6), (52, 20)], c), line(16, 46, 22, 42, "#C9A678", 3)]))


def detonator(c):
    return svg("\n".join([rect(22, 22, 20, 32, c, 2, 3), path("M32 22 C32 12 42 10 46 6", "none", 2, INK), circ(47, 6, 2.5, "#F2CE1D", 1)]))


def rocket(c):
    return svg("\n".join([path("M32 4 C40 14 42 26 40 44 L24 44 C22 26 24 14 32 4 Z", "#E8E4DC"), circ(32, 22, 4, "#7CC2E6", 1.5),
                          poly([(24, 34), (14, 48), (24, 44)], "#C33A2F"), poly([(40, 34), (50, 48), (40, 44)], "#C33A2F"),
                          path("M27 44 L37 44 L34 56 L30 56 Z", "#F0A030", 1.5)]))


def station(c):
    return svg("\n".join([rect(26, 26, 12, 12, "#D3D8DE"), rect(6, 28, 18, 8, "#2B4D98", 1.5), rect(40, 28, 18, 8, "#2B4D98", 1.5),
                          line(15, 28, 15, 36, "#7CC2E6", 1), line(49, 28, 49, 36, "#7CC2E6", 1), rect(30, 14, 4, 12, "#A3AAB2", 1.5), rect(30, 38, 4, 12, "#A3AAB2", 1.5)]))


def bucket(c):
    return svg("\n".join([path("M14 22 C14 10 50 10 50 22", "none", 2.5, "#5A5F66"), path("M12 22 L52 22 L46 54 L18 54 Z", "#A8763E"),
                          line(13, 30, 51, 30, "#5A5F66", 3), line(16, 46, 48, 46, "#5A5F66", 3),
                          line(26, 22, 25, 54, "#7E5428", 1.2), line(38, 22, 39, 54, "#7E5428", 1.2),
                          '<ellipse cx="32" cy="22" rx="20" ry="4" fill="#6FA8C8" stroke="%s" stroke-width="2"/>' % INK]))


def clay_pot(c):
    return svg("\n".join([path("M24 10 L40 10 L38 16 C50 20 54 30 50 42 C46 52 18 52 14 42 C10 30 14 20 26 16 Z", "#C2683A"),
                          path("M16 30 C24 34 40 34 48 30", "none", 1.5, "#8A3F1E"), line(24, 10, 40, 10, INK, 3)]))


def iron_tank(c):
    return svg("\n".join([rect(14, 14, 36, 40, "#8A9099", 2, 4), '<ellipse cx="32" cy="14" rx="18" ry="4" fill="#A3AAB2" stroke="%s" stroke-width="2"/>' % INK,
                          line(14, 26, 50, 26, "#5A5F66", 2), line(14, 44, 50, 44, "#5A5F66", 2),
                          "".join(circ(18 + i * 7, 26, 1.2, "#C9CED4", 0, "none") for i in range(5))]))


def kiln(c):
    return svg("\n".join([path("M10 54 L14 26 C16 12 48 12 50 26 L54 54 Z", "#B8743F"), path("M24 54 L24 40 C24 32 40 32 40 40 L40 54 Z", "#3C2D24"),
                          path("M28 54 C28 46 36 46 36 54", "#F0A030", 1.2), rect(28, 6, 8, 8, "#8C4A2F", 1.5),
                          line(14, 34, 50, 34, "#8C4A2F", 1.2), line(13, 44, 24, 44, "#8C4A2F", 1.2), line(40, 44, 51, 44, "#8C4A2F", 1.2)]))


def blast_furnace(c):
    return svg("\n".join([path("M18 56 L22 14 L42 14 L46 56 Z", "#9C6A45"), rect(20, 8, 24, 6, "#5A5F66", 1.5),
                          line(20, 26, 44, 26, "#5A5F66", 3), line(19, 42, 45, 42, "#5A5F66", 3),
                          rect(26, 46, 12, 10, "#3C2D24", 1.5), rect(28, 49, 8, 5, "#F0A030", 0, 0, "none"),
                          path("M46 34 L58 34 L58 40", "none", 4, "#5A5F66")]))


def crucible(c):
    return svg("\n".join([path("M14 18 L50 18 L44 50 C42 56 22 56 20 50 Z", "#D8CDB8"), '<ellipse cx="32" cy="18" rx="18" ry="4" fill="#B8743F" stroke="%s" stroke-width="2"/>' % INK,
                          path("M18 30 C26 33 38 33 46 30", "none", 1.5, "#A89A80"), path("M24 18 C26 12 32 10 34 4", "none", 1.5, "#E07A2C")]))


def condenser(c):
    return svg("\n".join([line(8, 50, 56, 14, INK, 9), line(8, 50, 56, 14, "#D2AC3C", 6), line(14, 44, 50, 18, "#F4F8FA", 2.5),
                          rect(14, 30, 6, 8, "#D2AC3C", 1.5), rect(42, 14, 6, 8, "#D2AC3C", 1.5)]))


def beaker(c):
    return svg("\n".join([path("M16 10 L48 10 L48 50 C48 55 16 55 16 50 L16 14 L12 10", "#F4F8FA"),
                          path("M17 34 L47 34 L47 50 C47 53 17 53 17 50 Z", "#9CC7DE", 1.5),
                          line(40, 18, 46, 18, INK, 1.2), line(40, 24, 46, 24, INK, 1.2), line(40, 30, 46, 30, INK, 1.2)]))


def test_tube(c):
    return svg("\n".join([path("M26 6 L38 6 L38 50 C38 57 26 57 26 50 Z", "#F4F8FA"), path("M27 36 L37 36 L37 50 C37 55 27 55 27 50 Z", "#9CC7DE", 1.5),
                          line(23, 6, 41, 6, INK, 2.5), line(29, 10, 29, 44, "#FFFFFF", 1.2)]))


def distilling_flask(c):
    return svg("\n".join([path("M28 6 L28 26 C16 30 12 40 16 48 C20 56 44 56 48 48 C52 40 48 30 36 26 L36 6", "#F4F8FA"),
                          path("M15 42 C16 52 48 52 49 42 C44 44 20 44 15 42 Z", "#9CC7DE", 1.5), path("M36 14 L58 24", "none", 2.5, INK)]))


def autoclave(c):
    return svg("\n".join([rect(16, 16, 32, 40, "#8A9099", 2, 6), rect(12, 12, 40, 8, "#5A5F66", 2, 2), circ(44, 8, 5, "#F4F8FA", 1.5),
                          line(44, 8, 46, 5, "#C33A2F", 1.2), "".join(circ(16 + i * 8, 16, 1.4, "#C9CED4", 0, "none") for i in range(5))]))


def reactor(c):
    return svg("\n".join([path("M12 56 L12 28 C12 8 52 8 52 28 L52 56 Z", "#C9CED4"), rect(22, 40, 20, 16, "#5A5F66", 1.5),
                          circ(32, 26, 7, "#3BB5D6", 1.5), circ(32, 26, 3, "#E8FBFF", 0, "none")]))


def kettle(c):
    return svg("\n".join([path("M12 24 L52 24 L52 46 C52 54 12 54 12 46 Z", "#8A9099"), rect(10, 18, 44, 6, "#5A5F66", 1.5, 2),
                          line(32, 18, 32, 8, INK, 2.5), circ(32, 7, 3, "#C9CED4", 1.5), path("M20 36 L44 36", "none", 1.5, "#5A5F66")]))


def sealed_tube(c):
    return svg("\n".join([path("M8 26 C8 20 56 20 56 26 L56 38 C56 44 8 44 8 38 Z", "#F1F6F8"), line(12, 26, 52, 26, "#FFFFFF", 1.5),
                          rect(26, 28, 12, 8, "#9CC7DE", 1.2, 2)]))


def electro_cell(c):
    return svg("\n".join([rect(10, 24, 44, 30, "#9CC7DE", 2, 3), rect(18, 10, 8, 38, "#3C3A38", 1.5), rect(38, 10, 8, 38, "#3C3A38", 1.5),
                          line(22, 6, 22, 10, "#C33A2F", 2.5), line(42, 6, 42, 10, "#3A6EC0", 2.5)]))


def column(c):
    out = [path("M28 4 L36 4 L36 30 C46 34 48 44 44 50 C40 56 24 56 20 50 C16 44 18 34 28 30 Z", "#F4F8FA")]
    for y in (10, 16, 22):
        out.append('<ellipse cx="32" cy="%d" rx="6" ry="2.5" fill="#E8F1F5" stroke="%s" stroke-width="1.2"/>' % (y, INK))
    out.append(path("M21 44 C24 52 40 52 43 44 Z", "#9CC7DE", 1.2))
    return svg("\n".join(out))


def control_rod(c):
    return svg("\n".join([rect(26, 6, 12, 50, "#44464A", 2, 2), rect(22, 4, 20, 6, "#A3AAB2", 1.5, 1),
                          line(29, 14, 29, 50, "#7A7268", 1.2), line(35, 14, 35, 50, "#7A7268", 1.2)]))


def tenon(c):
    return svg("\n".join([poly([(8, 30), (28, 22), (28, 34), (8, 42)], "#B07A44"), poly([(36, 20), (56, 28), (56, 40), (36, 32)], "#C28A50"),
                          poly([(24, 26), (40, 22), (40, 30), (24, 34)], "#8A5A36", 1.5)]))


def rivet(c):
    return svg("\n".join(['<ellipse cx="32" cy="20" rx="16" ry="8" fill="%s" stroke="%s" stroke-width="2"/>' % (c, INK),
                          rect(27, 22, 10, 30, adj(c, -0.08), 2, 2), line(22, 18, 30, 15, "#FFFFFF", 1.2)]))


def dynamite(c):
    out = []
    for i, x in enumerate((18, 30, 42)):
        out.append(rect(x - 6, 20, 12, 34, "#C33A2F", 2, 3))
    out += [rect(10, 32, 44, 5, "#3C2D24", 1.5), path("M30 20 C30 12 38 10 42 6", "none", 2, INK), circ(43, 5, 2.5, "#F2CE1D", 1)]
    return svg("\n".join(out))


def seaweed(c):
    return svg("\n".join([path("M22 56 C14 44 26 34 18 20 C16 14 20 8 22 6", "none", 5, "#2E6B3F"),
                          path("M34 56 C42 44 30 32 40 18", "none", 5, "#3D8A4E"), path("M44 56 C50 48 46 40 52 32", "none", 4, "#2E6B3F")]))


def grains(c, key):
    out = ['<ellipse cx="32" cy="44" rx="22" ry="8" fill="#8A5A36" stroke="%s" stroke-width="2"/>' % INK, path("M10 44 C10 56 54 56 54 44", "#8A5A36")]
    for i in range(12):
        x = 16 + (i % 6) * 6 + (i // 6) * 3
        y = 40 - (i // 6) * 4
        out.append('<ellipse cx="%d" cy="%d" rx="3" ry="2" fill="#F4F1E8" stroke="%s" stroke-width="1"/>' % (x, y, INK))
    return svg("\n".join(out))


def fat(c, key):
    return svg("\n".join([path("M12 40 C10 26 26 18 38 22 C50 24 56 34 50 44 C44 52 18 52 12 40 Z", "#F1E7CF"),
                          path("M20 34 C28 30 36 34 44 32", "none", 1.5, "#D8C49A"), circ(26, 42, 3, "#E6D5AF", 1)]))


def fire_seed(c, key):
    return svg("\n".join([path("M14 50 L50 50 L44 56 L20 56 Z", "#8A5A36"), path("M18 50 C14 40 22 34 22 26 C28 32 30 22 32 14 C38 24 46 30 44 40 C44 46 40 50 36 50 Z", "#E07A2C"),
                          path("M26 50 C24 44 28 40 30 34 C34 40 38 44 36 50 Z", "#F2CE1D", 1.5)]))


def ember_powder(c, key):
    body = powder("#3A3634", key)
    return body.replace("</svg>", '<path d="M44 18 L46 12 L48 18 L54 20 L48 22 L46 28 L44 22 L38 20 Z" fill="#F2CE1D" stroke="%s" stroke-width="1.2"/>\n</svg>' % INK)


def ash(c, key):
    out = ['<ellipse cx="32" cy="48" rx="24" ry="6" fill="#CFC9BE" stroke="none"/>', path("M10 48 C14 34 24 26 32 26 C42 26 50 36 54 48 Z", "#B9B3A9")]
    for i in range(10):
        out.append(circ(16 + h(key + "a%d" % i, 34), 34 + h(key + "b%d" % i, 12), 1.3, "#8E887E" if i % 3 else "#E07A2C", 0, "none"))
    out.append(path("M24 22 C22 16 28 14 26 8 M36 20 C38 14 34 12 36 6", "none", 1.5, "#A8A29A"))
    return svg("\n".join(out))


# ---------------------------------------------------------------- 奇观与装置

def pyramid(c):
    return svg("\n".join([poly([(32, 8), (58, 52), (6, 52)], "#E3C27A"), poly([(32, 8), (58, 52), (36, 52)], "#C9A35A", 1.5),
                          line(16, 36, 47, 36, "#B8914E", 1), line(22, 26, 42, 26, "#B8914E", 1), line(4, 54, 60, 54, INK, 2)]))


def zun(c):
    return svg("\n".join([path("M18 8 L46 8 L40 20 C50 26 50 40 42 46 L46 56 L18 56 L22 46 C14 40 14 26 24 20 Z", "#4F8A72"),
                          circ(16, 30, 4, "#3E6E5A", 1.5), circ(48, 30, 4, "#3E6E5A", 1.5), path("M24 34 L40 34 M24 40 L40 40", "none", 1.5, "#2E5C45")]))


def great_wall(c):
    out = [path("M4 44 L16 34 L30 38 L44 26 L60 30 L60 42 L44 38 L30 50 L16 46 L4 56 Z", "#A89C86")]
    for x, y in ((16, 34), (44, 26)):
        out.append(rect(x - 5, y - 10, 10, 10, "#8E8270", 1.5))
    return svg("\n".join(out))


def pantheon(c):
    out = [path("M14 30 C14 14 50 14 50 30 Z", "#D8CDB8"), poly([(8, 30), (56, 30), (32, 20)], "#E6DCC8"), rect(8, 30, 48, 4, "#CFC3AA", 1.5)]
    for x in range(12, 56, 8):
        out.append(rect(x, 34, 4, 16, "#EDE6D8", 1.2))
    out.append(rect(6, 50, 52, 5, "#CFC3AA", 1.5))
    return svg("\n".join(out))


def eiffel(c):
    return svg("\n".join([path("M32 4 L36 22 L44 40 L52 58 L42 58 C40 50 24 50 22 58 L12 58 L20 40 L28 22 Z", "#8C6A4A"),
                          line(24, 36, 40, 36, INK, 2), line(29, 20, 35, 20, INK, 2), path("M26 58 C28 52 36 52 38 58", "#EDE6D8", 1.5)]))


def pagoda(c):
    out = []
    for i, (w, y) in enumerate(((26, 50), (22, 40), (18, 30), (14, 20))):
        out.append(path("M%d %d L%d %d L%d %d L%d %d Z" % (32 - w, y, 32 + w, y, 32 + w - 4, y - 4, 32 - w + 4, y - 4), "#8C4A2F", 1.5))
        out.append(rect(32 - w + 6, y, 2 * w - 12, 6, "#C28A50", 1.2))
    out.append(line(32, 4, 32, 16, INK, 2))
    return svg("\n".join(out))


def cyclotron(c):
    return svg("\n".join([circ(32, 32, 24, "#C9CED4"), path("M32 32 m-4 0 a4 4 0 1 1 8 0 a8 8 0 1 1 -16 0 a12 12 0 1 1 24 0 a16 16 0 1 1 -32 0", "none", 1.8, "#3A6EC0"),
                          line(8, 32, 56, 32, "#5A5F66", 1.5)]))


def geiger(c):
    return svg("\n".join([rect(10, 20, 30, 34, "#E6C239", 2, 4), rect(15, 26, 20, 12, "#F4F1E8", 1.5, 1), path("M18 36 L24 30 L28 36", "none", 1.5, INK),
                          line(40, 30, 54, 16, INK, 2.5), rect(48, 10, 8, 10, "#8A9099", 1.5, 2)]))


def magnet(c):
    return svg("\n".join([path("M14 10 L26 10 L26 36 C26 44 38 44 38 36 L38 10 L50 10 L50 36 C50 58 14 58 14 36 Z", "#3A6EC0"),
                          rect(14, 10, 12, 8, "#C9CED4", 1.5), rect(38, 10, 12, 8, "#C9CED4", 1.5)]))


# 名称关键词 → 形状 (工具 / 容器 / 装置 / 奇观)，按顺序匹配
NAMED = [
    ("冷凝管", lambda c: condenser(c)), ("蒸馏瓶", lambda c: distilling_flask(c)), ("烧杯", lambda c: beaker(c)), ("试管", lambda c: test_tube(c)),
    ("高压釜", lambda c: autoclave(c)), ("反应釜", lambda c: kettle(c)), ("核反应堆", lambda c: reactor(c)), ("高炉", lambda c: blast_furnace(c)),
    ("窑炉", lambda c: kiln(c)), ("坩埚", lambda c: crucible(c)), ("木桶", lambda c: bucket(c)), ("陶罐", lambda c: clay_pot(c)), ("铁罐", lambda c: iron_tank(c)),
    ("石英反应管", lambda c: sealed_tube(c)), ("电解槽", lambda c: electro_cell(c)), ("分馏柱", lambda c: column(c)), ("控制棒", lambda c: control_rod(c)),
    ("玻璃棒", lambda c: rod("#DDEBF2")), ("电池", lambda c: battery(c)), ("雷管", lambda c: detonator("#C9CED4")), ("淘洗盘", lambda c: dish("#C9A678")),
    ("蒸发皿", lambda c: dish("#F1EFE9")), ("标枪", lambda c: javelin("#8A9099")), ("真空泵", lambda c: pump("#8A9099")), ("气瓶", lambda c: cylinder("#3A6EC0")),
    ("陶模", lambda c: mold("#C2683A")), ("鼓风机", lambda c: bellows(c)), ("筛子", lambda c: sieve(c)), ("运载火箭", lambda c: rocket(c)),
    ("和平号空间站", lambda c: station(c).replace("</svg>", '<path d="M2 60 Q32 44 62 60" fill="#3A6EC0" stroke="%s" stroke-width="2"/>\n</svg>' % INK)),
    ("空间站", lambda c: station(c)), ("金字塔", lambda c: pyramid(c)), ("四羊方尊", lambda c: zun(c)), ("长城", lambda c: great_wall(c)),
    ("万神殿", lambda c: pantheon(c)), ("埃菲尔铁塔", lambda c: eiffel(c)), ("木塔", lambda c: pagoda(c)), ("回旋加速器", lambda c: cyclotron(c)),
    ("盖革计数器", lambda c: geiger(c)), ("超导磁体", lambda c: magnet(c)),
]

# 早期常见物品单独绘制：key → (形状函数, 颜色)
HAND = {
    "wood_ash": (ash, "#B9B3A9"), "fire_seed": (fire_seed, "#E07A2C"), "gunpowder": (ember_powder, "#3A3634"),
    "coal": (lambda c, k: lump(c, k, glossy=True), "#2E2C2B"), "coke": (lambda c, k: lump(c, k, porous=True), "#77736C"),
    "slag": (lambda c, k: lump(c, k, porous=True), "#6E5A4A"), "pig_iron": (ingot, "#5E636A"),
    "fire_brick": (brick, "#E2CC97"), "blue_brick": (brick, "#7D8A93"), "lead_bricks": (brick, "#8C929A"),
    "limestone": (block, "#D9D2C2"), "quicklime": (lambda c, k: lump(c, k), "#F1EFE9"), "slaked_lime": (powder, "#F4F2EC"),
    "cement": (sack, "#B9BCAE"), "roman_concrete": (block, "#B4ADA0"), "sticky_rice": (grains, "#F4F1E8"),
    "sticky_rice_mortar": (paste, "#E9E2CF"), "fiber_cloth": (cloth, "#C8B48A"), "animal_fat": (fat, "#F1E7CF"),
    "seaweed": (lambda c, k: seaweed(c), "#2E6B3F"), "dried_seaweed": (lambda c, k: seaweed(c).replace("#2E6B3F", "#6B6A3A").replace("#3D8A4E", "#7E7A44"), "#6B6A3A"),
    "sand": (sand_pile, "#E3CF95"), "silica_sand": (sand_pile, "#EFE7D2"), "gold_sand": (sand_pile, "#D9A82B"),
    "crude_platinum_sand": (sand_pile, "#B9BEC4"), "diatomaceous_earth": (powder, "#E8E2D2"),
    "dynamite": (lambda c, k: dynamite(c), "#C33A2F"), "rivet": (lambda c, k: rivet(c), "#8A9099"),
    "tenon_mortise": (lambda c, k: tenon(c), "#B07A44"), "magnesium_aluminum_alloy": (ingot, "#C7CDD3"),
    "manganese_steel": (ingot, "#6C7178"), "stainless_steel": (ingot, "#C9D3DC"), "platinum_ingot": (ingot, "#E1E4E8"),
    "blister_copper": (lambda c, k: lump(c, k, porous=True), "#B5623A"), "native_silver": (lambda c, k: lump(c, k, glossy=True), "#C7CCD2"),
    "air": (gas_jar, "#DCE9EF"), "brine": (liquid_bottle, "#5E9EC2"), "bittern": (liquid_bottle, "#C8D9C0"),
    "alkaline_solution": (liquid_bottle, "#D6DDB8"), "mercury": (liquid_bottle, "#B9BEC4"), "coal_tar": (liquid_bottle, "#2E2C2B"),
    "solar_cell": (lambda c, k: battery("#2B4D98"), "#2B4D98"),
}

POWDER_WORDS = ("粉", "灰", "白", "霜")
SALT_WORDS = ("氧化", "硫化", "氯化", "碳酸", "硝酸", "硫酸", "磷酸", "氟化", "草酸", "氢氧化", "铬酸", "锰酸", "氟", "盐", "酸")
CRYSTAL_ORES = ("石英", "萤石", "绿柱石", "天青石", "锆石", "冰晶石", "金红石", "黄铜矿", "辉钼矿", "白钨矿", "雄黄", "雌黄", "辰砂")
NONMETALS = {"nonmetal", "halogen", "noble-gas", "metalloid"}


def shape_for(item, elements):
    key, name, cat = item["key"], item["name"], item.get("category", "")
    desc = item.get("description", "")
    c = pick_color(item)
    if key in HAND:
        fn, col = HAND[key]
        return fn(col, key)
    for word, fn in NAMED:
        if word in name:
            return fn(c)
    types = item.get("type", [])
    if cat == "工具":
        hc = head_color(name)
        if "斧" in name:
            return axe(hc)
        if "镐" in name:
            return pickaxe(hc)
        if "铲" in name:
            return shovel(hc)
        if "凿" in name:
            return chisel(hc)
        return chisel(hc)
    if cat == "气体" or "gas" in types:
        return gas_jar(c, key)
    if cat in ("液体", "化工") or "liquid" in types or name.endswith(("溶液", "浸液", "母液", "酸", "液")):
        return liquid_bottle(c, key)
    if cat == "矿石":
        if "砂" in name or "沙" in name:
            return sand_pile(c, key)
        if name in CRYSTAL_ORES or "晶" in desc[:12]:
            return crystals(c, key)
        return ore(c, key)
    # 单质：金属画锭，非金属画晶块
    el = item.get("elemental")
    if isinstance(el, int) and el > 0 and el in elements and len(name.replace("金属", "")) <= 2:
        if elements[el].get("category") in NONMETALS:
            return crystals(c, key) if "晶" in desc else lump(c, key, glossy=True)
        return ingot(c, key)
    if any(w in name for w in ("合金", "钢", "锭")):
        return ingot(c, key)
    if "砖" in name:
        return brick(c, key)
    if "渣" in name or "灰" in name and "石" not in name:
        return powder(c, key) if "灰" in name else lump(c, key, porous=True)
    if "块" in name or "熔块" in name:
        return lump(c, key)
    if any(w in name for w in POWDER_WORDS) or "粉末" in desc:
        return powder(c, key)
    if any(w in name for w in SALT_WORDS) or "晶" in desc:
        return crystals(c, key) if ("晶体" in desc or "结晶" in desc) and "粉末" not in desc else powder(c, key)
    if cat == "燃料":
        return lump(c, key)
    return block(c, key)


# ---------------------------------------------------------------- 化学式刻印 (笔画字体，不依赖 <text>)
# 字形坐标：宽 4、大写高 6 (y 向下，基线 6)，小写 x 高从 2 起，下伸到 8
GLYPHS = {
    "A": "M0 6 L2 0 L4 6 M0.7 4 L3.3 4", "B": "M0 6 L0 0 L3 0 Q4 0 4 1.5 Q4 3 3 3 L0 3 M3 3 Q4 3 4 4.5 Q4 6 3 6 L0 6",
    "C": "M4 0.8 Q3 0 2 0 Q0 0 0 3 Q0 6 2 6 Q3 6 4 5.2", "D": "M0 0 L0 6 L2 6 Q4 6 4 3 Q4 0 2 0 Z",
    "E": "M4 0 L0 0 L0 6 L4 6 M0 3 L3 3", "F": "M4 0 L0 0 L0 6 M0 3 L3 3",
    "G": "M4 0.8 Q3 0 2 0 Q0 0 0 3 Q0 6 2 6 Q4 6 4 3.5 L2.2 3.5", "H": "M0 0 L0 6 M4 0 L4 6 M0 3 L4 3",
    "I": "M0.8 0 L3.2 0 M2 0 L2 6 M0.8 6 L3.2 6", "K": "M0 0 L0 6 M4 0 L0 3.5 M1.3 2.6 L4 6", "L": "M0 0 L0 6 L4 6",
    "M": "M0 6 L0 0 L2 3.5 L4 0 L4 6", "N": "M0 6 L0 0 L4 6 L4 0", "O": "M2 0 Q0 0 0 3 Q0 6 2 6 Q4 6 4 3 Q4 0 2 0 Z",
    "P": "M0 6 L0 0 L3 0 Q4 0 4 1.5 Q4 3 3 3 L0 3", "R": "M0 6 L0 0 L3 0 Q4 0 4 1.5 Q4 3 3 3 L0 3 M2 3 L4 6",
    "S": "M4 0.8 Q3.2 0 2 0 Q0 0 0 1.5 Q0 3 2 3 Q4 3 4 4.5 Q4 6 2 6 Q0.8 6 0 5.2", "T": "M0 0 L4 0 M2 0 L2 6",
    "U": "M0 0 L0 4 Q0 6 2 6 Q4 6 4 4 L4 0", "V": "M0 0 L2 6 L4 0", "W": "M0 0 L1 6 L2 2.5 L3 6 L4 0",
    "X": "M0 0 L4 6 M4 0 L0 6", "Y": "M0 0 L2 3 L4 0 M2 3 L2 6", "Z": "M0 0 L4 0 L0 6 L4 6",
    "a": "M3.5 2.6 Q3 2 2 2 Q0 2 0 4 Q0 6 2 6 Q3.5 6 3.5 4 M3.5 2 L3.5 6",
    "b": "M0 0 L0 6 M0 4 Q0 2 2 2 Q3.5 2 3.5 4 Q3.5 6 2 6 Q0 6 0 4",
    "c": "M3.5 2.6 Q3 2 2 2 Q0 2 0 4 Q0 6 2 6 Q3 6 3.5 5.4",
    "d": "M3.5 0 L3.5 6 M3.5 4 Q3.5 2 1.8 2 Q0 2 0 4 Q0 6 1.8 6 Q3.5 6 3.5 4",
    "e": "M0 4 L3.5 4 Q3.5 2 1.8 2 Q0 2 0 4 Q0 6 2 6 Q3 6 3.5 5.4", "f": "M3 0.4 Q2.6 0 2 0 Q1.2 0 1.2 1 L1.2 6 M0 2.4 L2.6 2.4",
    "g": "M3.5 2 L3.5 6.5 Q3.5 8 1.8 8 Q0.6 8 0.2 7.4 M3.5 4 Q3.5 2 1.8 2 Q0 2 0 4 Q0 5.8 1.8 5.8 Q3.5 5.8 3.5 4",
    "h": "M0 0 L0 6 M0 3.8 Q0.6 2 2 2 Q3.5 2 3.5 3.6 L3.5 6", "i": "M1.8 2.4 L1.8 6 M1.8 0.6 L1.8 0.9",
    "k": "M0 0 L0 6 M3.2 2 L0 4.4 M1.1 3.6 L3.4 6", "l": "M1.8 0 L1.8 6",
    "m": "M0 6 L0 2 M0 3.4 Q0.4 2 1.2 2 Q2 2 2 3.4 L2 6 M2 3.4 Q2.4 2 3.2 2 Q4 2 4 3.4 L4 6",
    "n": "M0 6 L0 2 M0 3.6 Q0.6 2 2 2 Q3.5 2 3.5 3.6 L3.5 6", "o": "M1.8 2 Q0 2 0 4 Q0 6 1.8 6 Q3.5 6 3.5 4 Q3.5 2 1.8 2 Z",
    "p": "M0 2 L0 8 M0 4 Q0 2 1.8 2 Q3.5 2 3.5 4 Q3.5 6 1.8 6 Q0 6 0 4", "r": "M0 6 L0 2 M0 3.8 Q0.8 2 2.6 2.2",
    "s": "M3.2 2.5 Q2.6 2 1.7 2 Q0.2 2 0.2 3 Q0.2 4 1.7 4 Q3.3 4 3.3 5 Q3.3 6 1.7 6 Q0.6 6 0 5.4",
    "t": "M1.4 0.6 L1.4 5 Q1.4 6 2.4 6 L3 6 M0 2.2 L2.8 2.2", "u": "M0 2 L0 4.4 Q0 6 1.7 6 Q3.4 6 3.4 4.4 M3.4 2 L3.4 6",
    "y": "M0 2 L1.8 5.6 M3.6 2 L1.6 7 Q1.2 8 0.4 8",
    "0": "M2 0 Q0.4 0 0.4 3 Q0.4 6 2 6 Q3.6 6 3.6 3 Q3.6 0 2 0 Z", "1": "M1 1.2 L2.2 0 L2.2 6",
    "2": "M0.3 1.2 Q1 0 2 0 Q3.7 0 3.7 1.7 Q3.7 3 0.3 6 L3.8 6",
    "3": "M0.4 0.6 Q1.2 0 2 0 Q3.6 0 3.6 1.5 Q3.6 3 2 3 Q3.8 3 3.8 4.5 Q3.8 6 2 6 Q1 6 0.3 5.4",
    "4": "M3 6 L3 0 L0 4.2 L4 4.2", "5": "M3.6 0 L0.6 0 L0.3 2.8 Q1 2.3 2 2.3 Q3.8 2.3 3.8 4.2 Q3.8 6 2 6 Q1 6 0.3 5.4",
    "7": "M0 0 L4 0 L1.5 6",
}
ANIONS = [("tetrachloride", "Cl4"), ("dichromate", "Cr2O7"), ("pyrosulfate", "S2O7"), ("bisulfate", "HSO4"), ("bicarbonate", "HCO3"),
          ("trioxide", "O3"), ("dioxide", "O2"), ("monoxide", "O"), ("oxide", "O"), ("sulfate", "SO4"), ("sulfide", "S"),
          ("chloride", "Cl"), ("carbonate", "CO3"), ("nitrate", "NO3"), ("nitrite", "NO2"), ("hydroxide", "OH"),
          ("fluoride", "F"), ("oxalate", "C2O4"), ("chromate", "CrO4"), ("aluminate", "AlO2"), ("perrhenate", "ReO4"),
          ("zincate", "ZnO2"), ("hypochlorite", "ClO"), ("diuranate", "U2O7"), ("fulminate", "CNO"), ("phosphate", "PO4")]
# 气体、酸与常见化合物直接给出化学式
FORMULAS = {
    "carbon_monoxide": "CO", "carbon_dioxide": "CO2", "hydrogen_sulfide": "H2S", "hydrogen": "H2", "sulfur_dioxide": "SO2",
    "sulfur_trioxide": "SO3", "nitrogen": "N2", "ammonia": "NH3", "oxygen": "O2", "chlorine": "Cl2", "nitrogen_monoxide": "NO",
    "nitrogen_dioxide": "NO2", "air": "Air", "radon": "Rn", "helium": "He", "crude_helium": "He", "helium_deoxidized": "He",
    "radon_gas_mixture": "Rn", "argon": "Ar", "neon": "Ne", "krypton": "Kr", "xenon": "Xe", "coal_gas": "CH4",
    "dilute_sulfuric_acid": "H2SO4", "concentrated_sulfuric_acid": "H2SO4", "fuming_sulfuric_acid": "SO3", "nitric_acid": "HNO3",
    "hydrochloric_acid": "HCl", "hydrofluoric_acid": "HF", "phosphoric_acid": "H3PO4", "sulfurous_acid": "H2SO3",
    "oxalic_acid": "C2O4", "boric_acid": "BO3", "aqua_regia": "HCl", "ammonia_water": "NH3", "carbonated_water": "CO2",
    "glycerol": "C3H8", "nitroglycerin": "NO3", "liquid_hydrogen": "H2", "liquid_oxygen": "O2", "liquid_helium": "He",
    "liquid_nitrogen": "N2", "alumina": "Al2O3", "zirconia": "ZrO2", "quicklime": "CaO", "slaked_lime": "CaOH",
    "gypsum": "CaSO4", "sodium_hypochlorite": "NaClO", "bleaching_powder": "CaClO", "mercury": "Hg", "bromine": "Br",
}
ALIASES = {"aluminum": "Al", "cesium": "Cs", "sulfur": "S", "rare": "RE", "ferrous": "Fe", "cuprammonium": "Cu", "uranyl": "U"}


def chem_label(item, elements, name2sym):
    key = item["key"]
    if key in FORMULAS:
        return FORMULAS[key]
    el = item.get("elemental")
    if isinstance(el, int) and el > 0 and el in elements and len(item["name"].replace("金属", "")) <= 2:
        return elements[el]["symbol"]
    cats = []
    anion = ""
    for tok in key.split("_"):
        if tok in name2sym:
            cats.append(name2sym[tok])
        elif tok in ALIASES:
            cats.append(ALIASES[tok])
        else:
            for a, f in ANIONS:
                if tok == a:
                    anion = f
                    break
    if not cats and not anion:
        return ""
    if not anion and item.get("category") in ("矿石", "工具", "容器", "奇观", "装置"):
        return ""
    text = "".join(dict.fromkeys(cats)) + anion
    if len(text) > 6:
        text = "".join(ch for ch in text if not ch.isdigit())
    if len(text) > 6:
        text = "".join(dict.fromkeys(cats)) or anion
    return text[:6]


def label_tag(text):
    """右下角纸签，化学式中的数字画成下标。"""
    if not text:
        return ""
    adv, glyphs, x = [], [], 0.0
    for ch in text:
        if ch not in GLYPHS:
            continue
        sub = ch.isdigit() and x > 0
        glyphs.append((ch, x, sub))
        x += (3.4 if sub else (5.2 if ch.isupper() or ch.isdigit() else 4.6))
    if not glyphs:
        return ""
    width = x - 1.0
    scale = min(1.6, 30.0 / width)
    tw = width * scale + 6
    tx, ty, th = 62 - tw, 45, 17
    out = ['<rect x="%.1f" y="%d" width="%.1f" height="%d" rx="3" fill="#FBF7EE" stroke="%s" stroke-width="1.5"/>' % (tx, ty, tw, th, INK)]
    for ch, gx, sub in glyphs:
        s = scale * (0.62 if sub else 1.0)
        ox = tx + 3 + gx * scale
        oy = ty + 3.2 + (6 * scale - 6 * s) + (1.2 * scale if sub else 0)
        out.append('<g transform="translate(%.2f %.2f) scale(%.3f)"><path d="%s" fill="none" stroke="%s" stroke-width="%.2f"/></g>' % (
            ox, oy, s, GLYPHS[ch], INK, 1.5 / s))
    return "\n".join(out)


def with_label(text_svg, label):
    tag = label_tag(label)
    return text_svg.replace("</svg>", tag + "\n</svg>") if tag else text_svg


def recolor(text_svg, k):
    """同图标时整体轻微改变色相，直到与已有图标不同。"""
    def shift(m):
        col = m.group(0)
        if col.upper() in (INK.upper(), "#FFFFFF", "#FBF7EE", "#F4F8FA"):
            return col
        r, g, b = (int(col[i:i + 2], 16) / 255 for i in (1, 3, 5))
        hh, l, sat = colorsys.rgb_to_hls(r, g, b)
        hh = (hh + 0.07 * k) % 1.0
        l = max(0.05, min(0.95, l + (0.05 if k % 2 else -0.05)))
        sat = max(sat, 0.25)
        r, g, b = colorsys.hls_to_rgb(hh, l, sat)
        return "#%02X%02X%02X" % (round(r * 255), round(g * 255), round(b * 255))
    return re.sub(r"#[0-9A-Fa-f]{6}", shift, text_svg)


IMPORT_TMPL = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
svg/scale=3.0
editor/scale_with_editor_scale=false
editor/convert_colors_with_editor_theme=false
"""


def has_hand_icon(key):
    return any(os.path.exists(os.path.join(ICONS, p % key)) for p in ("res_%s.svg", "bldg_%s.svg", "tool_%s.svg", "%s.svg"))


def main():
    items = json.load(open(os.path.join(ROOT, "data", "items.json"), encoding="utf-8"))
    elements = {int(e["number"]): e for e in json.load(open(os.path.join(ROOT, "data", "elements.json"), encoding="utf-8"))}
    name2sym = {e["nameEn"].lower(): e["symbol"] for e in elements.values()}
    os.makedirs(OUT, exist_ok=True)
    made, digests = 0, {}
    for item in items:
        if has_hand_icon(item["key"]):
            continue
        text = with_label(shape_for(item, elements), chem_label(item, elements, name2sym))
        k = 1
        while hashlib.md5(text.encode()).hexdigest() in digests and k < 12:
            text = recolor(with_label(shape_for(item, elements), chem_label(item, elements, name2sym)), k)
            k += 1
        digests.setdefault(hashlib.md5(text.encode()).hexdigest(), []).append(item["key"])
        p = os.path.join(OUT, item["key"] + ".svg")
        old = open(p, encoding="utf-8").read() if os.path.exists(p) else None
        if old != text:
            open(p, "w", encoding="utf-8").write(text)
        if not os.path.exists(p + ".import"):
            open(p + ".import", "w", encoding="utf-8").write(IMPORT_TMPL)
        made += 1
    dup = [v for v in digests.values() if len(v) > 1]
    print("item icons: %d -> %s" % (made, os.path.relpath(OUT, ROOT)))
    for group in dup:
        print("SAME ICON:", ", ".join(group))
    return 1 if dup else 0


if __name__ == "__main__":
    raise SystemExit(main())
