extends Area2D

signal enemy_hit(enemy: Node2D)

@export var speed: float = 720.0
@export var travel_distance: float = 340.0
@export var fade_duration: float = 0.12
@export var ignore_boss: bool = true

var direction: Vector2 = Vector2.RIGHT
var traveled_distance: float = 0.0
var hit_enemies: Array[Node2D] = []

@onready var wave_visual: Polygon2D = $WaveVisual
@onready var inner_glow: Polygon2D = $InnerGlow

func setup(cast_direction: Vector2) -> void:
	direction = cast_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	rotation = direction.angle()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	var movement := direction * speed * delta
	global_position += movement
	traveled_distance += movement.length()
	_try_hit_overlapping_bodies()
	
	if traveled_distance >= travel_distance:
		_finish()

func _try_hit_overlapping_bodies() -> void:
	for body in get_overlapping_bodies():
		_try_hit_enemy(body)
	for area in get_overlapping_areas():
		_try_hit_enemy(area)

func _try_hit_enemy(enemy: Node) -> void:
	if not enemy is Node2D:
		return
	if hit_enemies.has(enemy):
		return
	if ignore_boss and enemy.has_signal("boss_killed"):
		return
	if not enemy.is_in_group("orcs"):
		return
	if not enemy.has_method("die"):
		return
	
	hit_enemies.append(enemy)
	enemy.die()
	enemy_hit.emit(enemy)

func _on_body_entered(body: Node2D) -> void:
	_try_hit_enemy(body)

func _on_area_entered(area: Area2D) -> void:
	_try_hit_enemy(area)

func _finish() -> void:
	set_physics_process(false)
	monitoring = false
	monitorable = false
	var tween := create_tween()
	tween.parallel().tween_property(wave_visual, "modulate:a", 0.0, fade_duration)
	tween.parallel().tween_property(inner_glow, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(queue_free)
