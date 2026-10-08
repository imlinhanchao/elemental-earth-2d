#!/usr/bin/env python3
"""检查每种物品至少有一条获取途径：地图资源、采集伴生掉落、制作、配方产物或硬编码掉落。

用法: python3 tools/check_item_sources.py
有孤立物品时列出并返回 1。新增物品或修改 data/*.json 后运行。
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(name):
    with open(os.path.join(ROOT, "data", name + ".json"), encoding="utf-8") as f:
        return json.load(f)


# simulation.gd / lab_bench.gd 中写死的采集掉落与副产物
CODE_SOURCES = {"water", "mud", "clay", "bark", "resin", "sapling", "wood_ash", "flint", "rock_salt", "stick", "stone"}


def main():
    raw = load("items")
    items = {i["key"]: i for i in raw}
    dup = len(raw) - len(items)
    if dup:
        print("DUPLICATE items.json 有 %d 个重复的物品 key" % dup)
    src = {}
    for f in load("formula"):
        for p in f.get("products", []):
            src.setdefault(p["key"], "配方 " + f["key"])
    for c in load("crafting"):
        src.setdefault(c.get("result_item") or c.get("result_tool") or c["key"], "制作 " + c["key"])
    for d in load("harvest_drops"):
        src.setdefault(d["item"], "采集掉落")
    sim = open(os.path.join(ROOT, "src", "core", "simulation.gd"), encoding="utf-8").read()
    a = sim.index("func _init_hex_resources")
    b = sim.index("tile_resources[coord] = res", a)
    for k in re.findall(r'"([a-z_]+)"\s*:', sim[a:b]):
        src.setdefault(k, "地图")
    # 世界生成器返回的主资源与开局保底资源 (RESOURCE_GUARANTEES) 也在地图上
    gen = open(os.path.join(ROOT, "src", "core", "hex_world_generator.gd"), encoding="utf-8").read()
    for k in re.findall(r'return "([a-z_]+)"', gen):
        src.setdefault(k, "地图")
    g = sim.index("RESOURCE_GUARANTEES")
    for k in re.findall(r'\["([a-z_]+)"', sim[g:sim.index("\n]\n", g)]):
        src.setdefault(k, "地图")
    for k in CODE_SOURCES:
        src.setdefault(k, "采集")
    orphans = [k for k in items if k not in src]
    for k in orphans:
        print("ORPHAN %-28s %s" % (k, items[k]["name"]))
    print("物品 %d 种，孤立 %d 种" % (len(items), len(orphans)))
    return 1 if orphans or dup else 0


if __name__ == "__main__":
    sys.exit(main())
