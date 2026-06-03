# scripts/boss.gd
extends "res://scripts/orc.gd"

signal phase_changed(phase_name: String)
signal boss_killed
signal shockwave_released(position: Vector2)
signal grunts_summoned(grunts: Array[Node2D])

const APPROACH_DURATION: float = 2.0
const SPIN_DURATION: float = 1.5
const RECOVER_DURATION: float = 1.0
const LEAP_DURATION: float = 1.5
const LEAP_SHADOW_LEAD_TIME: float = 0.5
const TAUNT_DURATION: float = 2.0
const SPIN_RADIUS: float = 150.0
const SHOCKWAVE_RADIUS: float = 100.0
const TAUNT_GRUNT_COUNT: int = 2

@export var boss_move_speed: float = 312.65
@export var boss_recover_speed: float = 0.0
@export var grunt_scene: PackedScene
@export var summon_spawn_buffer: float = 50.0

enum BossPhase {
	APPROACH,
	SPIN,
	RECOVER,
	LEAP,
	TAUNT,
}

var boss_phase: BossPhase = BossPhase.APPROACH
var phase_timer: float = 0.0
var leap_target: Vector2 = Vector2.ZERO
var leap_shadow_shown: bool = false
var taunt_spawned: bool = false

@onready var phase_aura: Polygon2D = $PhaseAura
@onready var spin_radius_visual: Polygon2D = $SpinRadius
@onready var leap_shadow: Polygon2D = $LeapShadow
@onready var shockwave_visual: Polygon2D = $ShockwaveVisual

func _ready() -> void:
	super()
	_start_approach()

func _physics_process(delta: float) -> void:
	if GameState.game_over:
		velocity = Vector2.ZERO
		return
	if is_dead:
		return
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		return
	
	phase_timer -= delta
	
	match boss_phase:
		BossPhase.APPROACH:
			_process_approach()
		BossPhase.SPIN:
			_process_spin()
		BossPhase.RECOVER:
			_process_recover()
		BossPhase.LEAP:
			_process_leap()
		BossPhase.TAUNT:
			_process_taunt()
	
	move_and_slide()
	_face_player()

func _process_approach() -> void:
	var direction := (player.global_position - global_position).normalized()
	velocity = direction * boss_move_speed
	if phase_timer <= 0.0:
		_start_spin()

func _process_spin() -> void:
	velocity = Vector2.ZERO
	_try_hit_player_in_radius(SPIN_RADIUS)
	if phase_timer <= 0.0:
		_start_recover()

func _process_recover() -> void:
	var direction := (player.global_position - global_position).normalized()
	velocity = direction * boss_recover_speed
	if phase_timer <= 0.0:
		_start_leap()

func _process_leap() -> void:
	velocity = Vector2.ZERO
	
	if not leap_shadow_shown and phase_timer <= LEAP_SHADOW_LEAD_TIME:
		_show_leap_shadow()
	
	if phase_timer <= 0.0:
		_land_leap()
		_start_taunt()

func _process_taunt() -> void:
	velocity = Vector2.ZERO
	if not taunt_spawned:
		_summon_grunts()
		taunt_spawned = true
	if phase_timer <= 0.0:
		_start_approach()

func _start_approach() -> void:
	boss_phase = BossPhase.APPROACH
	phase_timer = APPROACH_DURATION
	_set_phase_visuals(Color(1.0, 0.45, 0.05, 1.0), false, false, false)
	phase_changed.emit("APPROACH")

func _start_spin() -> void:
	boss_phase = BossPhase.SPIN
	phase_timer = SPIN_DURATION
	_set_phase_visuals(Color.RED, true, false, false)
	phase_changed.emit("SPIN")

func _start_recover() -> void:
	boss_phase = BossPhase.RECOVER
	phase_timer = RECOVER_DURATION
	_set_phase_visuals(Color(0.15, 1.0, 0.2, 1.0), false, false, false)
	phase_changed.emit("RECOVER")

func _start_leap() -> void:
	boss_phase = BossPhase.LEAP
	phase_timer = LEAP_DURATION
	leap_shadow_shown = false
	leap_target = global_position
	_set_phase_visuals(Color.RED, false, false, false)
	phase_changed.emit("LEAP")

func _start_taunt() -> void:
	boss_phase = BossPhase.TAUNT
	phase_timer = TAUNT_DURATION
	taunt_spawned = false
	_set_phase_visuals(Color(0.75, 0.15, 1.0, 1.0), false, false, shockwave_visual.visible)
	phase_changed.emit("TAUNT")

func _show_leap_shadow() -> void:
	leap_shadow_shown = true
	leap_target = player.global_position
	leap_shadow.global_position = leap_target
	leap_shadow.visible = true

func _land_leap() -> void:
	global_position = leap_target
	leap_shadow.visible = false
	_show_shockwave()
	_try_hit_player_in_radius(SHOCKWAVE_RADIUS)
	shockwave_released.emit(global_position)

func _show_shockwave() -> void:
	shockwave_visual.visible = true
	shockwave_visual.modulate = Color(1.0, 0.1, 0.05, 0.75)
	var tween := create_tween()
	tween.tween_property(shockwave_visual, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void:
		shockwave_visual.visible = false
	)

func _summon_grunts() -> void:
	if not grunt_scene:
		return
	
	var summoned: Array[Node2D] = []
	for i in range(TAUNT_GRUNT_COUNT):
		var grunt := grunt_scene.instantiate()
		grunt.global_position = _get_edge_spawn_position(float(i) / float(TAUNT_GRUNT_COUNT))
		get_parent().add_child(grunt)
		summoned.append(grunt)
	grunts_summoned.emit(summoned)

func _get_edge_spawn_position(seed_offset: float) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var spawn_radius: float = max(viewport_size.x, viewport_size.y) / 2.0 + summon_spawn_buffer
	var center := player.global_position
	var camera := get_viewport().get_camera_2d()
	if camera:
		center = camera.global_position
	
	var angle := seed_offset * TAU + randf_range(-0.35, 0.35)
	return center + Vector2(cos(angle), sin(angle)) * spawn_radius

func _try_hit_player_in_radius(radius: float) -> void:
	if global_position.distance_to(player.global_position) > radius:
		return
	if player.has_method("die"):
		player.die()

func _set_phase_visuals(color: Color, show_spin: bool, show_shadow: bool, show_shockwave: bool) -> void:
	visual.modulate = color
	phase_aura.modulate = Color(color.r, color.g, color.b, 0.28)
	spin_radius_visual.visible = show_spin
	leap_shadow.visible = show_shadow
	shockwave_visual.visible = show_shockwave

func _face_player() -> void:
	visual.rotation = (player.global_position - global_position).angle() - PI / 2

func _is_vulnerable() -> bool:
	return boss_phase == BossPhase.APPROACH \
		or boss_phase == BossPhase.RECOVER \
		or boss_phase == BossPhase.TAUNT

func die() -> void:
	if not _is_vulnerable():
		return
	boss_killed.emit()
	super()
