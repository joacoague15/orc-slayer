# scripts/boss_warlord.gd
# Boss Warlord.
#
# DOS ATAQUES y una sola apertura por AGOTAMIENTO:
# 1) CLEAVE  — arco frontal telegrafiado y RÁPIDO: leer el abanico y salir del
#              cono o atravesarlo con dash (i-frames).
# 2) PISOTÓN — frecuente. Telegrafía 0.5s (se alza + círculo de advertencia) y
#              libera UNA onda expansiva LETAL que cubre TODA la ronda, más
#              veloz que el jugador corriendo: hay que atravesarla con dash.
# AGOTAMIENTO — tras 5-10 ataques (aleatorio; cuentan cleaves y pisotones) queda
#              ESTUNEADO: la ÚNICA ventana en la que el jugador puede matarlo
#              (de un golpe, como todo en el juego). Si la ventana se cierra,
#              el contador arranca de nuevo.
#
# - PUNTERÍA EN DOS CAPAS: la cabeza gira rápido hacia el jugador hasta un límite;
#   si el jugador se sale de ese cono, el CUERPO rota (lento) para reencararlo.
#   El cuerpo lento crea un PUNTO CIEGO a la espalda que el jugador puede explotar.
# - Fuera del stun es INVULNERABLE: se escuda; cualquier golpe rebota con
#   chispas y knockback (ver die() / _on_attacked()).
#
# Forward del boss = su eje local +Y (mira "hacia abajo"/cámara con rotación 0).
extends CharacterBody2D

const ShockwaveRing := preload("res://scripts/shockwave_ring.gd")
const CleaveTelegraph := preload("res://scripts/cleave_telegraph.gd")
const StompTelegraph := preload("res://scripts/stomp_telegraph.gd")

@export var move_speed: float = 326.4               # +70% (prototipo: 192); más lento que el jugador (390)
@export var score_value: int = 10
@export var enemy_class: StringName = &"boss"

@export_group("Bloqueo con escudo")
@export var block_front_arc: float = 1.4            # rad (~80°): ataque considerado "de frente"
@export var block_knockback: float = 1200.0        # fuerza con que rebota al jugador
@export var shield_block_pose: float = 0.8          # cuánto se levanta el escudo al bloquear (rad)
@export var block_hold_time: float = 0.4            # cuánto se queda bloqueando tras el último golpe

@export_group("Punteria")
@export var head_turn_limit: float = 0.95           # rad (~54°) que la cabeza puede girar sola
@export var head_turn_speed: float = 11.0           # rad/s (cabeza rápida: lidera la mirada)
@export var body_turn_speed: float = 1.0            # rad/s (cuerpo lento → la cabeza lidera + punto ciego)

@export_group("Marcha")
@export var gait_stride: float = 165.0              # px recorridos por paso: la fase avanza por DISTANCIA real
@export var gait_bob: float = 7.0                   # alzada del cuerpo en cada paso
@export var gait_sway: float = 5.0                  # balanceo lateral alternado por paso

@export_group("Espectral")
@export var ghost_interval: float = 0.12            # cadencia de ecos espectrales al moverse

@export_group("Cleave")
@export var cleave_trigger_range: float = 202.0     # acompaña el alcance: justo por debajo del reach
@export var cleave_reach: float = 230.0             # -40% (antes 384)
@export var cleave_half_arc: float = 1.2            # rad (~69°) de medio cono
@export var windup_time: float = 0.38               # +30% más rápido (antes 0.49)
@export var cleave_time: float = 0.15               # (antes 0.2)
@export var recover_time: float = 0.35              # (antes 0.45)
@export var windup_body_turn_speed: float = 6.0     # al telegrafiar encara rápido y fija la dirección
@export var club_rest_angle: float = 0.0
@export var club_windup_angle: float = 1.1          # carga a la DERECHA (wind-up)
@export var club_swing_angle: float = -1.2          # barre hacia la IZQUIERDA (swing der→izq)

@export_group("Pisotón")
@export var stomp_interval_min: float = 3.0         # frecuente: presión constante
@export var stomp_interval_max: float = 5.5
@export var stomp_windup_time: float = 0.5          # telegraph: se alza + círculo de advertencia
@export var stomp_warning_radius: float = 300.0     # círculo del epicentro durante el telegraph
@export var stomp_wave_speed: float = 430.0         # px/s: más rápida que el jugador corriendo (390)
@export var stomp_wave_width: float = 16.0          # grosor del frente: tiene que leerse de lejos
@export var stomp_fallback_radius: float = 900.0    # alcance si no hay arena publicada (legacy)
@export var stomp_ring_color: Color = Color(2.0, 0.35, 0.12, 1.0)  # ROJO peligro: mismo lenguaje que los telegraphs

@export_group("Agotamiento (stun)")
@export var stun_attacks_min: int = 5               # ataques (cleave + pisotón) antes de agotarse
@export var stun_attacks_max: int = 10
@export var vulnerable_time: float = 1.5            # ventana de kill mientras está estuneado

enum State { CHASE, WINDUP, CLEAVE, RECOVER, BLOCK, STOMP, VULNERABLE }

var state: int = State.CHASE
var block_hold_timer: float = 0.0
var phase_timer: float = 0.0
var committed_rot: float = 0.0          # rotación de cuerpo comprometida para el cleave
var player: Node2D = null
var time_accum: float = 0.0
var block_cd: float = 0.0
var shield_recoil: float = 0.0
var shield_block: float = 0.0           # pose de "escudo al frente" (decae sola)
var head_rot: float = 0.0               # rotación local actual de la cabeza
var club_target: float = 0.0           # rotación objetivo del brazo de la maza
var telegraph_node: CleaveTelegraph = null

var gait_phase: float = 0.0             # avanza 1.0 por paso, en función de los px recorridos
var gait_was_moving: bool = false
var ghost_timer: float = 0.0
var spirit_wisps: CPUParticles2D = null # motas de alma flotando alrededor del espíritu

var stomp_timer: float = 6.0
var stomp_warning: StompTelegraph = null  # telegraph del pisotón (anillo contractor)

var attacks_done: int = 0               # cleaves + pisotones desde el último stun
var attacks_until_stun: int = 7

var vulnerable_disc: Polygon2D = null   # disco-timer dorado (se achica con la ventana)
var vulnerable_sparks: CPUParticles2D = null
var dying: bool = false                 # evita doble registro de kill en la ventana

@onready var parts: Node2D = $Parts
@onready var body: Sprite2D = $Parts/Body
@onready var head: Sprite2D = $Parts/Head
@onready var club: Sprite2D = $Parts/RightArm   # brazo con maza
@onready var shield: Sprite2D = $Parts/LeftArm  # brazo con escudo
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	if not is_in_group("orcs"):
		add_to_group("orcs")
	player = get_tree().get_first_node_in_group("player")
	stomp_timer = randf_range(stomp_interval_min, stomp_interval_max)
	attacks_until_stun = randi_range(stun_attacks_min, stun_attacks_max)
	_spawn_spirit_wisps()

func _physics_process(delta: float) -> void:
	time_accum += delta
	block_cd = maxf(block_cd - delta, 0.0)
	shield_recoil = move_toward(shield_recoil, 0.0, delta * 4.0)
	shield_block = move_toward(shield_block, 0.0, delta * 3.0)

	if GameState.game_over:
		velocity = Vector2.ZERO
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		velocity = Vector2.ZERO
		return

	# Bloqueo: el jugador lo está atacando → todo congelado, escudo arriba.
	if state == State.BLOCK:
		_process_block(delta)
		move_and_slide()
		return

	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var target_body_rot := to_player.angle() - PI / 2.0

	# Sin contacto-letal pasivo: las amenazas letales son los ataques telegrafiados.
	# El frente está escudado: atacarlo fuera del stun rebota al jugador (ver die()).

	match state:
		State.CHASE:
			_process_chase(to_player, dist)
		State.WINDUP:
			_process_windup(delta)
		State.CLEAVE:
			_process_cleave(delta)
		State.RECOVER:
			_process_recover(delta)
		State.STOMP:
			_process_stomp(delta)
		State.VULNERABLE:
			_process_vulnerable(delta)

	# --- Aim en dos capas ---
	# La cabeza sigue al jugador girando sobre su propio centro hasta head_turn_limit.
	# Solo cuando se pasa de ese máximo, el CUERPO rota (lento) para reencararlo,
	# y la cabeza queda fija en el tope mientras el cuerpo alcanza. Natural y fluido.
	# (No aplica durante ataques con dirección comprometida ni mientras está aturdido.)
	if state != State.VULNERABLE:
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
	shield.rotation = sin(time_accum * 1.3) * 0.04 + shield_recoil + shield_block

	_update_gait(delta)

	# Scheduler: el pisotón solo se decide mientras persigue.
	if state == State.CHASE:
		stomp_timer -= delta
		if stomp_timer <= 0.0:
			_enter_stomp()

	move_and_slide()

# === Marcha (anti-slide) y presencia espectral ===

func _update_gait(delta: float) -> void:
	# Marcha sincronizada con el desplazamiento REAL: la fase avanza por píxeles
	# recorridos (no por tiempo), así los pasos coinciden con el suelo y el boss
	# no "patina". Mientras camina, la respiración (idle) cede el control de Parts.
	var moving := state == State.CHASE and velocity.length() > 20.0
	if moving:
		if not gait_was_moving and anim_player:
			anim_player.pause()
		var prev := gait_phase
		gait_phase += velocity.length() * delta / gait_stride
		var dir := velocity.normalized()
		var side := Vector2(-dir.y, dir.x)
		var swing := sin(gait_phase * PI)   # alterna de signo en cada paso
		parts.position = side * swing * gait_sway + Vector2(0.0, -absf(swing) * gait_bob)
		body.rotation = swing * 0.05
		if floorf(prev) != floorf(gait_phase):
			# Pisada: bruma espectral a los pies + mini-shake (peso del Warlord).
			var foot := 1.0 if int(floorf(gait_phase)) % 2 == 0 else -1.0
			_spawn_step_mist(global_position + side * foot * 38.0)
			_shake(1.3)
		ghost_timer -= delta
		if ghost_timer <= 0.0:
			ghost_timer = ghost_interval
			_spawn_ghost()
	elif gait_was_moving:
		parts.position = Vector2.ZERO
		body.rotation = 0.0
		if anim_player and state != State.BLOCK:
			anim_player.play("idle")
	gait_was_moving = moving

func _spawn_ghost() -> void:
	# Eco espectral: copia de las partes que queda atrás y se desvanece.
	var ghost := parts.duplicate(0) as Node2D
	get_parent().add_child(ghost)
	ghost.global_transform = parts.global_transform
	ghost.z_index = 4   # justo debajo del boss (5)
	ghost.modulate = Color(0.5, 1.2, 1.0, 0.35)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(ghost.queue_free)

func _spawn_spirit_wisps() -> void:
	# Motas de alma: ascienden lento alrededor del cuerpo, permanentes.
	spirit_wisps = CPUParticles2D.new()
	spirit_wisps.amount = 16
	spirit_wisps.lifetime = 1.7
	spirit_wisps.preprocess = 1.0
	spirit_wisps.local_coords = false
	spirit_wisps.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	spirit_wisps.emission_sphere_radius = 260.0
	spirit_wisps.direction = Vector2.UP
	spirit_wisps.spread = 25.0
	spirit_wisps.gravity = Vector2(0.0, -70.0)
	spirit_wisps.initial_velocity_min = 10.0
	spirit_wisps.initial_velocity_max = 45.0
	spirit_wisps.scale_amount_min = 1.5
	spirit_wisps.scale_amount_max = 3.5
	var g := Gradient.new()
	g.set_color(0, Color(0.5, 1.6, 1.2, 0.0))
	g.set_color(1, Color(0.5, 1.6, 1.2, 0.0))
	g.add_point(0.25, Color(0.5, 1.6, 1.2, 0.55))
	spirit_wisps.color_ramp = g
	spirit_wisps.z_index = 2
	add_child(spirit_wisps)

func _spawn_step_mist(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = 7
	p.lifetime = 0.5
	p.direction = Vector2.UP
	p.spread = 80.0
	p.gravity = Vector2(0.0, -40.0)
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 60.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.color = Color(0.5, 1.3, 1.05, 0.5)
	p.z_index = 1
	get_parent().add_child(p)
	p.global_position = pos
	var t := p.create_tween()
	t.tween_interval(0.8)
	t.tween_callback(p.queue_free)

# === Persecución y CLEAVE ===

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
	_spawn_cleave_sweep()
	_spawn_cleave_sparks()
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
		_finish_attack()

# === PISOTÓN ===

func _enter_stomp() -> void:
	state = State.STOMP
	phase_timer = stomp_windup_time
	velocity = Vector2.ZERO
	_spawn_stomp_warning()

func _process_stomp(delta: float) -> void:
	velocity = Vector2.ZERO
	var t := 1.0 - phase_timer / stomp_windup_time
	# Se "alza" para pisar: crece y se tiñe. Junto al círculo en el piso, el
	# jugador tiene 0.5s de lectura clara antes de las ondas.
	parts.scale = Vector2.ONE * (1.0 + 0.14 * (1.0 - pow(1.0 - t, 2.0)))
	modulate = Color.WHITE.lerp(Color(1.5, 0.75, 0.4), t * 0.8)

	phase_timer -= delta
	if phase_timer <= 0.0:
		_do_stomp()
		modulate = Color.WHITE
		stomp_timer = randf_range(stomp_interval_min, stomp_interval_max)
		_finish_attack()

func _spawn_stomp_warning() -> void:
	# Anillo contractor: se cierra hacia el centro en sincronía con el wind-up;
	# cuando llega, cae el pisotón (ver stomp_telegraph.gd).
	_clear_stomp_warning()
	stomp_warning = StompTelegraph.new()
	stomp_warning.setup(stomp_warning_radius, stomp_windup_time)
	get_parent().add_child(stomp_warning)
	stomp_warning.global_position = global_position

func _clear_stomp_warning() -> void:
	if is_instance_valid(stomp_warning):
		stomp_warning.queue_free()
	stomp_warning = null

func _do_stomp() -> void:
	# Pisa el suelo: flash del área, slam de escala, polvo, shake y UNA onda letal
	# que cubre toda la ronda, más rápida que el jugador (no se le huye: se cruza).
	if is_instance_valid(stomp_warning):
		stomp_warning.burst()   # flash del área y fade-out (se libera solo)
		stomp_warning = null
	# Slam: aplasta y rebota a tamaño normal (contraparte del alzado del telegraph).
	parts.scale = Vector2.ONE * 0.93
	var pop := parts.create_tween()
	pop.tween_property(parts, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_dust_burst(global_position, Vector2.DOWN, 24, 360.0)
	_spawn_stomp_impact_fx()
	_shake(13.0)
	_hitstop(0.06)
	_spawn_stomp_ring()

func _spawn_stomp_impact_fx() -> void:
	# Capas del impacto: flash central que se expande y apaga, dos ondas de
	# polvo no letales delante del muro letal, y escombros del suelo.
	var flash := _make_disc(140.0, Color(1.9, 1.3, 0.9, 0.5))
	flash.z_index = 1
	get_parent().add_child(flash)
	flash.global_position = global_position
	var tw := flash.create_tween()
	tw.tween_property(flash, "scale", Vector2.ONE * 1.7, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(flash, "color:a", 0.0, 0.18)
	tw.tween_callback(flash.queue_free)
	for i in range(2):
		var fx := ShockwaveRing.new()
		fx.line_width = 7.0
		get_parent().add_child(fx)
		fx.setup(global_position, 200.0 + 130.0 * float(i), 0.28 + 0.06 * float(i), 0.03 * float(i), Color(1.4, 0.8, 0.5, 0.55), false)
	_spawn_stomp_debris()

func _spawn_stomp_debris() -> void:
	# Piedras oscuras despedidas radialmente que frenan rápido (peso del golpe).
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = 18
	p.lifetime = 0.55
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 40.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 180.0
	p.initial_velocity_max = 460.0
	p.damping_min = 300.0
	p.damping_max = 600.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = Color(0.45, 0.4, 0.34, 1.0)
	p.z_index = 6
	get_parent().add_child(p)
	p.global_position = global_position
	var t := p.create_tween()
	t.tween_interval(0.8)
	t.tween_callback(p.queue_free)

func _spawn_stomp_ring() -> void:
	# La onda cubre la ronda completa: el radio sale de la arena publicada y la
	# expansión es LINEAL a stomp_wave_speed (un muro constante, legible y justo).
	var radius := GameState.arena_radius if GameState.arena_radius > 0.0 else stomp_fallback_radius
	var ring := ShockwaveRing.new()
	ring.line_width = stomp_wave_width
	get_parent().add_child(ring)
	ring.setup(global_position, radius, radius / stomp_wave_speed, 0.0, stomp_ring_color, true, false)

# === AGOTAMIENTO (stun) ===

func _finish_attack() -> void:
	# Cada ataque completado (cleave o pisotón) lo acerca al agotamiento.
	attacks_done += 1
	if attacks_done >= attacks_until_stun:
		_enter_vulnerable()
	else:
		state = State.CHASE

func _enter_vulnerable() -> void:
	state = State.VULNERABLE
	phase_timer = vulnerable_time
	velocity = Vector2.ZERO
	modulate = Color(2.0, 1.9, 1.2)   # flash de entrada: "¡AHORA!"
	_shake(12.0)
	_hitstop(0.1)
	# Burst dorado + disco-timer que se achica con la ventana + chispas sostenidas.
	var ring := ShockwaveRing.new()
	get_parent().add_child(ring)
	ring.setup(global_position, 220.0, 0.4, 0.0, Color(1.6, 1.35, 0.5, 0.9), false)
	_spawn_vulnerable_disc()
	_spawn_vulnerable_sparks()

func _process_vulnerable(delta: float) -> void:
	velocity = Vector2.ZERO
	# Estuneado: pulso dorado, maza caída, cabeza mareada. Imposible no leerlo.
	var pulse := 0.5 + 0.5 * sin(time_accum * 14.0)
	modulate = Color.WHITE.lerp(Color(1.7, 1.45, 0.5), 0.35 + 0.35 * pulse)
	club_target = lerpf(club_target, 1.5, 6.0 * delta)
	head.rotation = sin(time_accum * 9.0) * 0.45

	phase_timer -= delta
	if phase_timer <= 0.0:
		_end_vulnerable()

func _end_vulnerable() -> void:
	# La ventana se cierra: vuelve a blanco de golpe (corte visual claro) y retoma.
	state = State.CHASE
	modulate = Color.WHITE
	club_target = club_rest_angle
	attacks_done = 0
	attacks_until_stun = randi_range(stun_attacks_min, stun_attacks_max)
	stomp_timer = maxf(stomp_timer, 2.5)   # respiro al despertar
	_free_vulnerable_fx()
	_impact_punch()

func _spawn_vulnerable_disc() -> void:
	vulnerable_disc = _make_disc(170.0, Color(1.6, 1.3, 0.4, 0.26))
	vulnerable_disc.z_index = 1
	get_parent().add_child(vulnerable_disc)
	vulnerable_disc.global_position = global_position
	# El disco se achica con la ventana: timer visual de cuánto queda para atacar.
	var tw := vulnerable_disc.create_tween()
	tw.tween_property(vulnerable_disc, "scale", Vector2.ONE * 0.02, vulnerable_time)

func _spawn_vulnerable_sparks() -> void:
	vulnerable_sparks = CPUParticles2D.new()
	vulnerable_sparks.amount = 24
	vulnerable_sparks.lifetime = 0.6
	vulnerable_sparks.local_coords = false
	vulnerable_sparks.direction = Vector2.UP
	vulnerable_sparks.spread = 70.0
	vulnerable_sparks.gravity = Vector2(0.0, -60.0)   # chispas que flotan hacia arriba
	vulnerable_sparks.initial_velocity_min = 40.0
	vulnerable_sparks.initial_velocity_max = 140.0
	vulnerable_sparks.scale_amount_min = 1.5
	vulnerable_sparks.scale_amount_max = 3.0
	vulnerable_sparks.color = Color(1.9, 1.6, 0.6, 1.0)
	vulnerable_sparks.z_index = 7
	get_parent().add_child(vulnerable_sparks)
	vulnerable_sparks.global_position = global_position

func _free_vulnerable_fx() -> void:
	if is_instance_valid(vulnerable_disc):
		vulnerable_disc.queue_free()
	vulnerable_disc = null
	if is_instance_valid(vulnerable_sparks):
		vulnerable_sparks.emitting = false
		var tw := vulnerable_sparks.create_tween()
		tw.tween_interval(0.7)
		tw.tween_callback(vulnerable_sparks.queue_free)
	vulnerable_sparks = null

# === BLOQUEO ===

func _process_block(delta: float) -> void:
	# Congelado: para toda animación y mantiene la pose de escudo al frente.
	velocity = Vector2.ZERO
	shield.rotation = shield_block_pose   # escudo arriba
	club.rotation = club_rest_angle       # maza en guardia
	head.rotation = 0.0                    # cabeza de frente al atacante
	block_hold_timer -= delta
	if block_hold_timer <= 0.0:
		_exit_block()

func _exit_block() -> void:
	state = State.CHASE
	head_rot = 0.0
	gait_was_moving = false
	if anim_player:
		anim_player.play("idle")           # reanuda la respiración

# === Muerte / invulnerabilidad ===

func die() -> void:
	if dying:
		return
	# La ÚNICA ventana de kill es el agotamiento tras 5-10 ataques.
	if state == State.VULNERABLE:
		_die_for_real()
		return
	_on_attacked()

func _die_for_real() -> void:
	dying = true
	remove_from_group("orcs")
	set_physics_process(false)
	GameState.register_kill(score_value, true, enemy_class)
	AudioManager.play_orc_death()
	_clear_telegraph()
	_clear_stomp_warning()
	_free_vulnerable_fx()
	_shake(16.0)
	# Estallido de muerte: ondas doradas no letales + chispas en abanico.
	for i in range(2):
		var ring := ShockwaveRing.new()
		get_parent().add_child(ring)
		ring.setup(global_position, 320.0 + 140.0 * float(i), 0.55, 0.12 * float(i), Color(1.7, 1.4, 0.6, 0.9), false)
	for dir in [Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		_spawn_block_sparks(global_position, dir)
	# Hitstop largo de remate: se oculta ya, pero se libera recién al volver el tiempo
	# (si se libera antes, el await muere con el nodo y el time_scale queda trabado).
	hide()
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.25, true, false, true).timeout
	Engine.time_scale = 1.0
	queue_free()

func _on_attacked() -> void:
	# Solo entra en pose de bloqueo en sus estados "de guardia". Durante el pisotón
	# o el stun el ataque igual rebota (feedback), pero no interrumpe.
	var can_block: bool = state in [State.CHASE, State.WINDUP, State.CLEAVE, State.RECOVER, State.BLOCK]
	if can_block:
		if state != State.BLOCK:
			_clear_telegraph()          # cancela un cleave/telegraph en curso
			modulate = Color.WHITE      # por si quedó tintado de un wind-up
			parts.position = Vector2.ZERO   # corta la marcha a mitad de paso
			body.rotation = 0.0
			if anim_player:
				anim_player.pause()     # congela la respiración
		state = State.BLOCK
		block_hold_timer = block_hold_time
		velocity = Vector2.ZERO
		# Encara al jugador para interponer el escudo.
		if is_instance_valid(player):
			parts.rotation = (player.global_position - global_position).angle() - PI / 2.0

	# Feedback (throttleado) + rebote del jugador.
	if block_cd > 0.0:
		return
	block_cd = 0.12
	var dir := Vector2.DOWN
	if is_instance_valid(player):
		dir = (player.global_position - global_position).normalized()
	_spawn_block_sparks(global_position + dir * 110.0, dir)
	shield.self_modulate = Color(2.2, 2.2, 2.4)
	var tw := shield.create_tween()
	tw.tween_property(shield, "self_modulate", Color.WHITE, 0.2)
	if is_instance_valid(player) and player.has_method("apply_knockback"):
		player.apply_knockback(block_knockback, global_position)
	_shake(5.0)
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

func _make_disc(radius: float, color: Color) -> Polygon2D:
	var pts := PackedVector2Array()
	var segs := 40
	for i in range(segs):
		var a := TAU * float(i) / float(segs)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = color
	return poly

func _spawn_telegraph() -> void:
	# Telegraph con relleno de carga lineal: cuando el frente llega al borde
	# del cono, cae el golpe (ver cleave_telegraph.gd).
	_clear_telegraph()
	telegraph_node = CleaveTelegraph.new()
	telegraph_node.setup(cleave_reach, cleave_half_arc, windup_time)
	get_parent().add_child(telegraph_node)
	telegraph_node.global_position = global_position
	telegraph_node.rotation = committed_rot

func _clear_telegraph() -> void:
	if is_instance_valid(telegraph_node):
		telegraph_node.queue_free()
	telegraph_node = null

func _spawn_cleave_flash() -> void:
	# Flash tenue del área completa: marca el cono golpeado (la hoja barriendo
	# es la protagonista, esto es solo el "piso iluminado").
	var flash := _make_wedge(cleave_reach, cleave_half_arc, Color(1.6, 1.5, 1.2, 0.4))
	flash.z_index = 5
	get_parent().add_child(flash)
	flash.global_position = global_position
	flash.rotation = committed_rot
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.22)
	tw.tween_callback(flash.queue_free)

func _spawn_cleave_sweep() -> void:
	# Hoja de corte: una cuña angosta y MUY brillante barre el cono siguiendo la
	# maza (der→izq), con una segunda cuña tenue de estela. Vende la dirección y
	# la violencia del golpe mucho mejor que un flash estático.
	var slice_half := 0.3
	var travel := cleave_half_arc - slice_half
	for i in range(2):
		var is_trail := i == 1
		var color := Color(1.8, 1.7, 1.4, 0.45) if is_trail else Color(2.4, 2.2, 1.7, 0.95)
		var sweep := _make_wedge(cleave_reach * 1.04, slice_half, color)
		sweep.z_index = 6
		get_parent().add_child(sweep)
		sweep.global_position = global_position
		sweep.rotation = committed_rot + travel
		var tw := sweep.create_tween()
		if is_trail:
			tw.tween_interval(0.045)   # la estela persigue a la hoja
		tw.tween_property(sweep, "rotation", committed_rot - travel, cleave_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sweep, "color:a", 0.0, cleave_time + 0.12)
		tw.tween_callback(sweep.queue_free)

func _spawn_cleave_sparks() -> void:
	# Chispas despedidas desde el medio del arco en el sentido del barrido:
	# remate físico del golpe (viento + impacto).
	var fwd := Vector2.DOWN.rotated(committed_rot)
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = 22
	p.lifetime = 0.4
	p.direction = fwd
	p.spread = 70.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 220.0
	p.initial_velocity_max = 520.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 4.0
	p.color = Color(2.0, 1.8, 1.2, 1.0)
	p.z_index = 6
	get_parent().add_child(p)
	p.global_position = global_position + fwd * (cleave_reach * 0.45)
	var t := p.create_tween()
	t.tween_interval(0.8)
	t.tween_callback(p.queue_free)

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

func _spawn_dust_burst(pos: Vector2, dir: Vector2, count: int, max_velocity: float) -> void:
	# Polvareda de impacto del pisotón.
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = 0.5
	p.direction = dir
	p.spread = 80.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = max_velocity * 0.3
	p.initial_velocity_max = max_velocity
	p.scale_amount_min = 2.5
	p.scale_amount_max = 6.0
	p.color = Color(0.6, 0.55, 0.48, 0.8)
	p.z_index = 6
	get_parent().add_child(p)
	p.global_position = pos
	var t := p.create_tween()
	t.tween_interval(0.8)
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
