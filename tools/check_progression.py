#!/usr/bin/env python3
"""按时代顺序模拟玩家进程，检查每个时代的里程碑是否都能用当时可获得的资源完成。

用法:
    Godot --headless --path . -s res://tools/dump_map_resources.gd | grep MAPDUMP > /tmp/map.txt
    python3 tools/check_progression.py /tmp/map.txt

规则 (与游戏实现保持一致):
- 地图资源：需在 dump 中出现、最近环距 <= 当前时代领地半径、时代 >= RESOURCE_ERA_REQUIREMENTS
- 科技 / 制作 / 建筑：受 era 字段与 required_techs 约束
- 配方：实验台必须放一件已制造的容器 (加热类操作要求 can_heat)；炉体可代替坩埚 / 窑炉 (ChemistrySolver.FURNACE_CONTAINERS)；
  温度上限取决于已建炉体；电压需要电池
- 燃烧木柴副产草木灰；砍树 / 拾枝伴生树皮与树脂
退出码：全部时代可完成为 0，否则为 1。
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
SIM = os.path.join(ROOT, "src", "core", "simulation.gd")


def load(name):
    with open(os.path.join(DATA, name + ".json"), encoding="utf-8") as f:
        return json.load(f)


def keys(req):
    k = req["key"]
    return k if isinstance(k, list) else [k]


# 追加操作：集气收集气体，冷凝收集蒸气 (ChemistrySolver.CHAIN_OPS)
CHAIN_OPS = ("gas_collecting", "gas_collecting_air", "condensation")
# 炉体能当作哪些容器 (与 ChemistrySolver.FURNACE_CONTAINERS 一致)
FURNACE_CONTAINERS = {
    "fire_pit": ["fire_pit"],
    "furnace": ["furnace", "kiln", "crucible"],
    "blast_furnace": ["blast_furnace", "furnace", "kiln", "crucible"],
}


def parse_gd_dict(src, name):
    # 支持单行与多行两种 GDScript 字典常量写法
    m = re.search(r"const %s[^{]*\{(.*?)\}" % name, src, re.S)
    if m is None:
        raise SystemExit("simulation.gd 中找不到常量 %s" % name)
    return {k: v for k, v in re.findall(r'"(\w+)":\s*([\d.]+)', m.group(1))}


def main(map_path):
    with open(map_path, encoding="utf-8") as f:
        txt = f.read()
    map_res = json.loads(txt[txt.index("{"):])
    sim_src = open(SIM, encoding="utf-8").read()
    res_era = {k: int(v) for k, v in parse_gd_dict(sim_src, "RESOURCE_ERA_REQUIREMENTS").items()}
    furnace_temp = {k: float(v) for k, v in parse_gd_dict(sim_src, "FURNACE_MAX_TEMP").items()}
    implemented = set(re.search(r"IMPLEMENTED_STRUCTURES[^=]*=\s*\[(.*?)\]", sim_src).group(1).replace('"', "").replace(" ", "").split(","))

    formulas, crafting, buildings = load("formula"), load("crafting"), load("buildings")
    techs, eras = load("techs"), load("eras")
    labs = {a["key"]: a for a in load("labs")}
    items = {i["key"]: i for i in load("items")}

    # 与 ChemistrySolver.formula_min_temp / formula_min_voltage 一致：配方没写就用操作默认值
    def op_of(f):
        return (f.get("required_actions") or {}).get("key", "")

    def min_temp(f):
        return f.get("min_temp") or labs.get(op_of(f), {}).get("default_min_temp", 0)

    def min_volt(f):
        return f.get("min_voltage") or labs.get(op_of(f), {}).get("default_min_voltage", 0)

    def lab_flame(have):
        # 实验台火焰温度取决于最好的燃料 (lab_bench.gd)，枯树枝 873K，持有风箱再加 200K
        t = [873.0] + [float(items[k]["attrs"]["max_temp"]) for k in have
                       if k in items and isinstance(items[k].get("attrs"), dict) and "max_temp" in items[k]["attrs"]]
        return max(t) + (200.0 if "bellows" in have else 0.0)

    def battery_volt(have):
        v = [float(items[k]["attrs"].get("voltage", 0)) for k in have
             if k in items and "battery" in items[k].get("type", []) and isinstance(items[k].get("attrs"), dict)]
        return max(v) if v else 0.0

    def op_ok(op_key, researched, have):
        # 与 LabBench.op_lock_reason 一致：科技 + 不可加热的必备工具
        op = labs.get(op_key)
        if op is None:
            return op_key == ""
        if int(op.get("unlock_era", 0)) > E:
            return False
        if not all(t in researched for t in op.get("required_techs", [])):
            return False
        for req in op.get("required_item", []):
            alts = keys(req)
            chain = op_key in CHAIN_OPS
            if not chain and any(isinstance(items.get(k, {}).get("attrs"), dict) and items[k]["attrs"].get("can_heat") for k in alts):
                continue
            if not any(k in have for k in alts):
                return False
        return True

    have, built, researched = set(), set(), set()
    ok = True
    for era in sorted(eras, key=lambda e: e["order"]):
        E = era["order"]
        radius = int(era.get("territory_radius", 5 + E * 3))
        for k, info in map_res.items():
            if info["min_dist"] <= radius and res_era.get(k, 0) <= E:
                have.add(k)
        if "wood" in have or "stick" in have:
            have |= {"bark", "resin"}

        def items_ok(reqs):
            return all(any(k in have for k in keys(r)) for r in reqs)

        changed = True
        while changed:
            changed = False
            for t in techs:
                if t["key"] in researched or int(t.get("era", 0)) > E:
                    continue
                if all(p in researched for p in t.get("required_techs", [])) and items_ok(t.get("required_items", [])):
                    researched.add(t["key"]); changed = True
            for c in crafting:
                out = c.get("result_item") or c.get("result_tool") or c["key"]
                if out in have or int(c.get("era", 0)) > E:
                    continue
                if all(p in researched for p in c.get("required_techs", [])) and items_ok(c.get("required_items", [])):
                    have |= {out, c["key"]}; changed = True
            for b in buildings:
                if b["key"] in built or b["key"] not in implemented or int(b.get("era", 0)) > E:
                    continue
                if all(p in researched for p in b.get("required_techs", [])) and items_ok(b.get("required_items", [])):
                    built.add(b["key"]); changed = True
            if built & {"fire_pit", "furnace", "blast_furnace"} and "wood_ash" not in have and "wood" in have:
                have.add("wood_ash"); changed = True
            lab_containers = {k for k in have if "container" in items.get(k, {}).get("type", [])}
            lab_hot = {k for k in lab_containers if (items[k].get("attrs") or {}).get("can_heat")}
            furnace_containers = set()
            for b in built & set(FURNACE_CONTAINERS):
                furnace_containers |= set(FURNACE_CONTAINERS[b])
            lab_t = lab_flame(have)
            furnace_t = max([0.0] + [furnace_temp.get(b, 0.0) for b in built])
            voltage = battery_volt(have)
            fire_ops = {k for k, a in labs.items() if a.get("requires_burning")}
            for f in formulas:
                op = op_of(f)
                # 炉体能做加热类操作，实验台需满足操作的科技 / 工具门槛
                in_lab = op_ok(op, researched, have)
                in_furnace = op in fire_ops and bool(built & set(furnace_temp)) and (op != "blowing" or "blast_furnace" in built)
                if not in_lab and not in_furnace:
                    continue
                max_temp = max(lab_t if in_lab else 0.0, furnace_t if in_furnace else 0.0)
                rc = f.get("required_container")
                rcs = set([] if rc in (None, "") else (rc if isinstance(rc, list) else [rc]))
                usable = lab_hot if op in fire_ops else lab_containers
                in_lab = in_lab and (not rcs or bool(rcs & usable))
                in_furnace = in_furnace and (not rcs or bool(rcs & furnace_containers))
                if not in_lab and not in_furnace:
                    continue
                if min_temp(f) > max_temp:
                    continue
                if min_volt(f) > voltage:
                    continue
                if items_ok(f.get("required_items", [])):
                    for p in f.get("products", []):
                        # 与 ChemistrySolver.product_collected 一致；炉体敞口，不收集气体
                        need = p.get("required_chain_operation") or ""
                        is_gas = "gas" in items.get(p["key"], {}).get("type", [])
                        if need in CHAIN_OPS:
                            ok_p = in_lab and op_ok(need, researched, have)
                        elif need == "" and is_gas:
                            ok_p = in_lab and (op_ok("gas_collecting", researched, have) or op_ok("gas_collecting_air", researched, have))
                        else:
                            ok_p = True
                        if ok_p and p["key"] not in have:
                            have.add(p["key"]); changed = True

        def milestone_ok(m):
            special = {
                "build_kiln": "furnace" in built,
                "first_smelt": bool({"copper", "pig_iron", "iron"} & have),
                "collect_gas": bool({"hydrogen", "oxygen", "carbon_dioxide", "chlorine"} & have),
                "first_electrolysis": "battery" in have,
                "produce_aluminum": "aluminum" in have,
                "separate_rare_earth": bool({"neodymium", "lanthanum", "cerium", "praseodymium"} & have),
                "isolate_radium": "radium" in have,
                "first_transmutation": any(
                    any(w in f["name"] for w in ("嬗变", "核", "衰变", "轰击")) and items_ok(f["required_items"])
                    for f in formulas),
                "research_pottery": "pottery" in researched,
                "research_gas_collection": "gas_collection" in researched,
                "crystallization_tech": "crystallization_tech" in researched,
                "unlock_advanced_chem_tools": "advanced_chemical_equipment" in researched,
            }
            if m in special:
                return special[m]
            if m.startswith("craft_"):
                return m[len("craft_"):] in have
            return False

        milestones = [m["key"] for m in era.get("milestones", [])]
        missing = [m for m in milestones if not milestone_ok(m)]
        if not milestones:
            print(f"era {E} {era['key']:12s} (终局时代，无里程碑)")
            break
        status = "OK" if not missing else "BLOCKED"
        print(f"era {E} {era['key']:12s} {status:8s} techs={len(researched)}/{len(techs)} missing={missing}")
        if missing:
            ok = False
            break

    never = [t["key"] for t in techs if t["key"] not in researched]
    print(f"研发不到的科技 ({len(never)}): {never}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
