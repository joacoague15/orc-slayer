# scripts/mage.gd
extends "res://scripts/orc.gd"

signal bolt_cast(bolt: Area2D)

const TELEGRAPH_DURATION: float = 0.8
const PROJECTILE_INTERVAL: float = 0.3
const BURST_PROJECTILE_COUNT: int = 3
const BURST_ANGLES_DEGREES: Array[float] = [0.0, -15.0, 15.0]
const NO_SPLIT_DISTANCE: float = 50.0

@export var arcane_bolt_scene: PackedScene
@export var mage_move_speed: float = 97.5
@export var mage_attack_range: float = 360.0
@export var mage_min_range: float = 120.0
@export var arcane_bolt_speed: float = 360.0
@export var bolt_split_distance: float = 200.0
@export var split_bolt_travel_distance: float = 360.0
@export var attack_cooldown: float = 3.0

enum MageState {
	POSITIONING,
	TELEGRAPHING,
	BURSTING,
	COOLDOWN,
}

var mage_state: MageState = MageState.POSITIONING
var mage_telegraph_timer: float = 0.0
var cooldown_timer: float = 0.0
var burst_interval_timer: float = 0.0
var burst_index: int = 0
var burst_base_direction: Vector2 = Vector2.RIGHT
var burst_should_split: bool = true

@onready var telegraph_glow: Polygon2D = $TelegraphGlow

func _ready() -> void:
	super()
	move_speed = mage_move_speed
	_hide_telegraph()

func _physics_process(delta: float) -> void:
	if GameState.game_over:
		velocity = Vector2.ZERO
		return
	if is_dead:
		return
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		return
	
	match mage_state:
		MageState.POSITIONING:
			_process_positioning()
		MageState.TELEGRAPHING:
			_process_telegraphing(delta)
		MageState.BURSTING:
			_process_bursting(delta)
		MageState.COOLDOWN:
			_process_cooldown(delta)
	
	move_and_slide()
	_face_player()

func _process_positioning() -> void:
	_maintain_range()
	if _is_in_optimal_range():
		_start_telegraph()

func _process_telegraphing(delta: float) -> void:
	velocity = Vector2.ZERO
	mage_telegraph_timer -= delta
	_update_telegraph()
	
	if mage_telegraph_timer <= 0.0:
		_start_burst()

func _process_bursting(delta: float) -> void:
	velocity = Vector2.ZERO
	burst_interval_timer -= delta
	
	if burst_interval_timer > 0.0:
		return
	
	_cast_bolt(BURST_ANGLES_DEGREES[burst_index])
	burst_index += 1
	
	if burst_index >= BURST_PROJECTILE_COUNT:
		_start_cooldown()
		return
	
	burst_interval_timer = PROJECTILE_INTERVAL

func _process_cooldown(delta: float) -> void:
	_maintain_range()
	cooldown_timer -= delta
	if cooldown_timer <= 0.0:
		mage_state = MageState.POSITIONING

func _maintain_range() -> void:
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	
	if distance > mage_attack_range:
		velocity = to_player.normalized() * mage_move_speed
	elif distance < mage_min_range:
		velocity = -to_player.normalized() * mage_move_speed
	else:
		velocity = Vector2.ZERO

func _is_in_optimal_range() -> bool:
	var distance := global_position.distance_to(player.global_position)
	return distance >= mage_min_range and distance <= mage_attack_range

func _start_telegraph() -> void:
	mage_state = MageState.TELEGRAPHING
	mage_telegraph_timer = TELEGRAPH_DURATION
	velocity = Vector2.ZERO
	_show_telegraph()

func _start_burst() -> void:
	_hide_telegraph()
	mage_state = MageState.BURSTING
	burst_index = 0
	burst_interval_timer = 0.0
	burst_base_direction = (player.global_position - global_position).normalized()
	if burst_base_direction == Vector2.ZERO:
		burst_base_direction = Vector2.RIGHT
	burst_should_split = global_position.distance_to(player.global_position) >= NO_SPLIT_DISTANCE

func _start_cooldown() -> void:
	mage_state = MageState.COOLDOWN
	cooldown_timer = attack_cooldown
	burst_interval_timer = 0.0

func _cast_bolt(angle_degrees: float) -> void:
	if not arcane_bolt_scene:
		return
	
	var bolt_direction := burst_base_direction.rotated(deg_to_rad(angle_degrees))
	var bolt := arcane_bolt_scene.instantiate()
	bolt.global_position = global_position
	if bolt.has_method("setup"):
		bolt.setup(
			bolt_direction,
			arcane_bolt_speed,
			burst_should_split,
			bolt_split_distance,
			split_bolt_travel_distance
		)
	get_tree().current_scene.add_child(bolt)
	bolt_cast.emit(bolt)

func _show_telegraph() -> void:
	telegraph_glow.visible = true
	_update_telegraph()

func _hide_telegraph() -> void:
	telegraph_glow.visible = false

func _update_telegraph() -> void:
	var pulse := 0.55 + sin(Time.get_ticks_msec() / 80.0) * 0.2
	telegraph_glow.modulate = Color(0.85, 0.25, 1.0, pulse)

func _face_player() -> void:
	if is_instance_valid(player):
		visual.rotation = (player.global_position - global_position).angle() - PI / 2

func die() -> void:
	_hide_telegraph()
	super()
