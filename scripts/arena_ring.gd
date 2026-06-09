# scripts/arena_ring.gd
# Decoración del arena: construye y anima la "ronda" de orcos que delimita el
# arena circular, y dispersa unos cadáveres iniciales cerca del centro.
#
# La ronda es PURAMENTE DECORATIVA: no está en el grupo "orcs", no se puede
# matar y no cuenta para el combo. Es el muro vivo que encierra al jugador y
# comunica el fin del mapa.
#
# Los cadáveres iniciales dan puntos de referencia para que el jugador entienda
# dónde está parado al empezar (la cámara está centrada en él al spawnear).
#
# El límite real del movimiento NO es colisión física (la regla core dice que
# el jugador atraviesa enemigos): se aplica por código en player.gd leyendo la
# geometría del arena que este nodo publica en GameState (fuente única de verdad).
extends Node2D

const ORC_TEXTURE: Texture2D = preload("res://sprites/orc.png")
const DEAD_ORC_TEXTURE: Texture2D = preload("res://sprites/animations_sprites/death_orc/frame11.png")
const BLOOD_SPLAT_SCENE: PackedScene = preload("res://scenes/blood_splat.tscn")
const DEAD_BODY_COLOR: Color = Color(0.45, 0.45, 0.45, 1.0)  # mismo tinte que orc.gd al morir
const ORC_BLOOD_COLOR: Color = Color(0.08, 0.45, 0.12, 1.0)  # mismo verde que orc.gd

@export var arena_radius: float = 900.0           # radio del arena; el centro es la posición de este nodo
@export var orc_spacing: float = 140.0            # separación aprox. entre orcos a lo largo del anillo
@export var orc_scale: float = 0.2                # mismo tamaño que un orco de combate (orc.tscn usa 0.2)
@export var radial_jitter: float = 18.0           # desorden radial para que parezca horda, no círculo perfecto
@export var scale_jitter: float = 0.08            # variación de tamaño por orco
@export var ring_tint: Color = Color(0.82, 0.82, 0.86, 1.0)  # levemente apagado para que la ronda recede

@export_group("Sway (movimiento sutil)")
@export var sway_position_amplitude: float = 2.5  # px de balanceo posicional (respiración)
@export var sway_rotation_amplitude: float = 0.05 # rad de balanceo de rotación (~3°)
@export var sway_speed_min: float = 0.6           # rad/s
@export var sway_speed_max: float = 1.3

@export_group("Cadáveres iniciales (puntos de referencia)")
@export var corpse_count: int = 7                 # cuántos cadáveres tirar al empezar
@export var corpse_min_radius: float = 150.0      # no encima del jugador (centro)
@export var corpse_max_radius: float = 430.0      # dentro del área visible inicial
@export var corpse_scale: float = 0.2             # mismo tamaño que el orco
@export var corpse_scale_jitter: float = 0.1
@export var corpse_blood: bool = true             # charco de sangre bajo cada cadáver

# Estado por orco para animar el sway sin recalcular nada pesado.
class RingOrc:
	var sprite: Sprite2D
	var base_position: Vector2
	var base_rotation: float
	var phase_pos: float
	var phase_rot: float
	var speed_pos: float
	var speed_rot: float

var _orcs: Array = []
var _time: float = 0.0

func _ready() -> void:
	# Publicar la geometría del arena para que jugador, spawner y cámara la consuman.
	GameState.set_arena(global_position, arena_radius)
	_build_ring()
	_scatter_corpses()

func _build_ring() -> void:
	var circumference := TAU * arena_radius
	var count := maxi(int(round(circumference / orc_spacing)), 8)
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		var dir := Vector2(cos(angle), sin(angle))
		var radius := arena_radius + randf_range(-radial_jitter, radial_jitter)
		var pos := dir * radius

		var sprite := Sprite2D.new()
		sprite.texture = ORC_TEXTURE
		sprite.position = pos
		# Mirar hacia el centro: mismo criterio que el orco de combate, donde
		# "arriba" del sprite es el frente (rotación = ángulo_al_objetivo - PI/2).
		var base_rotation := (-pos).angle() - PI / 2.0
		sprite.rotation = base_rotation
		var s := orc_scale * randf_range(1.0 - scale_jitter, 1.0 + scale_jitter)
		sprite.scale = Vector2(s, s)
		sprite.modulate = ring_tint
		sprite.z_index = 0  # detrás de los orcos vivos (z 2): la ronda es telón del arena
		add_child(sprite)

		var ring_orc := RingOrc.new()
		ring_orc.sprite = sprite
		ring_orc.base_position = pos
		ring_orc.base_rotation = base_rotation
		ring_orc.phase_pos = randf() * TAU
		ring_orc.phase_rot = randf() * TAU
		ring_orc.speed_pos = randf_range(sway_speed_min, sway_speed_max)
		ring_orc.speed_rot = randf_range(sway_speed_min, sway_speed_max)
		_orcs.append(ring_orc)

func _scatter_corpses() -> void:
	# Cadáveres estáticos cerca del centro como puntos de referencia. Distribuimos
	# los ángulos de forma pareja (con jitter) para que no se amontonen.
	for i in range(corpse_count):
		var angle := TAU * float(i) / float(corpse_count) + randf_range(-0.4, 0.4)
		var radius := randf_range(corpse_min_radius, corpse_max_radius)
		var pos := Vector2(cos(angle), sin(angle)) * radius

		if corpse_blood:
			_spawn_corpse_blood(pos)

		var corpse := Sprite2D.new()
		corpse.texture = DEAD_ORC_TEXTURE
		corpse.position = pos
		corpse.rotation = randf() * TAU  # tirados en cualquier dirección
		var s := corpse_scale * randf_range(1.0 - corpse_scale_jitter, 1.0 + corpse_scale_jitter)
		corpse.scale = Vector2(s, s)
		corpse.modulate = DEAD_BODY_COLOR
		corpse.z_index = -1  # orden de legibilidad: cadáveres por debajo de los vivos
		add_child(corpse)

func _spawn_corpse_blood(pos: Vector2) -> void:
	var splat := BLOOD_SPLAT_SCENE.instantiate()
	splat.position = pos
	splat.z_index = -2  # sangre en el piso, debajo de los cadáveres
	# Charco decorativo permanente: que no se desvanezca durante la run.
	splat.fade_after = 1.0e9
	add_child(splat)
	splat.setup(ORC_BLOOD_COLOR)

func _process(delta: float) -> void:
	_time += delta
	for o in _orcs:
		var bob := sin(_time * o.speed_pos + o.phase_pos) * sway_position_amplitude
		o.sprite.position = o.base_position + Vector2(0.0, bob)
		o.sprite.rotation = o.base_rotation + sin(_time * o.speed_rot + o.phase_rot) * sway_rotation_amplitude
