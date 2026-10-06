# tools/dump_map_resources.gd
# 开发工具：按固定种子生成大世界，输出每种地块资源的最近环距与出现格数 (供 tools/check_progression.py 使用)
# 用法: Godot --headless --path . -s res://tools/dump_map_resources.gd
extends SceneTree

func _initialize() -> void:
	var DataDB = load("res://src/core/data_db.gd")
	DataDB.initialize()
	var sim = load("res://src/core/simulation.gd").new()
	sim.init_world_map(12345, 18)
	var out := {}
	for c in sim.tile_resources.keys():
		var d = (abs(c.x) + abs(c.x + c.y) + abs(c.y)) / 2
		for k in sim.tile_resources[c].keys():
			if not out.has(k):
				out[k] = {"min_dist": d, "tiles": 0}
			out[k]["min_dist"] = min(out[k]["min_dist"], d)
			out[k]["tiles"] += 1
	print("MAPDUMP ", JSON.stringify(out))
	quit()
