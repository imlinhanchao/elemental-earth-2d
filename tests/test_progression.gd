# test_progression.gd
# 命令行无头测试：验证进程死锁修复 (P0) 在真实模拟层中生效
# 用法: Godot --headless --path . -s res://tests/test_progression.gd
extends SceneTree

const DataDB = preload("res://src/core/data_db.gd")
const Simulation = preload("res://src/core/simulation.gd")

var _failed := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ ", msg)
	else:
		_failed += 1
		printerr("  ✗ ", msg)

func _initialize() -> void:
	print("\n[进程死锁修复测试]")
	DataDB.initialize()
	var sim = Simulation.new()

	# 1. 地图生成新增的关键矿物
	var spawned := {}
	for c in sim.tile_resources.keys():
		for k in sim.tile_resources[c].keys():
			spawned[k] = true
	for k in ["hematite", "cassiterite", "limestone", "sand", "graphite", "pyrolusite", "niter", "cryolite"]:
		_check(spawned.has(k), "地图生成包含 %s" % k)
	_check(not spawned.has("iron_ore") and not spawned.has("halite"), "地图不再生成未登记物品 iron_ore / halite")

	# 2. 工具耗时读取 crafting.json 的 work_time
	_check(is_equal_approx(sim.calculate_task_duration("wood"), 4.0), "徒手伐木 4.0s")
	sim.equipped_tools["axe"] = "flint_axe"
	_check(is_equal_approx(sim.calculate_task_duration("wood"), 2.0), "燧石斧伐木 2.0s")
	sim.equipped_tools["axe"] = "bronze_axe"
	_check(sim.calculate_task_duration("wood") < 2.0, "青铜斧比燧石斧更快")
	sim.equipped_tools["pickaxe"] = "iron_pickaxe"
	_check(is_equal_approx(sim.calculate_task_duration("hematite"), 1.2), "铁镐采矿 1.2s")

	# 3. 科技时代读表
	_check(DataDB.get_tech_era("stone_tool_crafting") == 0, "石器制作属于石器时代")
	_check(DataDB.get_tech_era("crystallization_tech") == 2, "结晶工艺属于近代化学时代 (与里程碑同时代)")

	# 4. 鼓风高炉：可建造、生成模拟层炉体、炉温上限 1500K、赤铁矿炼生铁
	sim.current_era = 1
	sim.inventory.add_item("wood", 20)
	sim.inventory.add_item("stone", 20)
	sim.inventory.add_item("copper", 4)
	var hex = Vector2i(1, 0)
	_check(sim.build_structure("blast_furnace", hex), "鼓风高炉建造成功")
	_check(sim.built_furnaces.has(hex) and sim.built_furnaces[hex]["type"] == "blast_furnace", "鼓风高炉写入模拟层")
	_check(not sim.build_structure("distillation_tower", Vector2i(2, 0)), "未实现的建筑不可建造")

	sim.inventory.add_item("charcoal", 10)
	sim.inventory.add_item("hematite", 4)
	sim.furnace_add_fuel(hex)
	sim.furnace_add_fuel(hex)
	sim.furnace_add_ore(hex, "hematite", 2)
	for i in range(12):
		sim._on_second_tick()
	_check(sim.built_furnaces[hex]["buffer"].temperature > 1100.0 or sim.inventory.get_count("pig_iron") > 0 or sim.inventory.get_count("iron") > 0,
		"鼓风高炉升温超过陶土熔炉上限或已出铁")
	_check(sim.inventory.get_count("pig_iron") > 0 or sim.inventory.get_count("iron") > 0, "赤铁矿在高炉中炼出铁")

	# 5. 木柴燃烧副产草木灰
	var ash_before = sim.inventory.get_count("wood_ash")
	sim.inventory.remove_item("charcoal", sim.inventory.get_count("charcoal"))
	sim.furnace_add_fuel(hex)
	_check(sim.inventory.get_count("wood_ash") == ash_before + 1, "投入木柴后获得草木灰")

	# 6. 背包中持有的器皿可满足配方容器要求 (筛子 → 筛分硅砂)
	sim.lab_vessel.clear()
	sim.inventory.add_item("sieve", 1)
	sim.lab_vessel.add_substance("sand", 5.0)
	# 配方有 time_required，按其秒数推进一秒节拍
	var sift_secs = int(ceil(float(DataDB.get_formula("sift_silica_sand").get("time_required", 1.0))))
	for i in range(sift_secs):
		sim._on_second_tick()
	_check(sim.lab_vessel.has_substance("silica_sand"), "持有筛子时实验台可筛分出硅砂")

	# 7. 嬗变里程碑覆盖衰变 / 轰击类反应
	sim._on_solver_reaction_occurred("镭衰变产氡", ["radon"])
	_check(sim.completed_milestones.has("first_transmutation"), "衰变反应完成元素嬗变里程碑")

	if _failed == 0:
		print("🎉 进程死锁修复测试全部通过")
		quit(0)
	else:
		printerr("❌ %d 项失败" % _failed)
		quit(1)
