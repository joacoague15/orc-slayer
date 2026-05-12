# scripts/orc.gd
extends CharacterBody2D

@export var move_speed: float = 120.0
@export var attack_range: float = 40.0
@export var telegraph_duration: float = 0.5
@export var score_value: int = 1
@export var visual_color: Color = Color.WHITE
@export var visual_scale: float = 1.0

@export var separation_strength: float = 80.0
@export var separation_radius: float = 30.0

@export var pickup_drop_chance: float = 0.05
@export var pickup_coin_scene: PackedScene

@export var blood_splat_scene: PackedScene
@export var corpse_scene: PackedScene

enum State { CHASING, TELEGRAPHING }

var state: State = State.CHASING
var player: Node2D
var telegraph_timer: float = 0.0
var is_dying: bool = false

@onready var visual: AnimatedSprite2D = $OrcSpriteAnimator2D
@onready var neighbor_detector: Area2D = $NeighborDetector

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	visual.modulate = visual_color
	scale = Vector2(visual_scale, visual_scale)

func _physics_process(delta: float) -> void:
	if GameState.game_over:
		velocity = Vector2.ZERO
		return
	
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		return
	
	match state:
		State.CHASING:
			chase(delta)
		State.TELEGRAPHING:
			telegraph(delta)
	
	move_and_slide()
	
	# Rotación del sprite hacia el jugador
	if is_instance_valid(player):
		visual.rotation = (player.global_position - global_position).angle() - PI / 2

func chase(_delta: float) -> void:
	var distance := global_position.distance_to(player.global_position)
	
	if distance <= attack_range:
		start_telegraph()
		return
	
	var chase_dir := (player.global_position - global_position).normalized()
	var separation := get_separation_vector()
	
	velocity = chase_dir * move_speed + separation * separation_strength

func get_separation_vector() -> Vector2:
	var push := Vector2.ZERO
	var neighbors := neighbor_detector.get_overlapping_bodies()
	
	for neighbor in neighbors:
		if neighbor == self:
			continue
		if not neighbor.is_in_group("orcs"):
			continue
		
		var diff := global_position - neighbor.global_position
		var dist := diff.length()
		if dist == 0:
			push += Vector2(randf() - 0.5, randf() - 0.5).normalized()
		else:
			push += diff.normalized() * (1.0 - dist / separation_radius)
	
	if push.length() > 1.5:
		push = push.normalized() * 1.5
	return push

func start_telegraph() -> void:
	AudioManager.play_telegraph()
	state = State.TELEGRAPHING
	telegraph_timer = telegraph_duration
	velocity = Vector2.ZERO
	visual.modulate = Color.RED
	
	if is_instance_valid(player):
		var camera := player.get_node_or_null("Camera2D")
		if camera and camera.has_method("shake"):
			var telegraph_shake = 1.5 + min(GameState.combo * 0.15, 3.0)
			camera.shake(telegraph_shake)

func telegraph(delta: float) -> void:
	telegraph_timer -= delta
	velocity = Vector2.ZERO
	
	if telegraph_timer <= 0.0:
		if is_instance_valid(player):
			var distance := global_position.distance_to(player.global_position)
			if distance <= attack_range:
				if player.has_method("die"):
					player.die()
		state = State.CHASING
		visual.modulate = visual_color

func die() -> void:
	if is_dying:
		return
	is_dying = true
	
	AudioManager.play_orc_death()
	try_drop_pickup()
	
	var push_dir := Vector2.RIGHT
	if is_instance_valid(player):
		push_dir = (global_position - player.global_position).normalized()
		if push_dir == Vector2.ZERO:
			push_dir = Vector2.RIGHT
	
	spawn_corpse(push_dir)
	spawn_blood_splat_directional(push_dir)
	
	if is_instance_valid(player):
		var camera := player.get_node_or_null("Camera2D")
		if camera and camera.has_method("shake"):
			camera.shake(_get_shake_for_combo())
	
	for i in range(score_value):
		GameState.register_kill()
	queue_free()
	
func _get_shake_for_combo() -> float:
	# Base de 4, escala con combo, capeado para que no sea brutal
	var base_shake := 4.0
	var combo_bonus := GameState.combo * 0.4
	var max_shake := 12.0
	return min(base_shake + combo_bonus, max_shake)

func spawn_corpse(push_direction: Vector2) -> void:
	if not corpse_scene:
		return
	var corpse := corpse_scene.instantiate()
	corpse.position = global_position
	get_parent().add_child(corpse)
	if corpse.has_method("setup"):
		corpse.setup(visual_color, scale, push_direction, blood_splat_scene)

func spawn_blood_splat_directional(direction: Vector2) -> void:
	# Sangre que sale en la dirección del empuje (el primer "splash")
	if not blood_splat_scene:
		return
	var splat := blood_splat_scene.instantiate()
	splat.position = global_position
	splat.z_index = -2
	get_parent().add_child(splat)
	if splat.has_method("setup_directional"):
		splat.setup_directional(visual_color, direction)
	elif splat.has_method("setup"):
		splat.setup(visual_color)

func try_drop_pickup() -> void:
	if randf() > pickup_drop_chance:
		return
	if not pickup_coin_scene:
		return
	var pickup := pickup_coin_scene.instantiate()
	pickup.position = global_position
	get_parent().add_child(pickup)
