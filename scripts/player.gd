# scripts/player.gd
extends CharacterBody2D

signal died

@export var move_speed: float = 250.0
@export var slice_speed_multiplier: float = 0.5
@export var slice_cooldown: float = 0.3
@export var slice_scene: PackedScene

var is_slicing: bool = false
var can_slice: bool = true
var is_dead: bool = false

@onready var slice_cooldown_timer: Timer = $SliceCooldownTimer

var last_position: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return
	
	var input_vector := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()
	
	var current_speed := move_speed
	if is_slicing:
		current_speed *= slice_speed_multiplier
	
	velocity = input_vector * current_speed
	move_and_slide()
	
	if Input.is_action_just_pressed("attack") and can_slice:
		do_slice()

func do_slice() -> void:
	AudioManager.play_slice()
	can_slice = false
	is_slicing = true
	slice_cooldown_timer.start()
	
	$Camera2D.shake(2.0)
	
	var mouse_pos := get_global_mouse_position()
	var direction := (mouse_pos - global_position).angle()
	
	var slice := slice_scene.instantiate()
	# Setear posición ANTES de add_child para que _ready() del slice
	# se ejecute con la posición correcta
	slice.position = global_position
	slice.rotation = direction
	get_tree().current_scene.add_child(slice)
	
	await get_tree().create_timer(0.15).timeout
	is_slicing = false

func die() -> void:
	if is_dead:
		return
	is_dead = true
	AudioManager.play_player_death()
	$Camera2D.shake(15.0, 3.0)
	died.emit()
	hide()
	
func _on_slice_cooldown_timer_timeout() -> void:
	can_slice = true
