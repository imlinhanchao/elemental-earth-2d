# tools/dump_map_resources.gd
# 开发工具：用多个种子生成大世界，输出每种地块资源在最差种子下的最近环距与出现格数 (供 tools/check_progression.py 使用)
# 用法: Godot --headless --path . -s res://tools/dump_map_resources.gd
extends SceneTree

const SEED_COUNT := 40

func _initialize() -> void:
	var DataDB = load("res://src/core/data_db.gd")
	DataDB.initialize()
	var sim = load("res://src/core/simulation.gd").new()
	var seeds: Array = [12345]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in range(SEED_COUNT):
		seeds.append(rng.randi_range(1, 2000000000))
	var worst := {}
	for s in seeds:
		sim.init_world_map(s, 18)
		var out := {}
		for c in sim.tile_resources.keys():
			var d = (abs(c.x) + abs(c.x + c.y) + abs(c.y)) / 2
			# 湖面的水不限量、不记在储量里，按水域地块计入
			var keys: Array = sim.tile_resources[c].keys()
			if sim.is_water_hex(c) and not keys.has("water"):
				keys.append("water")
			for k in keys:
				if not out.has(k):
					out[k] = {"min_dist": d, "tiles": 0}
				out[k]["min_dist"] = min(out[k]["min_dist"], d)
				out[k]["tiles"] += 1
		# 开局 (半径 5) 内的主资源地块数，用于检查开局可玩性
		var start := {}
		for c in sim.world_resources.keys():
			if (abs(c.x) + abs(c.x + c.y) + abs(c.y)) / 2 <= 5:
				var k = sim.world_resources[c]
				start[k] = start.get(k, 0) + 1
		for k in ["wood", "stone", "stick", "flint"]:
			if start.get(k, 0) < 3:
				print("MAPWARN seed=%d 开局 %s 只有 %d 格" % [s, k, start.get(k, 0)])
		# 记录各资源在全部种子中最差的情况；某个种子缺失的资源记为不可达
		for k in out.keys():
			if not worst.has(k):
				worst[k] = {"min_dist": out[k]["min_dist"], "tiles": out[k]["tiles"], "seeds": 0}
			worst[k]["min_dist"] = max(worst[k]["min_dist"], out[k]["min_dist"])
			worst[k]["tiles"] = min(worst[k]["tiles"], out[k]["tiles"])
			worst[k]["seeds"] += 1
	for k in worst.keys():
		if worst[k]["seeds"] < seeds.size():
			worst[k]["min_dist"] = 99
		worst[k].erase("seeds")
	print("MAPDUMP ", JSON.stringify(worst))
	quit()
