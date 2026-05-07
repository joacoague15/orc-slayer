# scripts/game_state.gd
extends Node

signal score_changed(new_score: int)
signal combo_changed(combo: int)

var score: int = 0
var highscore: int = 0
var combo: int = 0

const SAVE_PATH := "user://highscore.save"
const COMBO_TIMEOUT: float = 3.5

var combo_timer: float = 0.0

var time_survived: float = 0.0
var is_running: bool = false

func _ready() -> void:
	load_highscore()

func _process(delta: float) -> void:
	if is_running:
		time_survived += delta
	
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			reset_combo()

func register_kill() -> void:
	combo += 1
	combo_timer = COMBO_TIMEOUT
	combo_changed.emit(combo)
	add_score(combo)  # cada kill suma puntos = combo actual

func reset_combo() -> void:
	combo = 0
	combo_timer = 0.0
	combo_changed.emit(combo)

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func reset_score() -> void:
	score = 0
	time_survived = 0.0
	is_running = true
	reset_combo()
	score_changed.emit(score)

func try_update_highscore() -> bool:
	if score > highscore:
		highscore = score
		save_highscore()
		return true
	return false

func save_highscore() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_32(highscore)

func load_highscore() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		highscore = file.get_32()
	
func stop_timer() -> void:
	is_running = false
	
var game_over: bool = false

func trigger_game_over() -> void:
	game_over = true
	is_running = false
