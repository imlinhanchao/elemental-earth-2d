# music_manager.gd
# 背景音乐管理器 (autoload)：主菜单 / 各时代曲目交叉淡化，时代跃迁与元素发现播放短乐句并压低背景音乐
# 曲目由 tools/compose_music.py 程序化生成；时代曲目路径读 data/eras.json 的 bgm 字段
extends Node

const SaveManager = preload("res://src/core/save_manager.gd")

const BGM_BUS := &"BGM"
const MENU_TRACK := "res://assets/audio/bgm/menu.ogg"
const STINGER_ERA := "res://assets/audio/bgm/stinger_era.ogg"
const STINGER_DISCOVERY := "res://assets/audio/bgm/stinger_discovery.ogg"

const FADE_TIME := 2.5      # 切曲交叉淡化秒数
const DUCK_DB := -12.0      # 短乐句播放时背景音乐压低量
const SILENT_DB := -60.0

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _stinger: AudioStreamPlayer
var current_track: String = ""
var _pending_track: String = "" # 短乐句结束后再切入的曲目
var _ducked: bool = false
var _tweens: Array = [null, null]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # 暂停菜单打开时音乐照常播放
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = BGM_BUS
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)
	_stinger = AudioStreamPlayer.new()
	_stinger.bus = BGM_BUS
	add_child(_stinger)
	_stinger.finished.connect(_on_stinger_finished)

	GameState.era_advanced.connect(_on_era_advanced)
	GameState.element_discovered.connect(func(_n, _k): play_stinger(STINGER_DISCOVERY))

func play_menu() -> void:
	play_track(MENU_TRACK)

func play_era(era: int) -> void:
	play_track(era_track(era))

static func era_track(era: int) -> String:
	return str(DataDB.get_era(era).get("bgm", ""))

func play_track(path: String, fade: float = FADE_TIME) -> void:
	if path == "" or path == current_track:
		return
	if _stinger.playing:
		_pending_track = path # 等短乐句结束再切
		return
	var stream = _load_loop(path)
	if stream == null:
		return
	current_track = path
	var old := _active
	_active = 1 - _active
	var p := _players[_active]
	p.stream = stream
	p.volume_db = SILENT_DB
	p.play()
	_fade(_active, _target_db(), fade)
	_fade(old, SILENT_DB, fade, true)

func play_stinger(path: String) -> void:
	# 时代跃迁乐句优先，不被同时到达的元素发现乐句打断
	if _stinger.playing and _stinger.stream and _stinger.stream.resource_path == STINGER_ERA and path != STINGER_ERA:
		return
	var stream = load(path) if ResourceLoader.exists(path) else null
	if stream == null:
		return
	_stinger.stream = stream
	_stinger.play()
	_ducked = true
	_fade(_active, _target_db(), 0.4)

func stop(fade: float = FADE_TIME) -> void:
	current_track = ""
	_pending_track = ""
	for i in 2:
		_fade(i, SILENT_DB, fade, true)

func is_ducked() -> bool:
	return _ducked

func _on_era_advanced(old_era: int, new_era: int, _name: String) -> void:
	# 只在大世界里跟随时代。读档 / 新游戏也会发出该信号 (old_era = 0)：
	# 真正的跃迁总是前进一个时代，且正在播放旧时代的曲目，只有这时才放乐句
	if not _in_world():
		return
	if new_era == old_era + 1 and current_track == era_track(old_era) and not SaveManager.is_loading:
		play_stinger(STINGER_ERA)
	play_era(new_era)

func _on_stinger_finished() -> void:
	_ducked = false
	if _pending_track != "":
		var t := _pending_track
		_pending_track = ""
		play_track(t)
	else:
		_fade(_active, _target_db(), 1.2)

func _in_world() -> bool:
	return get_tree().get_first_node_in_group("world") != null

func _target_db() -> float:
	return DUCK_DB if _ducked else 0.0

func _load_loop(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("[MusicManager] 找不到曲目 %s" % path)
		return null
	var s = load(path)
	if s is AudioStreamOggVorbis:
		s.loop = true
	return s

func _fade(i: int, db: float, time: float, stop_after: bool = false) -> void:
	if _tweens[i]:
		_tweens[i].kill()
	var p := _players[i]
	var tw := create_tween()
	tw.tween_property(p, "volume_db", db, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if stop_after:
		tw.tween_callback(p.stop)
	_tweens[i] = tw
