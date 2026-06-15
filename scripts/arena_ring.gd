# scripts/arena_ring.gd
# Decoración del arena: construye y anima la "ronda" de siluetas de enemigos
# (orcos, arqueros, magos, berserkers) que delimita el arena circular, y
# dispersa unos cadáveres iniciales cerca del centro.
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

# Siluetas de la ronda: una por cada tipo de enemigo (pose idle) con su escala
# nativa, para que la ronda sea una mezcla de orcos, arqueros, magos y berserkers.
const RING_ENEMY_TYPES: Array = [
	{"texture": preload("res://sprites/orc.png"), "scale": 0.20},
	{"texture": preload("res://sprites/animations_sprites/archer_fire_animation/archer_fire_animation_frame_0000.png"), "scale": 0.18},
	{"texture": preload("res://sprites/animations_sprites/mage_attack/mage_animation_frame_0000.png"), "scale": 0.18},
	{"texture": preload("res://sprites/animations_sprites/berserker_attack_animation/berserker_attack_animation_frame_0000.png"), "scale": 0.22},
]
const DEAD_ORC_TEXTURE: Texture2D = preload("res://sprites/animations_sprites/death_orc/frame11.png")
const BLOOD_SPLAT_SCENE: PackedScene = preload("res://scenes/blood_splat.tscn")
const FOG_SHADER: Shader = preload("res://shaders/arena_fog.gdshader")
const DEAD_BODY_COLOR: Color = Color(0.228, 0.24, 0.3, 1.0)  # gris frío, 20% menos oscuro (×1.2 sobre 0.19,0.2,0.25); igual que orc.gd
const ORC_BLOOD_COLOR: Color = Color(0.08, 0.45, 0.12, 1.0)  # mismo verde que orc.gd

@export var arena_radius: float = 900.0           # radio del arena; el centro es la posición de este nodo
@export var ring_spacing: float = 140.0           # separación aprox. entre siluetas a lo largo del anillo
@export var ring_scale_multiplier: float = 1.0    # multiplica la escala nativa de cada tipo de enemigo
@export var radial_jitter: float = 18.0           # desorden radial para que parezca horda, no círculo perfecto
@export var scale_jitter: float = 0.08            # variación de tamaño por silueta
@export var ring_tint: Color = Color(0.24, 0.264, 0.336, 1.0)  # gris frío, 20% menos oscuro (×1.2 sobre 0.20,0.22,0.28): siluetas más legibles contra la niebla

@export_group("Sway (movimiento sutil)")
@export var sway_position_amplitude: float = 2.5  # px de balanceo posicional (respiración)
@export var sway_rotation_amplitude: float = 0.05 # rad de balanceo de rotación (~3°)
@export var sway_speed_min: float = 0.6           # rad/s
@export var sway_speed_max: float = 1.3

@export_group("Mirada (siguen al jugador con la vista)")
@export var gaze_follow: bool = true
@export var gaze_max_angle: float = 0.20          # rad (~11°): desvío máximo desde mirar al centro. Poco, para no confundir.
@export var gaze_smooth: float = 4.0              # qué tan rápido giran la cabeza hacia el jugador

@export_group("Surge (embestida al cambiar de wave)")
@export var surge_distance: float = 42.0          # cuánto se lanzan las siluetas hacia el centro
@export var surge_color: Color = Color(0.9, 0.55, 0.4, 1.0)  # destello cálido del "rugido"
@export var surge_duration: float = 0.5           # cuánto dura el pulso

@export_group("Niebla (fuera de la ronda)")
@export var fog_enabled: bool = true
@export var fog_color: Color = Color(0.04, 0.05, 0.07, 1.0)  # casi negro, frío y tétrico
@export var fog_inner_offset: float = -30.0       # respecto al radio: dónde empieza la niebla (un poco antes de la ronda)
@export var fog_outer_offset: float = 250.0       # respecto al radio: dónde la niebla es total
@export var fog_max_alpha: float = 1.0
@export var fog_quad_size: float = 4000.0         # cubre toda la vista (y las esquinas del 16:9)
@export var fog_noise_freq: float = 0.004
@export var fog_noise_speed: float = 14.0
@export var fog_edge_wobble: float = 1.0
@export var fog_z_index: int = -1                 # detrás de la ronda (z 0): cubre lo de afuera sin tapar las siluetas

@export_group("Cadáveres iniciales (puntos de referencia)")
@export var corpse_count: int = 7                 # cuántos cadáveres tirar al empezar
@export var corpse_min_radius: float = 150.0      # no encima del jugador (centro)
@export var corpse_max_radius: float = 430.0      # dentro del área visible inicial
@export var corpse_scale: float = 0.2             # mismo tamaño que el orco
@export var corpse_scale_jitter: float = 0.1
@export var corpse_blood: bool = true             # charco de sangre bajo cada cadáver

# Estado por silueta para animar el sway y la mirada sin recalcular nada pesado.
class RingOrc:
	var sprite: Sprite2D
	var base_position: Vector2
	var base_rotation: float   # mirando al centro del arena
	var phase_pos: float
	var phase_rot: float
	var speed_pos: float
	var speed_rot: float
	var gaze_offset: float = 0.0  # desvío actual (suavizado) hacia el jugador

var _orcs: Array = []
var _time: float = 0.0
var _player: Node2D
var _surge: float = 0.0  # 1.0 al disparar la embestida, decae a 0

# La horda embiste: las siluetas se lanzan hacia adentro y destellan ~surge_duration.
func play_horde_surge() -> void:
	_surge = 1.0

func _ready() -> void:
	# Publicar la geometría del arena para que jugador, spawner y cámara la consuman.
	GameState.set_arena(global_position, arena_radius)
	_player = get_tree().get_first_node_in_group("player")
	_build_fog()
	_build_ring()
	_scatter_corpses()

func _build_fog() -> void:
	# Quad world-space centrado en el arena. Un shader lo deja transparente
	# adentro y niebla oscura afuera. Usamos un Sprite2D con una textura blanca
	# de 1px escalada: el shader solo necesita la UV (0..1) para mapear a mundo.
	if not fog_enabled:
		return

	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color.WHITE)
	var texture := ImageTexture.create_from_image(image)

	var material := ShaderMaterial.new()
	material.shader = FOG_SHADER
	material.set_shader_parameter("fog_inner", arena_radius + fog_inner_offset)
	material.set_shader_parameter("fog_outer", arena_radius + fog_outer_offset)
	material.set_shader_parameter("quad_size", fog_quad_size)
	material.set_shader_parameter("fog_color", fog_color)
	material.set_shader_parameter("fog_max_alpha", fog_max_alpha)
	material.set_shader_parameter("noise_freq", fog_noise_freq)
	material.set_shader_parameter("noise_speed", fog_noise_speed)
	material.set_shader_parameter("edge_wobble", fog_edge_wobble)

	var fog := Sprite2D.new()
	fog.texture = texture
	fog.scale = Vector2(fog_quad_size, fog_quad_size)  # 1px * quad_size = quad_size px de mundo
	fog.material = material
	fog.z_index = fog_z_index
	add_child(fog)

func _build_ring() -> void:
	var circumference := TAU * arena_radius
	var count := maxi(int(round(circumference / ring_spacing)), 8)
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		var dir := Vector2(cos(angle), sin(angle))
		var radius := arena_radius + randf_range(-radial_jitter, radial_jitter)
		var pos := dir * radius

		# Tipo de enemigo aleatorio para mezclar siluetas en la ronda.
		var enemy_type: Dictionary = RING_ENEMY_TYPES[randi() % RING_ENEMY_TYPES.size()]

		var sprite := Sprite2D.new()
		sprite.texture = enemy_type["texture"]
		sprite.position = pos
		# Mirar hacia el centro: mismo criterio que el enemigo de combate, donde
		# "arriba" del sprite es el frente (rotación = ángulo_al_objetivo - PI/2).
		var base_rotation := (-pos).angle() - PI / 2.0
		sprite.rotation = base_rotation
		var s: float = float(enemy_type["scale"]) * ring_scale_multiplier * randf_range(1.0 - scale_jitter, 1.0 + scale_jitter)
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

	# Re-resolver el jugador si hace falta (p. ej. tras recargar la escena).
	if gaze_follow and not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	# Embestida: el pulso hace lunge-and-recoil (0 al inicio, pico al medio, 0 al final).
	if _surge > 0.0:
		_surge = maxf(_surge - delta / surge_duration, 0.0)
	var surge_pulse := sin((1.0 - _surge) * PI) if _surge > 0.0 else 0.0

	for o in _orcs:
		var bob := sin(_time * o.speed_pos + o.phase_pos) * sway_position_amplitude
		var pos: Vector2 = o.base_position + Vector2(0.0, bob)
		if surge_pulse > 0.0:
			pos += (-(o.base_position as Vector2).normalized()) * surge_distance * surge_pulse  # hacia el centro
		o.sprite.position = pos
		# Destello cálido del rugido (decae con _surge; en reposo queda en ring_tint).
		o.sprite.modulate = ring_tint.lerp(surge_color, _surge)

		# Mirada: giran un poco la "cabeza" hacia el jugador, con desvío acotado
		# (gaze_max_angle) respecto de mirar al centro, para no confundir.
		if gaze_follow and is_instance_valid(_player):
			var sprite_pos: Vector2 = o.sprite.global_position
			var to_player: float = (_player.global_position - sprite_pos).angle() - PI / 2.0
			var target: float = clampf(wrapf(to_player - o.base_rotation, -PI, PI), -gaze_max_angle, gaze_max_angle)
			o.gaze_offset = lerp_angle(o.gaze_offset, target, clampf(gaze_smooth * delta, 0.0, 1.0))

		var sway := sin(_time * o.speed_rot + o.phase_rot) * sway_rotation_amplitude
		o.sprite.rotation = o.base_rotation + o.gaze_offset + sway
