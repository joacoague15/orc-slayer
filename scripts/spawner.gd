# scripts/spawner.gd
extends Node2D

signal wave_started(wave_number: int, kills_required: int)
signal wave_completed(wave_number: int)
signal boss_wave_reached

const BOSS_WAVE_NUMBER: int = 7
const WAVE_CONFIGS: Array[Dictionary] = [
	{
		"number": 1,
		"kills_required": 12,
		"max_orcs": 10,
		"spawn_interval": 1.20,
		"weights": {"normal": 1.00, "scout": 0.00, "brute": 0.00, "archer": 0.00, "mage": 0.00, "berserker": 0.00},
	},
	{
		"number": 2,
		"kills_required": 18,
		"max_orcs": 16,
		"spawn_interval": 1.05,
		"weights": {"normal": 0.70, "scout": 0.20, "brute": 0.00, "archer": 0.10, "mage": 0.00, "berserker": 0.00},
	},
	{
		"number": 3,
		"kills_required": 24,
		"max_orcs": 24,
		"spawn_interval": 0.90,
		"weights": {"normal": 0.52, "scout": 0.16, "brute": 0.00, "archer": 0.20, "mage": 0.12, "berserker": 0.00},
	},
	{
		"number": 4,
		"kills_required": 30,
		"max_orcs": 34,
		"spawn_interval": 0.78,
		"weights": {"normal": 0.42, "scout": 0.12, "brute": 0.08, "archer": 0.22, "mage": 0.12, "berserker": 0.04},
	},
	{
		"number": 5,
		"kills_required": 38,
		"max_orcs": 48,
		"spawn_interval": 0.66,
		"weights": {"normal": 0.32, "scout": 0.10, "brute": 0.10, "archer": 0.24, "mage": 0.16, "berserker": 0.08},
	},
	{
		"number": 6,
		"kills_required": 48,
		"max_orcs": 64,
		"spawn_interval": 0.54,
		"weights": {"normal": 0.24, "scout": 0.08, "brute": 0.12, "archer": 0.25, "mage": 0.18, "berserker": 0.13},
	},
	{
		"number": 7,
		"kills_required": 0,
		"max_orcs": 0,
		"spawn_interval": 0.0,
		"weights": {"normal": 0.00, "scout": 0.00, "brute": 0.00, "archer": 0.00, "mage": 0.00, "berserker": 0.00},
	},
]

@export var orc_normal_scene: PackedScene
@export var orc_scout_scene: PackedScene
@export var orc_brute_scene: PackedScene
@export var orc_archer_scene: PackedScene
@export var orc_mage_scene: PackedScene
@export var orc_berserker_scene: PackedScene

@export var spawn_distance_buffer: float = 50.0

var time_since_last_spawn: float = 0.0
var spawning_enabled: bool = true
var current_wave_index: int = 0
var current_wave_kills: int = 0
var wave_active: bool = false

var player: Node2D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if GameState.game_over:
		return
	if not spawning_enabled:
		return
	if not wave_active:
		return
	
	if not is_instance_valid(player):
		return
	
	time_since_last_spawn += delta
	var wave := get_current_wave()
	if time_since_last_spawn >= float(wave["spawn_interval"]):
		time_since_last_spawn = 0.0
		if get_orc_count() < int(wave["max_orcs"]):
			spawn_orc()

func start_waves() -> void:
	current_wave_index = 0
	current_wave_kills = 0
	_start_current_wave()

func notify_enemy_killed() -> void:
	if not wave_active:
		return
	var wave := get_current_wave()
	if int(wave["number"]) >= BOSS_WAVE_NUMBER:
		return
	current_wave_kills += 1
	if current_wave_kills >= int(wave["kills_required"]):
		_complete_current_wave()

func start_next_wave() -> void:
	if current_wave_index >= WAVE_CONFIGS.size() - 1:
		return
	current_wave_index += 1
	current_wave_kills = 0
	_start_current_wave()

func _start_current_wave() -> void:
	var wave := get_current_wave()
	time_since_last_spawn = 0.0
	spawning_enabled = int(wave["number"]) < BOSS_WAVE_NUMBER
	wave_active = spawning_enabled
	wave_started.emit(int(wave["number"]), int(wave["kills_required"]))
	if int(wave["number"]) == BOSS_WAVE_NUMBER:
		boss_wave_reached.emit()

func _complete_current_wave() -> void:
	spawning_enabled = false
	wave_active = false
	wave_completed.emit(int(get_current_wave()["number"]))

func spawn_orc() -> void:
	var scene := pick_orc_scene()
	if not scene:
		return
	var orc := scene.instantiate()
	# Posicionar ANTES de add_child para que _ready() corra con la pos correcta
	orc.position = get_spawn_position()
	get_parent().add_child(orc)

func pick_orc_scene() -> PackedScene:
	var weights: Dictionary = get_current_wave()["weights"]
	return _pick_weighted_orc_scene([
		{"key": "normal", "scene": orc_normal_scene, "weight": weights["normal"]},
		{"key": "scout", "scene": orc_scout_scene, "weight": weights["scout"]},
		{"key": "brute", "scene": orc_brute_scene, "weight": weights["brute"]},
		{"key": "archer", "scene": orc_archer_scene, "weight": weights["archer"]},
		{"key": "mage", "scene": orc_mage_scene, "weight": weights["mage"]},
		{"key": "berserker", "scene": orc_berserker_scene, "weight": weights["berserker"]},
	])

func _pick_weighted_orc_scene(entries: Array) -> PackedScene:
	var total_weight := 0.0
	for entry in entries:
		total_weight += _get_entry_weight(entry)
	
	if total_weight <= 0.0:
		return null
	
	var roll := randf() * total_weight
	var cursor := 0.0
	var fallback_scene: PackedScene = null
	for entry in entries:
		var entry_weight := _get_entry_weight(entry)
		if entry_weight <= 0.0:
			continue
		fallback_scene = entry["scene"]
		cursor += entry_weight
		if roll <= cursor:
			return entry["scene"]
	
	return fallback_scene

func _get_entry_weight(entry: Dictionary) -> float:
	if not entry["scene"]:
		return 0.0
	var base_weight: float = max(float(entry["weight"]), 0.0)
	return base_weight * GameState.get_spawn_enemy_weight_factor(entry["key"])

func get_spawn_position() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var spawn_radius: float = max(viewport_size.x, viewport_size.y) / 2.0 + spawn_distance_buffer
	
	var angle := randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * spawn_radius
	return player.global_position + offset

func get_orc_count() -> int:
	return get_tree().get_nodes_in_group("orcs").size()

func set_spawning_enabled(enabled: bool) -> void:
	spawning_enabled = enabled

func get_current_wave() -> Dictionary:
	return WAVE_CONFIGS[current_wave_index]

func get_current_wave_number() -> int:
	return int(get_current_wave()["number"])

func get_current_wave_kills() -> int:
	return current_wave_kills

func get_current_wave_kills_required() -> int:
	return int(get_current_wave()["kills_required"])
