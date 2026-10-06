# 测量启动与存档各阶段耗时 (headless)。用法: Godot --headless --path . -s res://tools/profile_load.gd
extends SceneTree

func _ms(t0: int) -> String:
	return "%.1fms" % ((Time.get_ticks_usec() - t0) / 1000.0)

func _initialize() -> void:
	var t = Time.get_ticks_usec()
	var font = load("res://assets/fonts/NotoSansSC.ttf")
	print("PROF font_load ", _ms(t))
	t = Time.get_ticks_usec()
	var ps: PackedScene = load("res://src/scenes/world.tscn")
	print("PROF world_tscn_load ", _ms(t))
	t = Time.get_ticks_usec()
	var w = ps.instantiate()
	print("PROF world_instantiate ", _ms(t))
	await process_frame
	t = Time.get_ticks_usec()
	root.add_child(w)
	print("PROF world_ready ", _ms(t), " nodes=", w.get_node("Entities").get_child_count() if w.has_node("Entities") else -1)
	for i in range(4):
		t = Time.get_ticks_usec()
		await process_frame
		print("PROF frame_", i, " ", _ms(t))
	# 稳态帧时间
	var worst := 0.0
	var total := 0.0
	for i in range(120):
		t = Time.get_ticks_usec()
		await process_frame
		var d = (Time.get_ticks_usec() - t) / 1000.0
		total += d
		worst = maxf(worst, d)
	print("PROF steady avg=%.2fms worst=%.2fms" % [total / 120.0, worst])
	var SM = load("res://src/core/save_manager.gd")
	t = Time.get_ticks_usec()
	SM.save_to_slot("prof_slot", w)
	print("PROF save ", _ms(t))
	var p = SM.get_slot_path("prof_slot")
	print("PROF save_bytes ", FileAccess.get_file_as_bytes(p).size())
	t = Time.get_ticks_usec()
	SM.load_from_slot("prof_slot", w)
	print("PROF load ", _ms(t))
	SM.delete_slot("prof_slot")
	var hud = w.get_node_or_null("HUD")
	if hud and hud.has_method("_populate_drawer"):
		for pass_i in range(2):
			for tab in range(1, 7):
				t = Time.get_ticks_usec()
				hud._populate_drawer(tab)
				print("PROF drawer_%s_%d %s" % ["first" if pass_i == 0 else "again", tab, _ms(t)])
	var tl = w.get_node_or_null("TerrainLayer")
	if tl:
		t = Time.get_ticks_usec()
		tl.queue_redraw()
		await process_frame
		print("PROF terrain_redraw_frame ", _ms(t))
	quit(0)
