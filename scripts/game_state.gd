# scripts/game_state.gd
extends Node

signal score_changed(new_score: int)
signal combo_changed(combo: int)
signal kill_count_changed(kill_count: int)
signal spawn_weights_changed

var score: int = 0
var highscore: int = 0
var combo: int = 0
var kill_count: int = 0
var kills_by_class: Dictionary = {}  # enemy_class (StringName) -> cantidad eliminada en la run

# Sistema de anger persistente
var total_anger: int = 0
var current_level: int = 1

const SAVE_PATH := "user://savegame.save"
const COMBO_TIMEOUT: float = 3.5
const POINTS_PER_ANGER: int = 10  # 10 puntos = 1 anger

var combo_timer: float = 0.0
var time_survived: float = 0.0
var is_running: bool = false
var game_over: bool = false

# === Arena ===
# Geometría del arena circular. La publica arena_ring.gd y la consumen el
# jugador (clamp de movimiento), el spawner y la cámara.
# arena_radius == 0.0 significa "sin arena acotada" (mundo infinito legacy).
var arena_center: Vector2 = Vector2.ZERO
var arena_radius: float = 0.0
var arena_player_margin: float = 50.0  # margen para que el jugador no se solape con la ronda
var spawn_enemy_enabled: Dictionary = {
	"normal": true,
	"archer": true,
	"mage": true,
	"berserker": true,
}
var spawn_enemy_weight_multiplier: Dictionary = {
	"normal": 1.0,
	"archer": 1.0,
	"mage": 1.0,
	"berserker": 1.0,
}

# Modo de test del menú: si está ON, todas las waves spawnean solo el Warlord.
var boss_only_mode: bool = false

func _ready() -> void:
	load_save()

func _process(delta: float) -> void:
	if is_running:
		time_survived += delta
	
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			reset_combo()

func register_kill(score_multiplier: int = 1, counts_as_enemy_kill: bool = true, enemy_class: StringName = &"") -> void:
	if counts_as_enemy_kill:
		kill_count += 1
		kill_count_changed.emit(kill_count)
		if enemy_class != &"":
			kills_by_class[enemy_class] = int(kills_by_class.get(enemy_class, 0)) + 1
	combo += 1
	combo_timer = COMBO_TIMEOUT
	combo_changed.emit(combo)
	add_score(combo * score_multiplier)

func set_arena(center: Vector2, radius: float) -> void:
	arena_center = center
	arena_radius = radius

func get_kills_of_class(enemy_class: StringName) -> int:
	return int(kills_by_class.get(enemy_class, 0))

func reset_combo() -> void:
	combo = 0
	combo_timer = 0.0
	combo_changed.emit(combo)

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func reset_score() -> void:
	score = 0
	kill_count = 0
	kills_by_class.clear()
	time_survived = 0.0
	is_running = true
	game_over = false
	reset_combo()
	score_changed.emit(score)
	kill_count_changed.emit(kill_count)

func stop_timer() -> void:
	is_running = false

func trigger_game_over() -> void:
	game_over = true
	is_running = false

func try_update_highscore() -> bool:
	if score > highscore:
		highscore = score
		save_progress()
		return true
	return false

func set_spawn_enemy_enabled(enemy_key: String, enabled: bool) -> void:
	if not spawn_enemy_enabled.has(enemy_key):
		return
	spawn_enemy_enabled[enemy_key] = enabled
	spawn_weights_changed.emit()

func is_spawn_enemy_enabled(enemy_key: String) -> bool:
	return bool(spawn_enemy_enabled.get(enemy_key, true))

func set_spawn_enemy_weight_multiplier(enemy_key: String, multiplier: float) -> void:
	if not spawn_enemy_weight_multiplier.has(enemy_key):
		return
	spawn_enemy_weight_multiplier[enemy_key] = clampf(multiplier, 0.0, 3.0)
	spawn_weights_changed.emit()

func get_spawn_enemy_weight_multiplier(enemy_key: String) -> float:
	return float(spawn_enemy_weight_multiplier.get(enemy_key, 1.0))

func get_spawn_enemy_weight_factor(enemy_key: String) -> float:
	if not is_spawn_enemy_enabled(enemy_key):
		return 0.0
	return get_spawn_enemy_weight_multiplier(enemy_key)

func reset_spawn_enemy_weights() -> void:
	for enemy_key in spawn_enemy_enabled.keys():
		spawn_enemy_enabled[enemy_key] = true
	for enemy_key in spawn_enemy_weight_multiplier.keys():
		spawn_enemy_weight_multiplier[enemy_key] = 1.0
	spawn_weights_changed.emit()

# === Anger system ===

func points_to_anger(points: int) -> int:
	return points / POINTS_PER_ANGER

func anger_needed_for_next_level(level: int) -> int:
	return 100 * level

func add_anger(amount: int) -> Dictionary:
	var levels_gained := 0
	total_anger += amount
	
	# Recalcular el nivel desde cero basado en total_anger
	var new_level := calculate_level_from_total_anger(total_anger)
	if new_level > current_level:
		levels_gained = new_level - current_level
		current_level = new_level
	
	save_progress()
	return {"levels_gained": levels_gained}
	


func calculate_level_from_total_anger(anger: int) -> int:
	# Anger acumulado necesario para llegar al nivel N: 100 + 200 + ... + (N-1)*100
	# Eso es: 100 * (N-1) * N / 2 (suma de los primeros N-1 enteros multiplicada por 100)
	# Despejando: N = (1 + sqrt(1 + 8*anger/100)) / 2
	if anger < 100:
		return 1
	var n := (1.0 + sqrt(1.0 + 8.0 * float(anger) / 100.0)) / 2.0
	return int(n)

func get_anger_in_current_level() -> int:
	var anger_for_previous_levels := 0
	for lvl in range(1, current_level):
		anger_for_previous_levels += anger_needed_for_next_level(lvl)
	return total_anger - anger_for_previous_levels

func get_anger_needed_for_current_level() -> int:
	return anger_needed_for_next_level(current_level)

func save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_32(highscore)
		file.store_32(total_anger)
		file.store_32(current_level)

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		highscore = file.get_32()
		total_anger = file.get_32()
		current_level = file.get_32()
		if current_level < 1:
			current_level = 1
			
func reset_save() -> void:
	highscore = 0
	total_anger = 0
	current_level = 1
	save_progress()
	print("[GAMESTATE] Save reseteado")
