# scripts/spawner.gd
extends Node2D

@export var orc_normal_scene: PackedScene
@export var orc_scout_scene: PackedScene
@export var orc_brute_scene: PackedScene
@export var orc_archer_scene: PackedScene
@export var orc_mage_scene: PackedScene
@export var orc_berserker_scene: PackedScene

@export_group("Spawn Weights")
@export var mid_scout_weight: float = 0.25
@export var mid_archer_weight: float = 0.15
@export var mid_mage_weight: float = 0.10
@export var mid_berserker_weight: float = 0.08
@export var hard_scout_weight: float = 0.25
@export var hard_brute_weight: float = 0.15
@export var hard_archer_weight: float = 0.20
@export var hard_mage_weight: float = 0.15
@export var hard_berserker_weight: float = 0.12
@export var late_scout_weight: float = 0.25
@export var late_brute_weight: float = 0.15
@export var late_archer_weight: float = 0.20
@export var late_mage_weight: float = 0.15
@export var late_berserker_weight: float = 0.20

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
	elif elapsed_time < 20.0:
		if roll < mid_scout_weight:
			return orc_scout_scene
		if roll < mid_scout_weight + mid_archer_weight:
			return orc_archer_scene
		return orc_normal_scene
	elif elapsed_time < 45.0:
		if roll < mid_scout_weight:
			return orc_scout_scene
		if roll < mid_scout_weight + mid_archer_weight:
			return orc_archer_scene
		if roll < mid_scout_weight + mid_archer_weight + mid_mage_weight:
			return orc_mage_scene
		if roll < mid_scout_weight + mid_archer_weight + mid_mage_weight + mid_berserker_weight:
			return orc_berserker_scene
		return orc_normal_scene
	elif elapsed_time < 90.0:
		if roll < hard_scout_weight:
			return orc_scout_scene
		if roll < hard_scout_weight + hard_brute_weight:
			return orc_brute_scene
		if roll < hard_scout_weight + hard_brute_weight + hard_archer_weight:
			return orc_archer_scene
		if roll < hard_scout_weight + hard_brute_weight + hard_archer_weight + hard_mage_weight:
			return orc_mage_scene
		if roll < hard_scout_weight + hard_brute_weight + hard_archer_weight + hard_mage_weight + hard_berserker_weight:
			return orc_berserker_scene
		return orc_normal_scene
	else:
		if roll < late_scout_weight:
			return orc_scout_scene
		if roll < late_scout_weight + late_brute_weight:
			return orc_brute_scene
		if roll < late_scout_weight + late_brute_weight + late_archer_weight:
			return orc_archer_scene
		if roll < late_scout_weight + late_brute_weight + late_archer_weight + late_mage_weight:
			return orc_mage_scene
		if roll < late_scout_weight + late_brute_weight + late_archer_weight + late_mage_weight + late_berserker_weight:
			return orc_berserker_scene
		return orc_normal_scene

func get_spawn_position() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var spawn_radius: float = max(viewport_size.x, viewport_size.y) / 2.0 + spawn_distance_buffer
	
	var angle := randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * spawn_radius
	return player.global_position + offset

func get_orc_count() -> int:
	return get_tree().get_nodes_in_group("orcs").size()
