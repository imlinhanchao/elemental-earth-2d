# game_state.gd
# 全局游戏状态管理器 (Autoload): 转发壳 (Proxy Shell)，对接底层核心 Simulation 模拟层
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

signal task_queue_changed
signal task_started(task: Dictionary)
signal task_progress_updated(task: Dictionary, percent: float, remaining_time: float)
signal task_completed(task: Dictionary)
signal task_cancelled(task: Dictionary)

signal tile_depleted(hex: Vector2i)
signal tile_respawned(hex: Vector2i)

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

var current_era: int:
	get: return sim.current_era
	set(v): sim.current_era = v

var playtime_seconds: float:
	get: return sim.playtime_seconds
	set(v): sim.playtime_seconds = v

var task_queue: Array[Dictionary]:
	get: return sim.task_queue

var active_task: Dictionary:
	get: return sim.active_task

var depleted_tiles: Dictionary:
	get: return sim.depleted_tiles

var ERA_NAMES: Array[String]:
	get: return Simulation.ERA_NAMES

const MAX_QUEUE_SIZE: int = Simulation.MAX_QUEUE_SIZE

func _init() -> void:
	sim = Simulation.new()
	_connect_sim_signals()

func _ready() -> void:
	print("[GameState] 模拟层已就绪，当前时代: %s" % ERA_NAMES[current_era])

func _connect_sim_signals() -> void:
	sim.element_discovered.connect(func(n, k): element_discovered.emit(n, k))
	sim.notification_posted.connect(func(t, c): notification_posted.emit(t, c))
	sim.era_advanced.connect(func(o, n, name): era_advanced.emit(o, n, name))
	sim.blueprint_unlocked.connect(func(bp): blueprint_unlocked.emit(bp))
	sim.tool_equipped.connect(func(k): tool_equipped.emit(k))
	sim.task_queue_changed.connect(func(): task_queue_changed.emit())
	sim.task_started.connect(func(t): task_started.emit(t))
	sim.task_progress_updated.connect(func(t, p, r): task_progress_updated.emit(t, p, r))
	sim.task_completed.connect(func(t): task_completed.emit(t))
	sim.task_cancelled.connect(func(t): task_cancelled.emit(t))
	sim.tile_depleted.connect(func(h): tile_depleted.emit(h))
	sim.tile_respawned.connect(func(h): tile_respawned.emit(h))

func _process(delta: float) -> void:
	sim.tick(delta)

func post_notice(text: String, color: Color = Color.WHITE) -> void:
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

func add_task(task_data: Dictionary) -> bool:
	return sim.add_task(task_data)

func cancel_task(task_id: int) -> void:
	sim.cancel_task(task_id)

func calculate_task_duration(item_key: String) -> float:
	return sim.calculate_task_duration(item_key)

func can_mine(item_key: String) -> Dictionary:
	return sim.can_mine(item_key)

func get_formatted_playtime() -> String:
	return sim.get_formatted_playtime()

func reset_to_new_game() -> void:
	sim.reset_to_new_game()
