# scripts/orc.gd
extends CharacterBody2D

@export var move_speed: float = 202.8
@export var attack_range: float = 40.0
@export var telegraph_duration: float = 0.08
@export var score_value: int = 1
@export var enemy_class: StringName = &"grunt"
@export var visual_color: Color = Color.WHITE
@export var blood_color: Color = Color(0.08, 0.45, 0.12, 1.0)
@export var visual_scale: float = 1.0

@export var separation_strength: float = 80.0
@export var separation_radius: float = 30.0

@export var pickup_drop_chance: float = 0.05
@export var pickup_coin_scene: PackedScene

@export var blood_splat_scene: PackedScene
@export var corpse_scene: PackedScene

@export var death_lifetime: float = 90.0
@export var death_fade_duration: float = 5.0
@export var death_blood_delay: float = 0.5  # cuándo sale el charco final (segundos)
@export var dead_body_color: Color = Color(0.19, 0.2, 0.25, 1.0)  # gris oscuro y frío: el cadáver retrocede, el vivo resalta

# Nuevo flag para distinguir "muriendo" de "muerto"
var is_dead: bool = false

enum State { CHASING, TELEGRAPHING, RETURNING_TO_IDLE }

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
	
	# Si está muerto, no procesa nada más (la animación corre sola)
	if is_dead:
		return
	
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		return
	
	match state:
		State.CHASING:
			chase(delta)
		State.TELEGRAPHING:
			telegraph(delta)
		State.RETURNING_TO_IDLE:
			chase(delta)
	
	move_and_slide()
	
	# Rotación (solo si está vivo)
	if state != State.TELEGRAPHING and is_instance_valid(player):
		visual.rotation = (player.global_position - global_position).angle() - PI / 2

func chase(_delta: float) -> void:
	var distance := global_position.distance_to(player.global_position)
	
	if distance <= attack_range and state == State.CHASING:
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
		if neighbor.get("enemy_class") != enemy_class:
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
	state = State.TELEGRAPHING
	telegraph_timer = telegraph_duration
	velocity = Vector2.ZERO
	
	# Animación de ataque
	visual.play("attack")
	
	if is_instance_valid(player):
		var camera := player.get_node_or_null("Camera2D")
		if camera and camera.has_method("shake"):
			camera.shake(1.5)

func telegraph(delta: float) -> void:
	telegraph_timer -= delta
	velocity = Vector2.ZERO
	
	if telegraph_timer <= 0.0:
		if is_instance_valid(player):
			var distance := global_position.distance_to(player.global_position)
			if distance <= attack_range:
				if player.has_method("die"):
					player.die()
		state = State.RETURNING_TO_IDLE
		visual.modulate = visual_color
		visual.play("attack_to_idle")
		visual.animation_finished.connect(_on_attack_to_idle_finished, CONNECT_ONE_SHOT)

func _on_attack_to_idle_finished() -> void:
	if not is_instance_valid(self) or is_dying:
		return
	state = State.CHASING
	visual.play("idle")

func die() -> void:
	if is_dying:
		return
	is_dying = true
	is_dead = true
	z_index = -1
	
	visual.modulate = dead_body_color
	
	AudioManager.play_orc_death()
	try_drop_pickup()
	
	# Calcular dirección del empuje
	var push_dir := Vector2.RIGHT
	if is_instance_valid(player):
		push_dir = (global_position - player.global_position).normalized()
		if push_dir == Vector2.ZERO:
			push_dir = Vector2.RIGHT
	
	# Splash inicial de sangre direccional
	spawn_blood_splat_directional(push_dir)
	
	# Shake con combo
	if is_instance_valid(player):
		var camera := player.get_node_or_null("Camera2D")
		if camera and camera.has_method("shake"):
			camera.shake(_get_shake_for_combo())
	
	# Desactivar colisiones (el cuerpo es solo visual)
	$CollisionShape2D.set_deferred("disabled", true)
	if has_node("NeighborDetector"):
		$NeighborDetector.set_deferred("monitoring", false)
		$NeighborDetector.set_deferred("monitorable", false)
	
	# Sacar del grupo "orcs" para que no cuente como vivo
	remove_from_group("orcs")
	
	# Una muerte siempre suma una kill; score_value solo multiplica puntos.
	GameState.register_kill(score_value)
	
	# EMPUJE: el orco se desliza un toque en dirección opuesta al jugador
	var push_distance := 80.0
	var push_duration := 0.2
	var target_pos := global_position + push_dir * push_distance
	var push_tween := create_tween()
	push_tween.tween_property(self, "global_position", target_pos, push_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Reproducir animación de muerte
	visual.play("death")
	visual.animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)
	
	# Charco de sangre asentado (con delay)
	await get_tree().create_timer(death_blood_delay).timeout
	if is_instance_valid(self):
		spawn_resting_blood()
	
	# Lifetime: esperar y hacer fade
	await get_tree().create_timer(death_lifetime - death_blood_delay - death_fade_duration).timeout
	if not is_instance_valid(self):
		return
	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, death_fade_duration)
	fade_tween.tween_callback(queue_free)
	
func _on_death_animation_finished() -> void:
	# Cuando termina la animación, queda en el último frame
	if not visual:
		return
	visual.pause()
	
func _get_shake_for_combo() -> float:
	# Base de 4, escala con combo, capeado para que no sea brutal
	var base_shake := 4.0
	var combo_bonus := GameState.combo * 0.4
	var max_shake := 12.0
	return min(base_shake + combo_bonus, max_shake)

func spawn_blood_splat_directional(direction: Vector2) -> void:
	# Sangre que sale en la dirección del empuje (el primer "splash")
	if not blood_splat_scene:
		return
	var splat := blood_splat_scene.instantiate()
	splat.position = global_position
	splat.z_index = -2
	get_parent().add_child(splat)
	if splat.has_method("setup_directional"):
		splat.setup_directional(blood_color, direction)
	elif splat.has_method("setup"):
		splat.setup(blood_color)

func try_drop_pickup() -> void:
	if randf() > pickup_drop_chance:
		return
	if not pickup_coin_scene:
		return
	var pickup := pickup_coin_scene.instantiate()
	pickup.position = global_position
	get_parent().add_child(pickup)
	
func spawn_resting_blood() -> void:
	if not blood_splat_scene:
		return
	# Spawneamos 3 splats en posiciones ligeramente distintas para crear un charco más grande
	for i in range(3):
		var splat := blood_splat_scene.instantiate()
		var offset := Vector2(randf_range(-32, 32), randf_range(-32, 32))
		splat.position = global_position + offset
		splat.z_index = -2
		get_parent().add_child(splat)
		if splat.has_method("setup"):
			splat.setup(blood_color)
