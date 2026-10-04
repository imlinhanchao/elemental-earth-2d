#!/usr/bin/env python3
import json

# 读取现有的 items.json 与 actions.json
items_data = {it['key']: it for it in json.load(open('data/items.json'))}
actions_data = {act['key']: act for act in json.load(open('data/actions.json'))}

# 时代映射函数
def determine_era(key, req_techs):
    if not req_techs:
        if key in ['flint_axe', 'stone_axe', 'stone_pickaxe', 'fire_seed', 'wooden_bucket', 'fiber_cloth']:
            return 0
        return 0
    t = req_techs[0]
    if t in ['stone_tool_crafting', 'stone_masonry', 'rammed_earth_technology', 'wood_processing', 'fire_starting']:
        return 0
    elif t in ['pottery', 'mold_making', 'refractory_materials', 'high_temp_furnace', 'bronze_tool_crafting', 'brass_tool_crafting', 'bark_processing']:
        return 1
    elif t in ['iron_tool_crafting', 'gas_collection', 'sifting_technology', 'explosives', 'crystallization_tech']:
        return 2
    elif t in ['electrochemistry', 'manganese_alloy_smithing', 'titanium_alloy_smithing', 'chrome_alloy_smithing', 'lithium_battery_tech', 'glassworking', 'production_tech', 'nickel_cadmium_battery_tech']:
        return 3
    elif t in ['high_pressure_tech', 'advanced_chemical_equipment', 'precision_machinery', 'magnesium_aluminum_alloying', 'gas_liquefaction']:
        return 4
    elif t in ['nuclear_physics', 'nuclear_reactor_tech', 'particle_accelerator_tech', 'jet_propulsion_tech', 'solar_cell_manufacturing']:
        return 5
    return 2

# 提取所有制作配方
crafting_list = []
seen_keys = set()

# 基础手斧保留
crafting_list.append({
    "key": "flint_axe",
    "name": "原始燧石手斧",
    "era": 0,
    "slot": "axe",
    "type": "tool",
    "required_items": [
        {"key": "stick", "quantity": 2},
        {"key": ["flint", "stone"], "quantity": 2}
    ],
    "result_tool": "flint_axe",
    "notice": "制作成功！装备【原始燧石斧】，现在可以前往树林砍伐橡树！"
})
seen_keys.add("flint_axe")

for act_key, act in actions_data.items():
    if not act_key.startswith("craft_"):
        continue
    
    rewards = act.get("rewards", [])
    if not rewards:
        continue
    
    target_item_key = rewards[0].get("key")
    item_info = items_data.get(target_item_key, {})
    
    # 过滤出建筑（单独进 buildings.json）
    if act_key in ["craft_kiln", "craft_blast_furnace", "craft_reactor_vessel"]:
        continue
        
    recipe_key = target_item_key if target_item_key not in seen_keys else act_key
    if recipe_key in seen_keys:
        continue
    seen_keys.add(recipe_key)
    
    era = determine_era(recipe_key, act.get("required_techs", []))
    
    # 判断槽位
    slot = None
    r_type = "item"
    if "pickaxe" in target_item_key or "hammer" in target_item_key:
        slot = "pickaxe"
        r_type = "tool"
    elif "axe" in target_item_key:
        slot = "axe"
        r_type = "tool"
    elif "shovel" in target_item_key:
        slot = "shovel"
        r_type = "tool"
        
    milestone = item_info.get("milestone")
    if not milestone and act.get("milestone"):
        milestone = act.get("milestone")
        
    crafting_list.append({
        "key": recipe_key,
        "name": act.get("name", item_info.get("name", recipe_key)).replace("打造", "").replace("制作", "").replace("组装", "").replace("制造", "").replace("拉制", "").replace("烧制", "").replace("吹制", ""),
        "era": era,
        "type": r_type,
        "slot": slot,
        "required_items": act.get("required_items", []),
        "required_techs": act.get("required_techs", []),
        "result_item": target_item_key,
        "result_tool": recipe_key if r_type == "tool" else None,
        "result_quantity": rewards[0].get("quantity", 1),
        "milestone": milestone if isinstance(milestone, str) else None,
        "description": act.get("description", item_info.get("description", "")),
        "notice": f"制作完成！成功获得【{item_info.get('name', target_item_key)}】！"
    })

# 排序并写入 crafting.json
crafting_list.sort(key=lambda x: (x["era"], x["name"]))
with open("data/crafting.json", "w", encoding="utf-8") as f:
    json.dump(crafting_list, f, ensure_ascii=False, indent=2)

print(f"成功生成全面工艺打造数据: 共 {len(crafting_list)} 项制作配方，覆盖 6 个时代！")

# 建筑物数据全面扩展
buildings_list = [
    {
        "key": "fire_pit",
        "name": "原始篝火堆",
        "era": 0,
        "required_items": [
            {"key": "wood", "quantity": 4},
            {"key": ["stone", "flint"], "quantity": 4}
        ],
        "description": "石块围起的火坑，可用于夜晚照明与物料粗糙烘烤。",
        "notice": "搭建完成！现场建立【原始篝火堆】！"
    },
    {
        "key": "furnace",
        "name": "陶土熔炉/窑炉",
        "era": 1,
        "milestone": "build_kiln",
        "required_items": [
            {"key": "wood", "quantity": 4},
            {"key": ["stone", "flint"], "quantity": 4}
        ],
        "description": "耐火黏土与石块堆砌的窑炉，可将温度升至1000K以上进行冶炼与烧陶。",
        "notice": "现场施工完成！堆砌起【陶土熔炉】！达成时代里程碑！"
    },
    {
        "key": "blast_furnace",
        "name": "鼓风高炉",
        "era": 1,
        "required_items": [
            {"key": "wood", "quantity": 8},
            {"key": ["stone", "flint"], "quantity": 8},
            {"key": "copper", "quantity": 2}
        ],
        "description": "结合皮风箱与高大炉身的竖炉，能够达到更高炉温进行生铁连续冶炼。",
        "notice": "高炉构筑完成！【鼓风高炉】耸立于领地！"
    },
    {
        "key": "industrial_reactor",
        "name": "工业连续反应塔",
        "era": 2,
        "required_items": [
            {"key": "wood", "quantity": 8},
            {"key": "copper", "quantity": 2}
        ],
        "description": "近代工业连续流装置，插装工艺芯片蓝图后可实现无人值守全自动产出。",
        "notice": "工业构件组装完成！【工业连续反应塔】运转就绪！"
    },
    {
        "key": "distillation_tower",
        "name": "近代分馏塔",
        "era": 2,
        "required_items": [
            {"key": "copper", "quantity": 6},
            {"key": "iron", "quantity": 4},
            {"key": "wood", "quantity": 6}
        ],
        "description": "利用各组分沸点差异进行气液逐板热质交换的多级高效分离构件。",
        "notice": "施工完成！【近代分馏塔】已部署！"
    },
    {
        "key": "electrolysis_bath",
        "name": "工业电解槽机组",
        "era": 3,
        "required_items": [
            {"key": "iron", "quantity": 8},
            {"key": "copper", "quantity": 6},
            {"key": "charcoal", "quantity": 8}
        ],
        "description": "配置石墨阳极与重型母线的高电流密度电解装置，专用于熔盐炼铝与氯碱生产。",
        "notice": "电气系统接通！【工业电解槽机组】建造完毕！"
    },
    {
        "key": "solvent_extraction_battery",
        "name": "串级离心萃取槽组",
        "era": 4,
        "required_items": [
            {"key": "iron", "quantity": 12},
            {"key": "copper", "quantity": 6},
            {"key": "wood", "quantity": 10}
        ],
        "description": "数十级逆流连续相传质萃取设备，用于相似度极高之14种稀土元素精密剥离。",
        "notice": "精密机组部署完成！【串级离心萃取槽组】落成！"
    },
    {
        "key": "nuclear_reactor",
        "name": "重水核裂变反应堆",
        "era": 5,
        "required_items": [
            {"key": "iron", "quantity": 20},
            {"key": "copper", "quantity": 12},
            {"key": "water", "quantity": 16}
        ],
        "description": "受控重核裂变链式反应装置，以重水慢化中子，提供极高通量中子源诱发核嬗变。",
        "notice": "世纪原子丰碑完成！【重水核反应堆】已建成临界！"
    }
]

with open("data/buildings.json", "w", encoding="utf-8") as f:
    json.dump(buildings_list, f, ensure_ascii=False, indent=2)

print(f"成功生成全面建筑数据: 共 {len(buildings_list)} 座核心建筑，覆盖全时代！")
