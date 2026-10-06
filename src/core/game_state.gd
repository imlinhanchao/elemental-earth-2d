# game_state.gd
# 全局游戏状态管理器 (Autoload): 透明转发壳 (Proxy Shell)，对接底层核心 Simulation 模拟层
extends Node

const Simulation = preload("res://src/core/simulation.gd")
const HexWorldGenerator = preload("res://src/core/hex_world_generator.gd")
const ProcessBlueprint = preload("res://src/core/process_blueprint.gd")
const PlayerInventory = preload("res://src/core/player_inventory.gd")
const ChemistrySolver = preload("res://src/core/chemistry_solver.gd")
const MixtureBuffer = preload("res://src/core/mixture_buffer.gd")

signal element_discovered(element_number: int, item_key: String)
signal notification_posted(text: String, color: Color)
signal era_advanced(old_era: int, new_era: int, era_name: String)
signal blueprint_unlocked(blueprint: ProcessBlueprint)
signal tool_equipped(tool_key: String)
signal tech_researched(tech_key: String)
signal milestone_completed(milestone_key: String)

signal task_queue_changed
signal task_started(task: Dictionary)
signal task_progress_updated(task: Dictionary, percent: float, remaining_time: float)
signal task_completed(task: Dictionary)
signal task_cancelled(task: Dictionary)

signal tile_depleted(hex: Vector2i)
signal tile_respawned(hex: Vector2i)
signal structure_built(structure_key: String, hex: Vector2i)

signal tutorial_step_changed(step: int)
signal tutorial_state_changed(active: bool)
signal tutorial_completed

var is_tutorial_active: bool = false
var tutorial_step: int = 0

var sim: Simulation

var inventory: PlayerInventory:
	get: return sim.inventory

var solver: ChemistrySolver:
	get: return sim.solver

var lab_vessel: MixtureBuffer:
	get: return sim.lab_vessel

var discovered_elements: Array[int]:
	get: return sim.discovered_elements
	set(v): sim.discovered_elements = v

var unlocked_blueprints: Dictionary:
	get: return sim.unlocked_blueprints
	set(v): sim.unlocked_blueprints = v

var equipped_tools: Dictionary:
	get: return sim.equipped_tools
	set(v): sim.equipped_tools = v

var researched_techs: Array[String]:
	get: return sim.researched_techs
	set(v): sim.researched_techs = v

var completed_milestones: Array[String]:
	get: return sim.completed_milestones
	set(v): sim.completed_milestones = v

var current_era: int:
	get: return sim.current_era
	set(v): sim.current_era = v

var playtime_seconds: float:
	get: return sim.playtime_seconds
	set(v): sim.playtime_seconds = v

var task_queue: Array[Dictionary]:
	get: return sim.task_queue
	set(v): sim.task_queue = v

var active_task: Dictionary:
	get: return sim.active_task
	set(v): sim.active_task = v

var depleted_tiles: Dictionary:
	get: return sim.depleted_tiles
	set(v): sim.depleted_tiles = v

var world_resources: Dictionary:
	get: return sim.world_resources

var world_biomes: Dictionary:
	get: return sim.world_biomes

var built_furnaces: Dictionary:
	get: return sim.built_furnaces

var built_reactors: Dictionary:
	get: return sim.built_reactors

var ERA_NAMES: Array[String]:
	get: return sim.ERA_NAMES

const MAX_QUEUE_SIZE: int = Simulation.MAX_QUEUE_SIZE

func _init() -> void:
	sim = Simulation.new()
	_connect_sim_signals()

func _ready() -> void:
	print("[GameState] 模拟层已就绪，当前时代: %s" % ERA_NAMES[current_era])
	_setup_app_icon()

func _setup_app_icon() -> void:
	if ResourceLoader.exists("res://icon.png"):
		var tex = load("res://icon.png") as Texture2D
		if tex:
			var img = tex.get_image()
			if img:
				DisplayServer.set_icon(img)

func _connect_sim_signals() -> void:
	sim.element_discovered.connect(func(n, k): element_discovered.emit(n, k))
	sim.notification_posted.connect(func(t, c): notification_posted.emit(t, c))
	sim.era_advanced.connect(func(o, n, name): era_advanced.emit(o, n, name))
	sim.blueprint_unlocked.connect(func(bp): blueprint_unlocked.emit(bp))
	sim.tool_equipped.connect(func(k): tool_equipped.emit(k))
	sim.tech_researched.connect(func(k): tech_researched.emit(k))
	sim.milestone_completed.connect(func(k): milestone_completed.emit(k))
	sim.task_queue_changed.connect(func(): task_queue_changed.emit())
	sim.task_started.connect(func(t): task_started.emit(t))
	sim.task_progress_updated.connect(func(t, p, r): task_progress_updated.emit(t, p, r))
	sim.task_completed.connect(func(t): task_completed.emit(t))
	sim.task_cancelled.connect(func(t): task_cancelled.emit(t))
	sim.tile_depleted.connect(func(h): tile_depleted.emit(h))
	sim.tile_respawned.connect(func(h): tile_respawned.emit(h))
	sim.structure_built.connect(func(k, h): structure_built.emit(k, h))

func _process(delta: float) -> void:
	sim.tick(delta)

func post_notice(text: String, color: Color = Color.WHITE) -> void:
	sim.post_notice(text, color)

func post_notification(text: String, color: Color = Color.WHITE) -> void:
	sim.post_notice(text, color)

func unlock_element(elem_num: int, item_key: String) -> void:
	sim.unlock_element(elem_num, item_key)

func unlock_blueprint(bp: ProcessBlueprint) -> void:
	sim.unlock_blueprint(bp)

func equip_tool(slot: String, tool_key: String) -> void:
	sim.equip_tool(slot, tool_key)

func advance_era(target_era: int) -> void:
	sim.advance_era(target_era)

func get_current_territory_radius() -> int:
	return sim.get_current_territory_radius()

func is_hex_in_territory(q: int, r: int) -> bool:
	return sim.is_hex_in_territory(q, r)

func is_pos_in_territory(pos: Vector2) -> bool:
	var h = HexWorldGenerator.pixel_to_hex(pos)
	return sim.is_hex_in_territory(h.x, h.y)

func is_tile_depleted(hex: Vector2i) -> bool:
	return sim.is_tile_depleted(hex)

func get_hex_resource(hex: Vector2i) -> String:
	return sim.get_hex_resource(hex)

func add_task(task_data: Dictionary) -> bool:
	return sim.add_task(task_data)

func cancel_task(task_id: int) -> void:
	sim.cancel_task(task_id)

func calculate_task_duration(item_key: String) -> float:
	return sim.calculate_task_duration(item_key)

func can_mine(item_key: String) -> Dictionary:
	return sim.can_mine(item_key)

var tile_resources: Dictionary:
	get: return sim.tile_resources

func get_tile_resources(hex: Vector2i) -> Dictionary:
	return sim.get_tile_resources(hex)

func get_tile_available_resources(hex: Vector2i) -> Array[Dictionary]:
	return sim.get_tile_available_resources(hex)

func consume_tile_resource(hex: Vector2i, item_key: String, count: int = 1) -> int:
	return sim.consume_tile_resource(hex, item_key, count)

func queue_hex_harvest(hex: Vector2i, item_key: String, count: int = 1, world_pos: Vector2 = Vector2.ZERO) -> bool:
	return sim.queue_hex_harvest(hex, item_key, count, world_pos)

func queue_hex_mine(hex: Vector2i, item_key: String, count: int = 1, world_pos: Vector2 = Vector2.ZERO) -> bool:
	return sim.queue_hex_mine(hex, item_key, count, world_pos)

func queue_hex_water(hex: Vector2i, count: int = 1, world_pos: Vector2 = Vector2.ZERO) -> bool:
	return sim.queue_hex_water(hex, count, world_pos)

func queue_hex_forage(hex: Vector2i, biome_name: String, count: int = 1, world_pos: Vector2 = Vector2.ZERO) -> bool:
	return sim.queue_hex_forage(hex, biome_name, count, world_pos)

func get_active_task_hex() -> Vector2i:
	return sim.get_active_task_hex()

func craft_tool(recipe_key: String) -> bool:
	return sim.craft_tool(recipe_key)

func build_structure(structure_key: String, hex: Vector2i) -> bool:
	return sim.build_structure(structure_key, hex)

func furnace_add_fuel(hex: Vector2i) -> bool:
	return sim.furnace_add_fuel(hex)

func furnace_add_ore(hex: Vector2i, key: String, amount: int = 1) -> bool:
	return sim.furnace_add_ore(hex, key, amount)

func reactor_install_blueprint(hex: Vector2i, bp_id: String) -> bool:
	return sim.reactor_install_blueprint(hex, bp_id)

func get_formatted_playtime() -> String:
	return sim.get_formatted_playtime()

func can_research_tech(tech_key: String) -> bool:
	return sim.can_research_tech(tech_key)

func research_tech(tech_key: String) -> bool:
	return sim.research_tech(tech_key)

func complete_milestone(milestone_key: String) -> void:
	sim.complete_milestone(milestone_key)

func reset_to_new_game() -> void:
	sim.reset_to_new_game()
	is_tutorial_active = false
	tutorial_step = 0

func start_tutorial() -> void:
	is_tutorial_active = true
	tutorial_step = 0
	tutorial_state_changed.emit(true)
	tutorial_step_changed.emit(0)

func next_tutorial_step() -> void:
	tutorial_step += 1
	tutorial_step_changed.emit(tutorial_step)

func set_tutorial_step(step: int) -> void:
	tutorial_step = step
	tutorial_step_changed.emit(tutorial_step)

func complete_tutorial() -> void:
	is_tutorial_active = false
	SettingsManager.set_tutorial_completed(true)
	tutorial_state_changed.emit(false)
	tutorial_completed.emit()
	post_notice("恭喜完成【文明拓荒教程】！现在尽情谱写你的文明进化史册吧！", Color(0.2, 0.9, 0.5))

func skip_tutorial() -> void:
	is_tutorial_active = false
	SettingsManager.set_tutorial_completed(true)
	tutorial_state_changed.emit(false)
	tutorial_completed.emit()
	post_notice("已跳过新手教程，进入自由沙盒探索模式！", Color(0.38, 0.82, 1.0))
