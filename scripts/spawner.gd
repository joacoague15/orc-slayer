# scripts/spawner.gd
extends Node2D

@export var orc_normal_scene: PackedScene
@export var orc_scout_scene: PackedScene
@export var orc_brute_scene: PackedScene

@export var initial_spawn_interval: float = 1.2
@export var min_spawn_interval: float = 0.2
@export var difficulty_step: float = 15.0
@export var difficulty_multiplier: float = 0.9
@export var max_orcs: int = 150
@export var spawn_distance_buffer: float = 50.0

var current_spawn_interval: float
var time_since_last_spawn: float = 0.0
var time_since_last_difficulty_increase: float = 0.0
var elapsed_time: float = 0.0

var player: Node2D

func _ready() -> void:
	current_spawn_interval = initial_spawn_interval
	player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if GameState.game_over:
		return
	
	if not is_instance_valid(player):
		return
	
	elapsed_time += delta
	time_since_last_spawn += delta
	time_since_last_difficulty_increase += delta
	
	if time_since_last_difficulty_increase >= difficulty_step:
		time_since_last_difficulty_increase = 0.0
		current_spawn_interval = max(
			min_spawn_interval,
			current_spawn_interval * difficulty_multiplier
		)
	
	if time_since_last_spawn >= current_spawn_interval:
		time_since_last_spawn = 0.0
		if get_orc_count() < max_orcs:
			spawn_orc()

func spawn_orc() -> void:
	var scene := pick_orc_scene()
	var orc := scene.instantiate()
	# Posicionar ANTES de add_child para que _ready() corra con la pos correcta
	orc.position = get_spawn_position()
	get_parent().add_child(orc)

func pick_orc_scene() -> PackedScene:
	var roll := randf()
	
	if elapsed_time < 15.0:
		return orc_normal_scene
	elif elapsed_time < 45.0:
		if roll < 0.3:
			return orc_scout_scene
		return orc_normal_scene
	elif elapsed_time < 90.0:
		if roll < 0.25:
			return orc_scout_scene
		elif roll < 0.4:
			return orc_brute_scene
		return orc_normal_scene
	else:
		if roll < 0.35:
			return orc_scout_scene
		elif roll < 0.6:
			return orc_brute_scene
		return orc_normal_scene

func get_spawn_position() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var spawn_radius: float = max(viewport_size.x, viewport_size.y) / 2.0 + spawn_distance_buffer
	
	var angle := randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * spawn_radius
	return player.global_position + offset

func get_orc_count() -> int:
	return get_tree().get_nodes_in_group("orcs").size()
