# test_progression.gd
# 命令行无头测试：验证进程死锁修复 (P0) 在真实模拟层中生效
# 用法: Godot --headless --path . -s res://tests/test_progression.gd
extends SceneTree

const DataDB = preload("res://src/core/data_db.gd")
const Simulation = preload("res://src/core/simulation.gd")
const LabBench = preload("res://src/core/lab_bench.gd")
const MixtureBuffer = preload("res://src/core/mixture_buffer.gd")

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

	# 1b. 新游戏随机种子：地图每次不同，开局领地内一定有树木、碎石、枯枝、燧石
	var maps := {}
	for i in range(8):
		sim.reset_to_new_game()
		var start := {}
		for c in sim.world_resources.keys():
			if (absi(c.x) + absi(c.x + c.y) + absi(c.y)) / 2 <= 5:
				start[sim.world_resources[c]] = start.get(sim.world_resources[c], 0) + 1
		maps[hash(sim.world_resources)] = true
		var ok: bool = start.get("wood", 0) >= 6 and start.get("stone", 0) >= 4 and start.get("stick", 0) >= 4 and start.get("flint", 0) >= 3
		if not ok:
			_check(false, "种子 %d 开局资源不足: %s" % [sim.world_seed, start])
	_check(maps.size() >= 7, "8 次新游戏生成了 %d 张不同的地图" % maps.size())
	sim.init_world_map(4242, 18)
	var map_a = sim.world_resources.duplicate()
	sim.init_world_map(4242, 18)
	_check(sim.world_resources == map_a, "同一种子生成的地图完全一致")
	sim.init_world_map(12345, 18)

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
	# 研发受阻时给出具体原因：陶器制作没有前置科技，石器时代应提示时代未到而不是缺前置
	sim.reset_to_new_game()
	sim.inventory.add_item("clay", 20)
	_check(sim.get_research_block_reason("pottery").begins_with("需要进入"), "陶器制作在石器时代提示所需时代")
	sim.current_era = 1
	_check(sim.can_research_tech("pottery"), "炼金术时代持有粘土即可研发陶器制作")
	_check(sim.get_research_block_reason("mold_making").begins_with("需要先研发"), "缺前置时列出前置科技")
	sim.inventory.remove_item("clay", 20)
	_check(sim.get_research_block_reason("pottery").begins_with("材料不足"), "缺材料时提示材料不足")
	sim.reset_to_new_game()

	# 4. 鼓风高炉：可建造、生成模拟层炉体、炉温上限 1500K、赤铁矿炼生铁
	sim.current_era = 1
	sim.inventory.add_item("wood", 20)
	sim.inventory.add_item("stone", 20)
	sim.inventory.add_item("copper", 4)
	var hex = Vector2i(1, 0)
	_check(sim.build_structure("blast_furnace", hex), "鼓风高炉建造成功")
	_check(sim.built_furnaces.has(hex) and sim.built_furnaces[hex]["type"] == "blast_furnace", "鼓风高炉写入模拟层")
	_check(not sim.build_structure("distillation_tower", Vector2i(2, 0)), "未实现的建筑不可建造")

	# 炉体是炉体模式的实验台：炉膛即容器，只能做加热类操作，不耗容器耐久
	var fb = sim.get_furnace_bench(hex)
	_check(fb != null and fb.is_furnace() and fb.container == "blast_furnace", "鼓风高炉带有炉体实验台，炉膛即容器")
	_check(fb.op_lock_reason("stirring") != "" and fb.op_lock_reason("roasting") == "", "炉内只能做加热类操作，焙烧不需要另带器皿")
	_check(fb.op_lock_reason("blowing") == "", "鼓风高炉自带风箱，可以吹炼")
	_check(not fb.set_container("clay_pot"), "炉体不能换容器")
	sim.inventory.add_item("charcoal", 10)
	sim.inventory.add_item("hematite", 4)
	sim.inventory.add_item("flint", 2)
	_check(fb.fuel_flame_temp("charcoal") > sim.lab.fuel_flame_temp("charcoal"), "炉膛保温：同样的木炭在高炉里比实验台更热")
	_check(sim.get_furnace_bench(hex) != null and LabBench.new(sim, MixtureBuffer.new(), "fire_pit").fuel_flame_temp("charcoal") <= sim.FURNACE_MAX_TEMP["fire_pit"], "篝火堆的火焰不超过炉温上限")
	fb.set_operation("roasting")
	fb.add_reagent("hematite", 2)
	fb.add_reagent("charcoal", 2)
	fb.add_fuel("charcoal")
	fb.add_fuel("charcoal")
	_check(fb.ignite(), "高炉放燃料后可以点火")
	_check(sim.has_open_fire(), "领地里有燃着的炉子")
	for i in range(30):
		sim.tick(1.0)
	_check(fb.vessel.temperature > 1100.0, "鼓风高炉升温超过 1100K")
	var fgot = fb.retrieve_all()
	_check(fgot.has("pig_iron") or fgot.has("iron"), "赤铁矿在高炉中炼出铁 %s" % str(fgot))
	_check(sim.lab.proven.has("pig_iron_smelting") or sim.lab.proven.has("iron_smelting") or sim.lab.proven.has("reduce_iron_oxide"), "炉内确证的工艺记入实验台手稿")

	# 5. 木柴燃尽留下草木灰；实验台可从燃着的炉子引火，不消耗燧石
	var ash_before = sim.inventory.get_count("wood_ash")
	sim.inventory.add_item("wood", 2)
	fb.add_fuel("wood")
	for i in range(160):
		sim.tick(1.0)
	_check(sim.inventory.get_count("wood_ash") > ash_before, "木柴燃尽后获得草木灰")
	_check(not fb.fire_lit and not sim.has_open_fire(), "燃料烧完后高炉熄火")
	# 实验台可从燃着的篝火引火，不消耗燧石
	var pit_hex = Vector2i(2, -1)
	sim.inventory.add_item("wood", 8)
	sim.inventory.add_item("stone", 8)
	_check(sim.build_structure("fire_pit", pit_hex), "篝火堆建造成功")
	var pit = sim.get_furnace_bench(pit_hex)
	pit.set_operation("dry_distillation")
	pit.add_fuel("wood")
	sim.inventory.add_item("flint", 1)
	_check(pit.ignite(), "篝火堆点火")
	sim.inventory.add_item("clay_pot", 1)
	sim.lab.set_container("clay_pot")
	sim.lab.set_operation("dry_distillation")
	sim.lab.add_fuel("wood")
	sim.inventory.remove_item("flint", sim.inventory.get_count("flint"))
	sim.inventory.remove_item("fire_seed", sim.inventory.get_count("fire_seed"))
	_check(sim.lab.ignite(), "篝火燃着时实验台不用燧石也能点火")
	sim.lab.extinguish()
	sim.lab.retrieve_all()
	sim.lab.set_container("")
	sim.built_furnaces.erase(pit_hex)
	sim.inventory.remove_item("clay_pot", sim.inventory.get_count("clay_pot"))

	# 6. 背包中持有的器皿可满足配方容器要求 (筛子 → 筛分硅砂)
	sim.lab_vessel.clear()
	sim.current_era = 2
	sim.researched_techs.append("sifting_technology")
	sim.inventory.add_item("sieve", 1)
	sim.lab.set_container("sieve")
	sim.lab.set_operation("sifting")
	sim.lab_vessel.add_substance("sand", 5.0)
	# 配方有 time_required，按其秒数推进一秒节拍
	var sift_secs = int(ceil(float(DataDB.get_formula("sift_silica_sand").get("time_required", 1.0))))
	for i in range(sift_secs):
		sim._on_second_tick()
	_check(sim.lab_vessel.has_substance("silica_sand"), "持有筛子时实验台可筛分出硅砂")

	# 7. 嬗变里程碑覆盖衰变 / 轰击类反应
	sim._on_solver_reaction_occurred("镭衰变产氡", ["radon"])
	_check(sim.completed_milestones.has("first_transmutation"), "衰变反应完成元素嬗变里程碑")

	# 8. 实验台：操作决定反应，点火消耗燃料，燃料决定温度
	var lab = sim.lab
	var ash_start = sim.inventory.get_count("wood_ash")
	sim.lab_vessel.clear()
	sim.lab_vessel.temperature = sim.ROOM_TEMP

	# 8a. 容器：必须放一件制造出的容器；加热要耐热容器；配方决定能用哪些容器；每次反应消耗耐久
	_check(lab.set_container(""), "撤下容器")
	sim.inventory.add_item("mud", 2)
	_check(not lab.add_reagent("mud", 1), "没放容器不能投料")
	_check(not lab.set_container("clay_pot"), "行囊里没有的容器放不上")
	sim.inventory.add_item("wooden_bucket", 1)
	_check(lab.set_container("wooden_bucket"), "放上木桶")
	sim.inventory.add_item("water", 2)
	lab.set_operation("stirring")
	lab.add_reagent("mud", 1)
	lab.add_reagent("water", 1)
	var clay_secs = int(ceil(float(DataDB.get_formula("clay_production").get("time_required", 1.0))))
	for i in range(clay_secs):
		sim._on_second_tick()
	_check(sim.lab_vessel.has_substance("clay"), "木桶里和泥制成粘土")
	_check(lab.durability_left("wooden_bucket") == LabBench.max_durable("wooden_bucket") - 1, "反应一次木桶耐久减 1 (%d)" % lab.durability_left("wooden_bucket"))
	_check(not lab.set_container("crucible"), "容器里有东西时不能换容器")
	lab.retrieve_all()
	sim.inventory.add_item("wood", 2)
	lab.set_operation("dry_distillation")
	lab.add_reagent("wood", 1)
	lab.add_fuel("wood")
	sim.inventory.add_item("flint", 1)
	_check(not lab.ignite(), "木桶不耐热，不能点火")
	_check(lab.diagnose()["state"] == "blocked" or lab.diagnose()["state"] == "unknown", "侦测卡不把木桶当成干馏容器")
	lab.retrieve_all()
	# 容器不对不反应：木桶里干馏 (已到温度) 不出木炭
	sim.lab_vessel.temperature = 900.0
	lab.add_reagent("wood", 1)
	sim._on_second_tick()
	sim._on_second_tick()
	_check(not sim.lab_vessel.has_substance("charcoal"), "木桶里不能干馏木炭")
	sim.lab_vessel.temperature = sim.ROOM_TEMP
	lab.retrieve_all()
	# 耐久用完容器损坏
	sim.inventory.wear["wooden_bucket"] = LabBench.max_durable("wooden_bucket") - 1
	lab.set_operation("stirring")
	lab.add_reagent("mud", 1)
	lab.add_reagent("water", 1)
	for i in range(clay_secs):
		sim._on_second_tick()
	_check(sim.inventory.get_count("wooden_bucket") == 0 and lab.container == "", "耐久用完木桶损坏并撤下")
	_check(lab.retrieve_all().get("clay", 0) == 1, "损坏后容器里的产物仍可取回")
	# 按手稿备料会自动换上合适的容器
	sim.inventory.add_item("crucible", 1)
	sim.inventory.add_item("wood", 1)
	lab.fragments.append("charcoal_production")
	_check(lab.prepare_from_fragment("charcoal_production").is_empty() and lab.container == "crucible", "按手稿备料换上坩埚")
	lab.retrieve_all()
	# 制作时写了 use 的器具只消耗耐久 (陶罐用窑炉烧制)
	sim.inventory.add_item("kiln", 1)
	sim.inventory.add_item("clay", 5)
	sim.researched_techs.append("pottery")
	sim.craft_tool("clay_pot")
	_check(sim.inventory.get_count("kiln") == 1 and sim.inventory.wear.get("kiln", 0) == 1, "烧陶罐消耗窑炉 1 点耐久而不是整座窑炉")

	lab.fuel_queue.clear()
	lab.cur_fuel = ""
	lab.cur_fuel_left = 0.0
	_check(lab.set_container("crucible"), "放上坩埚做冶炼")
	lab.set_operation("stirring")
	sim.lab_vessel.add_substance("malachite", 2.0)
	sim.lab_vessel.add_substance("charcoal", 2.0)
	sim.lab_vessel.temperature = 1200.0
	sim._on_second_tick()
	_check(not sim.lab_vessel.has_substance("copper"), "搅拌时即使高温也不炼铜 (操作不对)")
	sim.lab_vessel.temperature = sim.ROOM_TEMP
	_check(lab.set_operation("roasting"), "可以切换到焙烧")
	_check(not lab.ignite(), "没有燃料不能点火")
	sim.inventory.add_item("wood", 3)
	_check(lab.add_fuel("wood"), "投入原木作燃料")
	sim.inventory.remove_item("flint", sim.inventory.get_count("flint"))
	sim.inventory.remove_item("fire_seed", sim.inventory.get_count("fire_seed"))
	_check(not lab.ignite(), "没有火种或燧石不能点火")
	sim.inventory.add_item("flint", 1)
	_check(lab.ignite() and sim.inventory.get_count("flint") == 0, "用燧石点火，燧石消耗 1 块")
	for i in range(100):
		sim.tick(0.1)
	_check(sim.lab_vessel.temperature > 900.0 and sim.lab_vessel.temperature <= 974.0, "原木火焰升温到约 700 ℃ 为止 (%.0f K)" % sim.lab_vessel.temperature)
	_check(not sim.lab_vessel.has_substance("copper"), "原木火焰温度不够炼铜")
	var diag = lab.diagnose()
	_check(diag["state"] == "unknown", "没有手稿时侦测卡不透露配方 (%s)" % diag["state"])
	lab.fragments.append("copper_smelting")
	diag = lab.diagnose()
	_check(diag["state"] == "blocked" and diag["text"].contains("加热到"), "有手稿时提示温度不够")
	sim.inventory.add_item("charcoal", 2)
	lab.add_fuel("charcoal")
	for i in range(400):
		sim.tick(0.1)
		if sim.lab_vessel.has_substance("copper"): break
	_check(sim.lab_vessel.has_substance("copper"), "原木烧完换木炭后炼出铜")
	_check(lab.proven.has("copper_smelting") and sim.unlocked_blueprints.has("copper_smelting"), "第一次做成即确证并生成蓝图")
	_check(sim.inventory.get_count("wood_ash") > ash_start, "原木燃尽留下草木灰")
	var got = lab.retrieve_all()
	_check(got.get("copper", 0) >= 1 and sim.lab_vessel.components.is_empty(), "取回产物：铜 ×%d" % got.get("copper", 0))
	sim.lab_vessel.add_substance("stone", 3.0)
	sim.inventory.remove_item("stone", sim.inventory.get_count("stone"))
	lab.retrieve_all()
	_check(sim.inventory.get_count("stone") == 3, "没反应的原料原样退回")
	for i in range(1200):
		sim.tick(0.1)
	_check(not lab.fire_lit and sim.lab_vessel.temperature < 400.0, "燃料烧完后熄火并冷却")
	# 操作按时代解锁
	sim.current_era = 1
	_check(lab.op_lock_reason("electrolysis").contains("电化学时代"), "电解在电化学时代解锁 (%s)" % lab.op_lock_reason("electrolysis"))
	# 电解：没有电池不反应，接入伏打电池后电解水
	sim.current_era = 3
	sim.researched_techs.append("electrochemistry")
	_check(lab.set_operation("electrolysis"), "研发电化学后可以电解")
	sim.lab_vessel.clear()
	sim.inventory.add_item("beaker", 1)
	_check(lab.set_container("beaker"), "电解水改用烧杯")
	sim.lab_vessel.add_substance("water", 2.0)
	sim._on_second_tick()
	_check(not sim.lab_vessel.has_substance("oxygen"), "未通电不电解")
	sim.inventory.add_item("battery", 1)
	_check(lab.connect_power("battery"), "接入伏打电池")
	for i in range(30):
		sim.tick(0.1)
	_check(not sim.lab_vessel.has_substance("oxygen") and not sim.lab_vessel.has_substance("water"), "不集气时电解产生的氢气、氧气逸散")
	# 追加操作：排水集气需要集气技术、集气瓶和水
	_check(not lab.toggle_chain("gas_collecting"), "没有集气技术不能集气")
	sim.researched_techs.append("gas_collection")
	sim.inventory.add_item("gas_bottle", 1)
	sim.inventory.add_item("water", 1)
	_check(lab.toggle_chain("gas_collecting"), "研发集气技术并持有集气瓶后可勾选排水集气")
	_check(lab.toggle_chain("gas_collecting_air") and lab.chain_ops == ["gas_collecting_air"], "两种集气方式只保留一种")
	sim.lab_vessel.add_substance("water", 2.0)
	lab.power_left = 0.0
	sim.inventory.add_item("battery", 1)
	lab.connect_power("battery")
	for i in range(30):
		sim.tick(0.1)
	_check(sim.lab_vessel.has_substance("oxygen") and sim.lab_vessel.has_substance("hydrogen"), "勾选集气后收集到氢气和氧气")
	lab.toggle_chain("gas_collecting_air")
	sim.lab_vessel.clear()
	# 手稿：研发科技得到相关手稿
	var before = lab.fragments.size()
	lab.seen_items["clay"] = true
	lab.on_tech("pottery")
	_check(lab.fragments.size() == before + 1, "研发陶器制作后获得一份相关手稿")
	var txt = lab.fragment_text("charcoal_production", "#000", "#111", "#999")
	_check(txt.contains("木") and not txt.contains("#wood#"), "手稿正文替换物品与操作名")

	# 9. 作业按到期时间完成，而不是等到下一个整秒
	sim.task_queue.clear()
	sim.active_task = {
		"id": 999, "hex_q": 0, "hex_r": 0, "target_key": "stone", "yield_amount": 1,
		"repeat_count": 1, "current_cycle": 1, "time_required": 0.3,
		"begin_time": Time.get_ticks_msec() - 400
	}
	sim._second_accumulator = 0.0
	sim.tick(0.016)
	_check(sim.active_task.is_empty(), "0.3s 作业在到期后的下一帧完成")

	# 9b. 空地挖泥土：只在没有可采资源的陆地上挖，不限量；湖边挖到粘土
	var ms = Simulation.new()
	ms.reset_to_new_game()
	var res_hex := Vector2i(9999, 9999)
	var shore_hex := Vector2i(9999, 9999)
	var inland_hex := Vector2i(9999, 9999)
	for h in ms.world_biomes.keys():
		if Simulation._ring(h) > 5 or ms.world_biomes[h] == Simulation.B_LAKE:
			continue
		if res_hex == Vector2i(9999, 9999) and not ms.get_tile_available_resources(h).is_empty():
			res_hex = h
		elif ms.is_near_water(h) and shore_hex == Vector2i(9999, 9999):
			shore_hex = h
		elif not ms.is_near_water(h) and h != res_hex and inland_hex == Vector2i(9999, 9999):
			inland_hex = h
	_check(not ms.can_dig_mud(res_hex), "还有资源的地块不能挖泥土")
	ms.tile_resources[inland_hex] = {}
	ms.tile_resources[shore_hex] = {}
	_check(ms.can_dig_mud(inland_hex) and ms.can_dig_mud(shore_hex), "清空资源的陆地可以挖泥土")
	var lake_hex := Vector2i(9999, 9999)
	for h in ms.world_biomes.keys():
		if ms.world_biomes[h] == Simulation.B_LAKE:
			lake_hex = h
			break
	ms.tile_resources[lake_hex] = {}
	_check(not ms.can_dig_mud(lake_hex), "湖面不能挖泥土")
	for target in [inland_hex, shore_hex]:
		ms.active_task.clear()
		ms.task_queue.clear()
		_check(ms.queue_hex_harvest(target, "mud", 40), "空地可下发挖泥土 ×40")
		for i in range(40):
			ms.active_task["begin_time"] = Time.get_ticks_msec() - 2000
			ms.tick(0.016)
	_check(ms.inventory.get_count("mud") == 80, "两块空地各挖出 40 份泥土 (%d)" % ms.inventory.get_count("mud"))
	_check(ms.can_dig_mud(inland_hex), "泥土不限量，挖完仍可继续挖")
	_check(ms.inventory.get_count("clay") > 0, "湖边挖泥土掉落粘土 ×%d" % ms.inventory.get_count("clay"))

	# 9b. 打水：湖泊任何地块持有木桶即可打水，不限量，木桶不消耗
	var lakes: Array = []
	for h in ms.world_biomes.keys():
		if ms.world_biomes[h] == Simulation.B_LAKE:
			lakes.append(h)
	# 第一格放领地内的湖面 (下发作业要求在领地内)
	lakes.sort_custom(func(a, b): return Simulation._ring(a) < Simulation._ring(b))
	ms.inventory.remove_item("wooden_bucket", ms.inventory.get_count("wooden_bucket"))
	ms.active_task.clear()
	ms.task_queue.clear()
	_check(not lakes.is_empty(), "地图上有湖泊 (%d 格)" % lakes.size())
	_check(not ms.queue_hex_harvest(lakes[0], "water", 1), "没有木桶不能打水")
	_check(ms.get_tile_tool_hint(lakes[0]).contains("木桶"), "湖面提示需要木桶")
	ms.inventory.add_item("wooden_bucket", 1)
	var all_lakes_ok := true
	for h in lakes:
		var av = ms.get_tile_available_resources(h)
		if av.is_empty() or av[0]["key"] != "water" or int(av[0]["amount"]) != -1:
			all_lakes_ok = false
	_check(all_lakes_ok, "持有木桶后每一格湖面左键都是打水，不限量")
	ms.tile_resources[lakes[0]] = {} # 盐和沙采完的湖面仍可打水
	_check(ms.queue_hex_harvest(lakes[0], "water", 30), "盐沙采完的湖面仍可打水 ×30")
	var water_before = ms.inventory.get_count("water")
	for i in range(30):
		ms.active_task["begin_time"] = Time.get_ticks_msec() - 2000
		ms.tick(0.016)
	_check(ms.inventory.get_count("water") == water_before + 30, "打水 30 次得到 30 份水")
	_check(ms.inventory.get_count("wooden_bucket") == 1, "打水不消耗木桶")
	_check(ms.can_draw_water(lakes[0]) and not ms.depleted_tiles.has(lakes[0]), "湖面不会被打干")
	var land := Vector2i(9999, 9999)
	for h in ms.world_biomes.keys():
		if ms.world_biomes[h] != Simulation.B_LAKE:
			land = h
			break
	_check(not ms.queue_hex_harvest(land, "water", 1), "陆地上不能打水")

	# 10. 科技树布局：卡片不重叠、连线从左到右、跨列连线的途经点不压在卡片上
	var Layout = load("res://src/ui/tech_tree_layout.gd")
	var lay = Layout.compute(DataDB.techs)
	var rects := {}
	for k in lay.positions.keys():
		rects[k] = Rect2(lay.positions[k], Vector2(Layout.CARD_W, Layout.CARD_H))
	var overlap := 0
	var ks = rects.keys()
	for i in ks.size():
		for j in range(i + 1, ks.size()):
			if rects[ks[i]].intersects(rects[ks[j]]): overlap += 1
	_check(rects.size() == DataDB.techs.size() and overlap == 0, "科技树 %d 张卡片互不重叠" % rects.size())
	var backward := 0
	var through := 0
	for k in DataDB.techs.keys():
		for p in DataDB.techs[k].get("required_techs", []):
			if lay.layers[p] >= lay.layers[k]: backward += 1
			for pt in lay.routes.get("%s|%s" % [k, p], PackedVector2Array()):
				for r in rects.values():
					if r.grow(-1.0).has_point(pt + Vector2(1, 0)): through += 1
	_check(backward == 0, "所有前置连线都从左列指向右列")
	_check(through == 0, "跨列连线不穿过卡片")
	_check(int(lay.crossings) <= 40, "连线交叉数 %d 不超过 40" % lay.crossings)

	if _failed == 0:
		print("🎉 进程死锁修复测试全部通过")
		quit(0)
	else:
		printerr("❌ %d 项失败" % _failed)
		quit(1)
