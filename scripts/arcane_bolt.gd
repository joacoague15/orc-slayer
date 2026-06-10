# scripts/arcane_bolt.gd
# Orbe arcano del Mago. NO se fragmenta.
# Comportamiento: nace persiguiendo lento al jugador (telegrafiado, azul) durante
# `homing_duration` segundos; al terminar, fija la dirección hacia donde esté el
# jugador en ese instante y continúa en línea recta a velocidad normal.
# Si el mago que lo lanzó muere, el orbe desaparece.
extends Area2D

signal player_hit(player: Node2D)

@export var speed: float = 360.0
@export var homing_duration: float = 2.0
@export var homing_speed_factor: float = 0.35     # qué tan lento persigue durante el telegraph
@export var max_straight_distance: float = 1000.0 # alcance recto antes de desaparecer
@export var size_scale: float = 0.6               # 40% más chico que el tamaño base
@export var residue_scene: PackedScene
@export var trail_spawn_interval: float = 0.045

enum Phase { HOMING, STRAIGHT }

var phase: int = Phase.HOMING
var direction: Vector2 = Vector2.RIGHT
var homing_timer: float = 2.0
var straight_traveled: float = 0.0
var trail_timer: float = 0.0
var player_ref: Node2D = null
var owner_mage: Node = null

var _telegraph_pulse: float = 0.0
var _outer_aura: Polygon2D = null

func setup(shoot_direction: Vector2, bolt_speed: float, homing_time: float, player_node: Node2D, mage_node: Node) -> void:
	direction = shoot_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	speed = bolt_speed
	homing_duration = homing_time
	homing_timer = homing_time
	player_ref = player_node
	owner_mage = mage_node
	rotation = direction.angle()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	player_hit.connect(_on_player_hit)

	scale = Vector2.ONE * size_scale
	_outer_aura = get_node_or_null("OuterAura")

	# Mejora del efecto: estela un poco más densa y viva (compensa el tamaño menor).
	var trail := get_node_or_null("SparkTrail")
	if trail and trail is CPUParticles2D:
		trail.amount = 22
		trail.lifetime = 0.5
		trail.scale_amount_max = 3.4
		trail.initial_velocity_max = 150.0

func _physics_process(delta: float) -> void:
	# Si el mago que lo lanzó murió, el orbe se apaga.
	if owner_mage != null:
		if not is_instance_valid(owner_mage) or owner_mage.is_dead:
			_vanish()
			return

	match phase:
		Phase.HOMING:
			_process_homing(delta)
		Phase.STRAIGHT:
			_process_straight(delta)

	_update_trail(delta)
	_update_telegraph(delta)

func _process_homing(delta: float) -> void:
	# Persigue lento al jugador, reapuntando cada frame (telegraph claro).
	if is_instance_valid(player_ref):
		var to_player := player_ref.global_position - global_position
		if to_player != Vector2.ZERO:
			direction = to_player.normalized()
			rotation = direction.angle()

	position += direction * speed * homing_speed_factor * delta

	homing_timer -= delta
	if homing_timer <= 0.0:
		# La dirección queda fijada hacia la última posición del jugador.
		phase = Phase.STRAIGHT
		straight_traveled = 0.0
		scale = Vector2.ONE * size_scale
		if _outer_aura:
			_outer_aura.modulate.a = 0.26  # vuelve al brillo normal

func _process_straight(delta: float) -> void:
	var movement := direction * speed * delta
	position += movement
	straight_traveled += movement.length()
	if straight_traveled >= max_straight_distance:
		queue_free()

func _update_telegraph(delta: float) -> void:
	if phase != Phase.HOMING:
		return
	# Pulso de escala + brillo del aura: comunica que está cargando/persiguiendo.
	_telegraph_pulse += delta * 9.0
	var pulse := sin(_telegraph_pulse) * 0.5 + 0.5  # 0..1
	scale = Vector2.ONE * size_scale * (1.0 + pulse * 0.22)
	if _outer_aura:
		_outer_aura.modulate.a = lerp(0.18, 0.55, pulse)

func _update_trail(delta: float) -> void:
	trail_timer -= delta
	if trail_timer > 0.0:
		return
	trail_timer = trail_spawn_interval
	_spawn_residue()

func _spawn_residue() -> void:
	if not residue_scene:
		return
	var residue := residue_scene.instantiate()
	residue.global_position = global_position
	residue.rotation = direction.angle()
	get_parent().add_child(residue)

func _vanish() -> void:
	# El mago murió: deja un último residuo y desaparece.
	_spawn_residue()
	queue_free()

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
