# scripts/berserker.gd
extends "res://scripts/orc.gd"

const WANDER_MIN_DURATION: float = 1.5
const WANDER_MAX_DURATION: float = 3.0
const WINDUP_DURATION: float = 0.3
const CHARGE_DURATION: float = 2.0
const RECOVERY_DURATION: float = 0.5

@export var wander_speed: float = 150.0
@export var charge_speed: float = 620.0
@export var charge_hit_radius: float = 34.0
@export var charge_max_distance: float = 900.0

enum BerserkerState {
	WANDER,
	WINDUP,
	CHARGE,
	RECOVERY,
}

var berserker_state: BerserkerState = BerserkerState.WANDER
var state_timer: float = 0.0
var wander_direction: Vector2 = Vector2.RIGHT
var charge_direction: Vector2 = Vector2.RIGHT
var charge_start_position: Vector2 = Vector2.ZERO

@onready var telegraph_flash: Polygon2D = $TelegraphFlash

func _ready() -> void:
	super()
	_start_wander()

func _physics_process(delta: float) -> void:
	if GameState.game_over:
		velocity = Vector2.ZERO
		return
	if is_dead:
		return
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		return
	
	match berserker_state:
		BerserkerState.WANDER:
			_process_wander(delta)
		BerserkerState.WINDUP:
			_process_windup(delta)
		BerserkerState.CHARGE:
			_process_charge(delta)
		BerserkerState.RECOVERY:
			_process_recovery(delta)
	
	move_and_slide()
	_update_visual_rotation()

func _process_wander(delta: float) -> void:
	state_timer -= delta
	velocity = wander_direction * wander_speed
	
	if state_timer <= 0.0:
		_start_windup()

func _process_windup(delta: float) -> void:
	state_timer -= delta
	velocity = Vector2.ZERO
	_update_telegraph_flash()
	
	if state_timer <= 0.0:
		_start_charge()

func _process_charge(delta: float) -> void:
	state_timer -= delta
	velocity = charge_direction * charge_speed
	_try_hit_player()
	
	var charged_distance := global_position.distance_to(charge_start_position)
	if state_timer <= 0.0 or charged_distance >= charge_max_distance:
		_start_recovery()

func _process_recovery(delta: float) -> void:
	state_timer -= delta
	velocity = Vector2.ZERO
	
	if state_timer <= 0.0:
		_start_wander()

func _start_wander() -> void:
	berserker_state = BerserkerState.WANDER
	state_timer = randf_range(WANDER_MIN_DURATION, WANDER_MAX_DURATION)
	wander_direction = Vector2.RIGHT.rotated(randf() * TAU)
	visual.modulate = visual_color
	telegraph_flash.visible = false

func _start_windup() -> void:
	berserker_state = BerserkerState.WINDUP
	state_timer = WINDUP_DURATION
	velocity = Vector2.ZERO
	charge_direction = (player.global_position - global_position).normalized()
	if charge_direction == Vector2.ZERO:
		charge_direction = Vector2.RIGHT
	telegraph_flash.visible = true
	visual.modulate = Color.RED
	
	var camera := player.get_node_or_null("Camera2D")
	if camera and camera.has_method("shake"):
		camera.shake(2.0)

func _start_charge() -> void:
	berserker_state = BerserkerState.CHARGE
	state_timer = CHARGE_DURATION
	charge_start_position = global_position
	telegraph_flash.visible = false
	visual.modulate = Color(1.0, 0.15, 0.1, 1.0)

func _start_recovery() -> void:
	berserker_state = BerserkerState.RECOVERY
	state_timer = RECOVERY_DURATION
	velocity = Vector2.ZERO
	visual.modulate = Color(0.25, 1.0, 0.35, 1.0)

func _try_hit_player() -> void:
	if global_position.distance_to(player.global_position) > charge_hit_radius:
		return
	if player.has_method("die"):
		player.die()

func _update_telegraph_flash() -> void:
	var pulse := 0.45 + sin(Time.get_ticks_msec() / 35.0) * 0.25
	telegraph_flash.modulate = Color(1.0, 0.0, 0.0, pulse)

func _update_visual_rotation() -> void:
	if berserker_state == BerserkerState.CHARGE:
		visual.rotation = charge_direction.angle() - PI / 2
	elif berserker_state == BerserkerState.WANDER:
		visual.rotation = wander_direction.angle() - PI / 2
	else:
		visual.rotation = (player.global_position - global_position).angle() - PI / 2

func die() -> void:
	if berserker_state == BerserkerState.CHARGE:
		return
	telegraph_flash.visible = false
	super()
