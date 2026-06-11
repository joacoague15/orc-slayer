# scripts/boss_warlord.gd
# Boss Warlord.
#
# TRES ATAQUES (y una sola apertura):
# 1) CLEAVE  — arco frontal telegrafiado. Alcance -20% y cadencia +15% respecto
#              del prototipo: siempre hay ventana de esquive.
# 2) PISOTÓN — telegrafía 0.5s (se alza + círculo de advertencia en el piso) y
#              libera 2-3 ondas expansivas LETALES escalonadas.
# 3) CARGA   — 3-4 embestidas a alta velocidad contra el jugador, cada una hasta
#              chocar con el borde de la ronda. La ÚLTIMA se telegrafía DORADA y
#              al chocar queda VULNERABLE 1.5s: la ÚNICA ventana para matarlo
#              (de un golpe, como todo en el juego).
#
# - PUNTERÍA EN DOS CAPAS: la cabeza gira rápido hacia el jugador hasta un límite;
#   si el jugador se sale de ese cono, el CUERPO rota (lento) para reencararlo.
#   El cuerpo lento crea un PUNTO CIEGO a la espalda que el jugador puede explotar.
# - Fuera de la ventana vulnerable es INVULNERABLE: se escuda; cualquier golpe
#   rebota con chispas y knockback (ver die() / _on_attacked()).
#
# Forward del boss = su eje local +Y (mira "hacia abajo"/cámara con rotación 0).
extends CharacterBody2D

const ShockwaveRing := preload("res://scripts/shockwave_ring.gd")

@export var move_speed: float = 240.0               # +25% (antes 192)
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

@export_group("Cleave")
@export var cleave_trigger_range: float = 224.0     # acompaña el -20% del alcance (antes 280)
@export var cleave_reach: float = 256.0             # -20% (antes 320)
@export var cleave_half_arc: float = 1.2            # rad (~69°) de medio cono
@export var windup_time: float = 0.69               # +15% (antes 0.6): más ventana de lectura
@export var cleave_time: float = 0.28
@export var recover_time: float = 0.63              # +15% (antes 0.55): más ventana entre golpes
@export var windup_body_turn_speed: float = 6.0     # al telegrafiar encara rápido y fija la dirección
@export var club_rest_angle: float = 0.0
@export var club_windup_angle: float = 1.1          # carga a la DERECHA (wind-up)
@export var club_swing_angle: float = -1.2          # barre hacia la IZQUIERDA (swing der→izq)

@export_group("Pisotón")
@export var stomp_interval_min: float = 5.0
@export var stomp_interval_max: float = 9.0
@export var stomp_windup_time: float = 0.5          # telegraph: se alza + círculo de advertencia
@export var stomp_ring_count_min: int = 2
@export var stomp_ring_count_max: int = 3
@export var stomp_ring_stagger: float = 0.16        # retraso entre ondas
@export var stomp_radius: float = 260.0
@export var stomp_expand_time: float = 0.6
@export var stomp_ring_color: Color = Color(1.5, 0.62, 0.3, 0.9)  # naranja caliente: lee "letal"

@export_group("Carga")
@export var charge_first_delay: float = 6.0         # primera secuencia tras aparecer
@export var charge_interval_min: float = 9.0
@export var charge_interval_max: float = 13.0
@export var charge_count_min: int = 3
@export var charge_count_max: int = 4
@export var charge_aim_time: float = 0.55           # telegraph por carga (corredor en el piso)
@export var charge_aim_turn_speed: float = 7.0      # rad/s con que el apuntado sigue al jugador
@export var charge_speed: float = 1060.0
@export var charge_hit_radius: float = 110.0        # contacto letal durante la embestida
@export var charge_edge_margin: float = 90.0        # a esta distancia del radio se considera "chocó"
@export var charge_max_distance: float = 1100.0     # tope si no hay arena publicada (legacy)
@export var charge_rest_time: float = 0.45          # pausa entre cargas (re-apuntado)
@export var vulnerable_time: float = 1.5            # ventana de kill tras la última carga

enum State { CHASE, WINDUP, CLEAVE, RECOVER, BLOCK, STOMP, CHARGE_AIM, CHARGE_RUN, CHARGE_REST, VULNERABLE }

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
var telegraph_node: Polygon2D = null

var stomp_timer: float = 6.0
var stomp_warning: Polygon2D = null     # círculo de advertencia del pisotón

var charge_timer: float = 6.0
var charges_left: int = 0
var charge_dir: Vector2 = Vector2.DOWN
var charge_traveled: float = 0.0
var charge_telegraph: Polygon2D = null  # corredor de la embestida
var charge_dust: CPUParticles2D = null  # polvareda que deja al correr

var vulnerable_disc: Polygon2D = null   # disco-timer dorado (se achica con la ventana)
var vulnerable_sparks: CPUParticles2D = null
var dying: bool = false                 # evita doble registro de kill en la ventana

@onready var parts: Node2D = $Parts
@onready var head: Sprite2D = $Parts/Head
@onready var club: Sprite2D = $Parts/RightArm   # brazo con maza
@onready var shield: Sprite2D = $Parts/LeftArm  # brazo con escudo
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	if not is_in_group("orcs"):
		add_to_group("orcs")
	player = get_tree().get_first_node_in_group("player")
	stomp_timer = randf_range(stomp_interval_min, stomp_interval_max)
	charge_timer = charge_first_delay

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

	# Sin contacto-letal pasivo: las amenazas letales son los 3 ataques telegrafiados.
	# El frente está escudado: atacarlo fuera de la ventana rebota al jugador (ver die()).

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
		State.CHARGE_AIM:
			_process_charge_aim(delta)
		State.CHARGE_RUN:
			_process_charge_run(delta)
		State.CHARGE_REST:
			_process_charge_rest(delta)
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

	# Scheduler de ataques: solo elige mientras persigue. La carga tiene prioridad.
	if state == State.CHASE:
		stomp_timer -= delta
		charge_timer -= delta
		if charge_timer <= 0.0:
			_start_charge_sequence()
		elif stomp_timer <= 0.0:
			_enter_stomp()

	move_and_slide()

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
		state = State.CHASE
		stomp_timer = randf_range(stomp_interval_min, stomp_interval_max)

func _spawn_stomp_warning() -> void:
	_clear_stomp_warning()
	stomp_warning = _make_disc(stomp_radius, Color(1.0, 0.25, 0.12, 0.0))
	stomp_warning.z_index = 1
	get_parent().add_child(stomp_warning)
	stomp_warning.global_position = global_position
	var tw := stomp_warning.create_tween()
	tw.tween_property(stomp_warning, "color:a", 0.14, stomp_windup_time * 0.8)

func _clear_stomp_warning() -> void:
	if is_instance_valid(stomp_warning):
		stomp_warning.queue_free()
	stomp_warning = null

func _do_stomp() -> void:
	# Pisa el suelo: flash del área, slam de escala, polvo, shake y ondas letales.
	if is_instance_valid(stomp_warning):
		var tw := stomp_warning.create_tween()
		tw.tween_property(stomp_warning, "color:a", 0.0, 0.18).from(0.3)
		tw.tween_callback(stomp_warning.queue_free)
		stomp_warning = null
	# Slam: aplasta y rebota a tamaño normal (contraparte del alzado del telegraph).
	parts.scale = Vector2.ONE * 0.93
	var pop := parts.create_tween()
	pop.tween_property(parts, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_dust_burst(global_position, Vector2.DOWN, 24, 360.0)
	_shake(10.0)
	_hitstop(0.04)
	var ring_count := randi_range(stomp_ring_count_min, stomp_ring_count_max)
	for i in range(ring_count):
		_spawn_stomp_ring(float(i) * stomp_ring_stagger)

func _spawn_stomp_ring(delay: float) -> void:
	var ring := ShockwaveRing.new()
	get_parent().add_child(ring)
	ring.setup(global_position, stomp_radius, stomp_expand_time, delay, stomp_ring_color, true)

# === CARGA ===

func _start_charge_sequence() -> void:
	charges_left = randi_range(charge_count_min, charge_count_max)
	_enter_charge_aim()

func _enter_charge_aim() -> void:
	state = State.CHARGE_AIM
	phase_timer = charge_aim_time
	velocity = Vector2.ZERO
	# Arranca apuntando hacia donde mira el cuerpo y gira (acotado) hacia el jugador:
	# el corredor se lee y deja margen real de esquive.
	charge_dir = Vector2.DOWN.rotated(parts.rotation)
	_spawn_charge_telegraph()

func _process_charge_aim(delta: float) -> void:
	velocity = Vector2.ZERO
	var want := (player.global_position - global_position).normalized()
	charge_dir = Vector2.from_angle(rotate_toward(charge_dir.angle(), want.angle(), charge_aim_turn_speed * delta))
	parts.rotation = charge_dir.angle() - PI / 2.0
	_update_charge_telegraph()

	# Anticipación: tiembla y se tiñe. La ÚLTIMA carga se anuncia DORADA:
	# es la que termina con el boss vulnerable.
	var t := 1.0 - phase_timer / charge_aim_time
	var tint := Color(1.8, 1.6, 0.9) if charges_left == 1 else Color(1.5, 0.5, 0.4)
	modulate = Color.WHITE.lerp(tint, 0.25 + 0.55 * t)
	parts.scale = Vector2.ONE * (1.0 + sin(time_accum * 45.0) * 0.02 * t)

	phase_timer -= delta
	if phase_timer <= 0.0:
		_launch_charge()

func _launch_charge() -> void:
	state = State.CHARGE_RUN
	charge_traveled = 0.0
	parts.scale = Vector2.ONE
	parts.rotation = charge_dir.angle() - PI / 2.0
	velocity = charge_dir * charge_speed
	_fade_charge_telegraph()
	_start_charge_dust()
	_impact_punch()
	_shake(6.0)
	AudioManager.play_berserker_attack()

func _process_charge_run(delta: float) -> void:
	velocity = charge_dir * charge_speed
	parts.rotation = charge_dir.angle() - PI / 2.0
	charge_traveled += charge_speed * delta
	if is_instance_valid(charge_dust):
		charge_dust.global_position = global_position

	# Contacto letal: arrolla al jugador (die() respeta i-frames/dash).
	if is_instance_valid(player) and player.has_method("die"):
		if player.global_position.distance_to(global_position) <= charge_hit_radius:
			player.die()

	# ¿Chocó con el borde de la ronda?
	var crashed := false
	if GameState.arena_radius > 0.0:
		var rel := global_position - GameState.arena_center
		if rel.length() >= GameState.arena_radius - charge_edge_margin:
			global_position = GameState.arena_center + rel.normalized() * (GameState.arena_radius - charge_edge_margin)
			crashed = true
	elif charge_traveled >= charge_max_distance:
		crashed = true   # sin arena publicada (legacy): tope por distancia

	if crashed:
		_crash_into_edge()

func _crash_into_edge() -> void:
	charges_left -= 1
	_stop_charge_dust()
	_spawn_dust_burst(global_position, -charge_dir, 26, 420.0)
	_impact_punch()
	_shake(11.0)
	if charges_left <= 0:
		_hitstop(0.1)
		_enter_vulnerable()
	else:
		modulate = Color.WHITE
		state = State.CHARGE_REST
		phase_timer = charge_rest_time

func _process_charge_rest(delta: float) -> void:
	velocity = Vector2.ZERO
	phase_timer -= delta
	if phase_timer <= 0.0:
		_enter_charge_aim()

func _spawn_charge_telegraph() -> void:
	_clear_charge_telegraph()
	var color := Color(1.5, 1.2, 0.3, 0.0) if charges_left == 1 else Color(1.0, 0.18, 0.1, 0.0)
	charge_telegraph = Polygon2D.new()
	charge_telegraph.polygon = _corridor_points(_distance_to_arena_edge(global_position, charge_dir), charge_hit_radius)
	charge_telegraph.color = color
	charge_telegraph.z_index = 1
	get_parent().add_child(charge_telegraph)
	charge_telegraph.global_position = global_position
	charge_telegraph.rotation = charge_dir.angle() - PI / 2.0
	var tw := charge_telegraph.create_tween()
	tw.tween_property(charge_telegraph, "color:a", 0.28, charge_aim_time)

func _update_charge_telegraph() -> void:
	if not is_instance_valid(charge_telegraph):
		return
	charge_telegraph.rotation = charge_dir.angle() - PI / 2.0
	charge_telegraph.polygon = _corridor_points(_distance_to_arena_edge(global_position, charge_dir), charge_hit_radius)

func _fade_charge_telegraph() -> void:
	# Al lanzarse, el corredor se apaga rápido (la amenaza ya está en movimiento).
	if not is_instance_valid(charge_telegraph):
		return
	var tw := charge_telegraph.create_tween()
	tw.tween_property(charge_telegraph, "color:a", 0.0, 0.15)
	tw.tween_callback(charge_telegraph.queue_free)
	charge_telegraph = null

func _clear_charge_telegraph() -> void:
	if is_instance_valid(charge_telegraph):
		charge_telegraph.queue_free()
	charge_telegraph = null

func _distance_to_arena_edge(from: Vector2, dir: Vector2) -> float:
	# Largo del corredor: intersección rayo-círculo contra el borde jugable.
	if GameState.arena_radius <= 0.0:
		return charge_max_distance
	var rel := from - GameState.arena_center
	var r := GameState.arena_radius - charge_edge_margin
	var b := rel.dot(dir)
	var disc := b * b - (rel.length_squared() - r * r)
	if disc <= 0.0:
		return 0.0
	return maxf(-b + sqrt(disc), 0.0)

func _start_charge_dust() -> void:
	charge_dust = CPUParticles2D.new()
	charge_dust.amount = 40
	charge_dust.lifetime = 0.45
	charge_dust.local_coords = false      # la estela queda fija en el mundo
	charge_dust.direction = -charge_dir
	charge_dust.spread = 28.0
	charge_dust.gravity = Vector2.ZERO
	charge_dust.initial_velocity_min = 60.0
	charge_dust.initial_velocity_max = 170.0
	charge_dust.scale_amount_min = 2.0
	charge_dust.scale_amount_max = 5.0
	charge_dust.color = Color(0.55, 0.5, 0.45, 0.7)
	charge_dust.z_index = 1
	get_parent().add_child(charge_dust)
	charge_dust.global_position = global_position

func _stop_charge_dust() -> void:
	if not is_instance_valid(charge_dust):
		charge_dust = null
		return
	charge_dust.emitting = false
	var tw := charge_dust.create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(charge_dust.queue_free)
	charge_dust = null

# === VENTANA VULNERABLE ===

func _enter_vulnerable() -> void:
	state = State.VULNERABLE
	phase_timer = vulnerable_time
	velocity = Vector2.ZERO
	modulate = Color(2.0, 1.9, 1.2)   # flash de entrada: "¡AHORA!"
	_shake(12.0)
	# Burst dorado + disco-timer que se achica con la ventana + chispas sostenidas.
	var ring := ShockwaveRing.new()
	get_parent().add_child(ring)
	ring.setup(global_position, 220.0, 0.4, 0.0, Color(1.6, 1.35, 0.5, 0.9), false)
	_spawn_vulnerable_disc()
	_spawn_vulnerable_sparks()

func _process_vulnerable(delta: float) -> void:
	velocity = Vector2.ZERO
	# Aturdido: pulso dorado, maza caída, cabeza mareada. Imposible no leerlo.
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
	charge_timer = randf_range(charge_interval_min, charge_interval_max)
	stomp_timer = maxf(stomp_timer, 2.5)   # respiro tras la secuencia de cargas
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
	if anim_player:
		anim_player.speed_scale = 1.0      # reanuda la respiración

# === Muerte / invulnerabilidad ===

func die() -> void:
	if dying:
		return
	# La ÚNICA ventana de kill es el aturdimiento tras la última carga.
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
	_clear_charge_telegraph()
	_clear_stomp_warning()
	_stop_charge_dust()
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
	# Solo entra en pose de bloqueo en sus estados "de guardia". Durante pisotón,
	# cargas o aturdimiento el ataque igual rebota (feedback), pero no interrumpe.
	var can_block: bool = state in [State.CHASE, State.WINDUP, State.CLEAVE, State.RECOVER, State.BLOCK]
	if can_block:
		if state != State.BLOCK:
			_clear_telegraph()          # cancela un cleave/telegraph en curso
			modulate = Color.WHITE      # por si quedó tintado de un wind-up
			if anim_player:
				anim_player.speed_scale = 0.0   # para la respiración
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

func _corridor_points(length: float, half_width: float) -> PackedVector2Array:
	# Rectángulo que apunta a +Y (forward local); se rota a la dirección de carga.
	return PackedVector2Array([
		Vector2(-half_width, 0.0), Vector2(half_width, 0.0),
		Vector2(half_width, length), Vector2(-half_width, length),
	])

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

func _spawn_dust_burst(pos: Vector2, dir: Vector2, count: int, max_velocity: float) -> void:
	# Polvareda de impacto (pisotón / choque contra el borde).
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
