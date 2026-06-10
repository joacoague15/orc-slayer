# scripts/boss_warlord.gd
# Boss Warlord (prototipo).
#
# - PUNTERÍA EN DOS CAPAS: la cabeza gira rápido hacia el jugador hasta un límite;
#   si el jugador se sale de ese cono, el CUERPO rota (lento) para reencararlo.
#   El cuerpo lento crea un PUNTO CIEGO a la espalda que el jugador puede explotar.
# - ATAQUE: cleave frontal telegrafiado hacia donde apunta. Un golpe = muerte.
# - SIEMPRE INVULNERABLE: se escuda con el escudo. El jugador NO puede matarlo
#   todavía; cualquier golpe se bloquea con feedback de chispas en el escudo.
#
# Forward del boss = su eje local +Y (mira "hacia abajo"/cámara con rotación 0).
extends CharacterBody2D

@export var move_speed: float = 192.0
@export var contact_kill_range: float = 110.0       # tocar el cuerpo = muerte del jugador
@export var score_value: int = 10
@export var enemy_class: StringName = &"boss"
@export var invulnerable: bool = true               # por ahora SIEMPRE true

@export_group("Punteria")
@export var head_turn_limit: float = 0.95           # rad (~54°) que la cabeza puede girar sola
@export var head_turn_speed: float = 11.0           # rad/s (cabeza rápida: lidera la mirada)
@export var body_turn_speed: float = 1.0            # rad/s (cuerpo lento → la cabeza lidera + punto ciego)

@export_group("Cleave")
@export var cleave_trigger_range: float = 280.0     # distancia a la que decide atacar
@export var cleave_reach: float = 320.0             # alcance del golpe
@export var cleave_half_arc: float = 1.2            # rad (~69°) de medio cono
@export var windup_time: float = 0.6
@export var cleave_time: float = 0.28
@export var recover_time: float = 0.55
@export var windup_body_turn_speed: float = 6.0     # al telegrafiar encara rápido y fija la dirección
@export var club_rest_angle: float = 0.0
@export var club_windup_angle: float = -1.3         # brazo afuera/arriba (wind-up)
@export var club_swing_angle: float = 0.45          # termina adentro/centro (swing de afuera hacia adentro)

enum State { CHASE, WINDUP, CLEAVE, RECOVER }

var state: int = State.CHASE
var phase_timer: float = 0.0
var committed_rot: float = 0.0          # rotación de cuerpo comprometida para el cleave
var player: Node2D = null
var time_accum: float = 0.0
var block_cd: float = 0.0
var shield_recoil: float = 0.0
var head_rot: float = 0.0               # rotación local actual de la cabeza
var club_target: float = 0.0           # rotación objetivo del brazo de la maza
var telegraph_node: Polygon2D = null

@onready var parts: Node2D = $Parts
@onready var head: Sprite2D = $Parts/Head
@onready var club: Sprite2D = $Parts/RightArm   # brazo con maza
@onready var shield: Sprite2D = $Parts/LeftArm  # brazo con escudo

func _ready() -> void:
	if not is_in_group("orcs"):
		add_to_group("orcs")
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	time_accum += delta
	block_cd = maxf(block_cd - delta, 0.0)
	shield_recoil = move_toward(shield_recoil, 0.0, delta * 4.0)

	if GameState.game_over:
		velocity = Vector2.ZERO
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		velocity = Vector2.ZERO
		return

	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var target_body_rot := to_player.angle() - PI / 2.0

	# Contacto con el cuerpo = muerte del jugador (die() respeta i-frames/dash).
	if dist <= contact_kill_range and player.has_method("die"):
		player.die()

	match state:
		State.CHASE:
			_process_chase(to_player, dist)
		State.WINDUP:
			_process_windup(delta)
		State.CLEAVE:
			_process_cleave(delta)
		State.RECOVER:
			_process_recover(delta)

	# --- Aim en dos capas ---
	# La cabeza sigue al jugador girando sobre su propio centro hasta head_turn_limit.
	# Solo cuando se pasa de ese máximo, el CUERPO rota (lento) para reencararlo,
	# y la cabeza queda fija en el tope mientras el cuerpo alcanza. Natural y fluido.
	# (No aplica durante el ataque: ese usa su dirección comprometida.)
	var residual := angle_difference(parts.rotation, target_body_rot)
	if state == State.CHASE or state == State.RECOVER:
		if absf(residual) > head_turn_limit:
			parts.rotation = rotate_toward(parts.rotation, target_body_rot, body_turn_speed * delta)
			residual = angle_difference(parts.rotation, target_body_rot)
	var head_t := clampf(residual, -head_turn_limit, head_turn_limit)
	head_rot = rotate_toward(head_rot, head_t, head_turn_speed * delta)
	head.rotation = head_rot + sin(time_accum * 2.0) * 0.03

	# --- Brazos ---
	club.rotation = club_target
	shield.rotation = sin(time_accum * 1.3) * 0.04 + shield_recoil

	move_and_slide()

# === Estados ===

func _process_chase(to_player: Vector2, dist: float) -> void:
	velocity = to_player.normalized() * move_speed if dist > 1.0 else Vector2.ZERO
	club_target = sin(time_accum * 1.5) * 0.06   # leve sway de la maza

	if dist <= cleave_trigger_range:
		_enter_windup(to_player)

func _enter_windup(to_player: Vector2) -> void:
	state = State.WINDUP
	phase_timer = windup_time
	velocity = Vector2.ZERO
	committed_rot = to_player.angle() - PI / 2.0   # fija la dirección del cleave
	_spawn_telegraph()

func _process_windup(delta: float) -> void:
	velocity = Vector2.ZERO
	# Encara rápido la dirección comprometida (ya no la cambia: el jugador puede esquivar).
	parts.rotation = rotate_toward(parts.rotation, committed_rot, windup_body_turn_speed * delta)
	var t := 1.0 - phase_timer / windup_time
	# Ease-out: lleva el brazo atrás rápido y lo AGUANTA cargado (telegraph claro).
	var e := 1.0 - pow(1.0 - t, 2.0)
	club_target = lerpf(club_rest_angle, club_windup_angle, e)
	modulate = Color.WHITE.lerp(Color(1.4, 0.5, 0.42), t * 0.7)  # tinte rojo de carga

	phase_timer -= delta
	if phase_timer <= 0.0:
		_enter_cleave()

func _enter_cleave() -> void:
	state = State.CLEAVE
	phase_timer = cleave_time
	parts.rotation = committed_rot
	_clear_telegraph()
	_spawn_cleave_flash()
	_impact_punch()
	_hitstop(0.05)
	_shake(9.0)

func _process_cleave(delta: float) -> void:
	velocity = Vector2.ZERO
	var t := 1.0 - phase_timer / cleave_time
	# Back-ease-out: latigazo de afuera hacia adentro con leve overshoot (contundencia).
	club_target = lerpf(club_windup_angle, club_swing_angle, _back_ease_out(t))
	modulate = Color.WHITE.lerp(modulate, 0.5)     # apaga el tinte rápido

	# Golpe activo: mata al jugador si está dentro del cono frontal.
	if is_instance_valid(player):
		var fwd := Vector2.DOWN.rotated(committed_rot)
		var to_p := player.global_position - global_position
		if to_p.length() <= cleave_reach and absf(fwd.angle_to(to_p)) <= cleave_half_arc:
			if player.has_method("die"):
				player.die()

	phase_timer -= delta
	if phase_timer <= 0.0:
		state = State.RECOVER
		phase_timer = recover_time
		modulate = Color.WHITE

func _process_recover(delta: float) -> void:
	velocity = Vector2.ZERO
	var t := 1.0 - phase_timer / recover_time
	club_target = lerpf(club_swing_angle, club_rest_angle, t)  # la maza vuelve a reposo
	phase_timer -= delta
	if phase_timer <= 0.0:
		state = State.CHASE

# === Invulnerabilidad / bloqueo ===

func die() -> void:
	# Siempre invulnerable por ahora: el golpe se bloquea con el escudo.
	if invulnerable:
		_on_blocked()
		return
	# (Futuro) muerte real, cuando agreguemos ventanas vulnerables.
	remove_from_group("orcs")
	GameState.register_kill(score_value, true, enemy_class)
	AudioManager.play_orc_death()
	queue_free()

func _on_blocked() -> void:
	if block_cd > 0.0:
		return
	block_cd = 0.12

	var dir := Vector2.DOWN
	if is_instance_valid(player):
		dir = (player.global_position - global_position).normalized()

	_spawn_block_sparks(global_position + dir * 110.0, dir)
	shield_recoil = -0.3
	# Flash del escudo (self_modulate no pelea con la rotación por frame).
	shield.self_modulate = Color(2.2, 2.2, 2.4)
	var tw := shield.create_tween()
	tw.tween_property(shield, "self_modulate", Color.WHITE, 0.2)
	_shake(2.5)
	AudioManager.play_slice()  # provisional: falta un "clang" dedicado

# === FX por código ===

func _make_wedge(reach: float, half_arc: float, color: Color) -> Polygon2D:
	# Abanico que apunta a +Y (forward local del boss); luego se rota a committed_rot.
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var segs := 16
	for i in range(segs + 1):
		var a: float = lerpf(PI / 2.0 - half_arc, PI / 2.0 + half_arc, float(i) / float(segs))
		pts.append(Vector2(cos(a), sin(a)) * reach)
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = color
	return poly

func _spawn_telegraph() -> void:
	_clear_telegraph()
	telegraph_node = _make_wedge(cleave_reach, cleave_half_arc, Color(1.0, 0.15, 0.1, 0.0))
	telegraph_node.z_index = 1   # en el piso, debajo de las unidades
	get_parent().add_child(telegraph_node)
	telegraph_node.global_position = global_position
	telegraph_node.rotation = committed_rot
	var tw := telegraph_node.create_tween()
	tw.tween_property(telegraph_node, "color:a", 0.32, windup_time)

func _clear_telegraph() -> void:
	if is_instance_valid(telegraph_node):
		telegraph_node.queue_free()
	telegraph_node = null

func _spawn_cleave_flash() -> void:
	var flash := _make_wedge(cleave_reach, cleave_half_arc, Color(1.6, 1.5, 1.2, 0.8))
	flash.z_index = 6
	get_parent().add_child(flash)
	flash.global_position = global_position
	flash.rotation = committed_rot
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.25)
	tw.tween_callback(flash.queue_free)

func _spawn_block_sparks(pos: Vector2, dir: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = 16
	p.lifetime = 0.35
	p.direction = dir
	p.spread = 55.0
	p.gravity = Vector2(0.0, 320.0)
	p.initial_velocity_min = 130.0
	p.initial_velocity_max = 320.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.6
	p.color = Color(1.8, 1.55, 0.7, 1.0)  # chispas amarillas
	p.z_index = 7
	get_parent().add_child(p)
	p.global_position = pos
	var t := p.create_tween()
	t.tween_interval(0.7)
	t.tween_callback(p.queue_free)

func _shake(amount: float) -> void:
	if not is_instance_valid(player):
		return
	var camera := player.get_node_or_null("Camera2D")
	if camera and camera.has_method("shake"):
		camera.shake(amount)

func _back_ease_out(t: float) -> float:
	# Ease-out con overshoot (whip): pasa un toque del objetivo y vuelve.
	var s := 1.70158
	var u := t - 1.0
	return 1.0 + (s + 1.0) * pow(u, 3.0) + s * pow(u, 2.0)

func _impact_punch() -> void:
	# Pop de escala del ensamblado en el impacto.
	parts.scale = Vector2.ONE * 1.08
	var tw := parts.create_tween()
	tw.tween_property(parts, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hitstop(duration: float) -> void:
	# Micro-congelamiento en tiempo real (ignore_time_scale) para darle peso al golpe.
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
