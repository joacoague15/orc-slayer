# scripts/arcane_bolt.gd
extends Area2D

signal player_hit(player: Node2D)
signal split_spawned(split_bolt: Area2D)

@export var speed: float = 360.0
@export var split_distance: float = 200.0
@export var split_travel_distance: float = 360.0
@export var split_angle_degrees: float = 45.0
@export var can_split: bool = true
@export var residue_scene: PackedScene
@export var split_bolt_scene: PackedScene

var direction: Vector2 = Vector2.RIGHT
var traveled_distance: float = 0.0
var max_travel_distance: float = 200.0

func setup(
	shoot_direction: Vector2,
	bolt_speed: float,
	should_split: bool,
	initial_split_distance: float,
	split_distance_after_split: float
) -> void:
	direction = shoot_direction.normalized()
	speed = bolt_speed
	can_split = should_split
	split_distance = initial_split_distance
	split_travel_distance = split_distance_after_split
	max_travel_distance = split_distance if can_split else split_travel_distance
	rotation = direction.angle()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	player_hit.connect(_on_player_hit)

func _physics_process(delta: float) -> void:
	var movement := direction * speed * delta
	position += movement
	traveled_distance += movement.length()
	
	if can_split and traveled_distance >= split_distance:
		_split()
		return
	
	if traveled_distance >= max_travel_distance:
		queue_free()

func _split() -> void:
	_spawn_residue()
	_spawn_split_bolt(direction.rotated(deg_to_rad(-split_angle_degrees)))
	_spawn_split_bolt(direction.rotated(deg_to_rad(split_angle_degrees)))
	queue_free()

func _spawn_split_bolt(split_direction: Vector2) -> void:
	var scene: PackedScene = split_bolt_scene
	if not scene:
		scene = load("res://scenes/arcane_bolt.tscn")
	if not scene:
		return
	
	var split_bolt := scene.instantiate()
	split_bolt.global_position = global_position
	if split_bolt.has_method("setup"):
		split_bolt.setup(split_direction, speed, false, split_distance, split_travel_distance)
	get_tree().current_scene.add_child(split_bolt)
	split_spawned.emit(split_bolt)

func _spawn_residue() -> void:
	if not residue_scene:
		return
	var residue := residue_scene.instantiate()
	residue.global_position = global_position
	get_tree().current_scene.add_child(residue)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	player_hit.emit(body)

func _on_player_hit(player: Node2D) -> void:
	if player.has_method("is_damage_invulnerable") and player.is_damage_invulnerable():
		return
	if player.has_method("die"):
		player.die()
	queue_free()
