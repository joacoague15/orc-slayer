# scripts/touch_controls.gd
# Capa de controles táctiles (twin-stick) para celular/web táctil.
# - Stick izquierdo: movimiento (el jugador lo lee con get_move_vector()).
# - Stick derecho: apuntado; al deflectarlo dispara la acción "attack"
#   (estilo Archero) y expone la dirección con get_aim_direction().
# - Botón de dash: dispara la acción "dash" (la dirección sale de last_move_direction).
#
# Arbitra el multitouch a mano: un único _input centraliza los toques y los
# asigna por índice de dedo, con prioridad al botón de dash. Requiere
# emulate_mouse_from_touch = false (ver project.godot) para que los toques NO se
# conviertan en clicks de mouse y disparen "attack" por accidente.
extends CanvasLayer

@onready var move_stick: Control = $Root/MoveStick
@onready var aim_stick: Control = $Root/AimStick
@onready var dash_button: Control = $Root/DashButton

var _move_idx: int = -1
var _aim_idx: int = -1
var _dash_idx: int = -1

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event.index, event.position)
		else:
			_on_release(event.index)
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position)

func _on_press(index: int, pos: Vector2) -> void:
	# Prioridad: el botón de dash gana al stick de apuntado (que lo solapa).
	if _dash_idx == -1 and dash_button.contains_point(pos):
		_dash_idx = index
		dash_button.set_pressed(true)
		Input.action_press("dash")
		return
	if _move_idx == -1 and move_stick.get_global_rect().has_point(pos):
		_move_idx = index
		move_stick.begin(pos)
		return
	if _aim_idx == -1 and aim_stick.get_global_rect().has_point(pos):
		_aim_idx = index
		aim_stick.begin(pos)

func _on_drag(index: int, pos: Vector2) -> void:
	if index == _move_idx:
		move_stick.update_drag(pos)
	elif index == _aim_idx:
		aim_stick.update_drag(pos)

func _on_release(index: int) -> void:
	if index == _dash_idx:
		_dash_idx = -1
		dash_button.set_pressed(false)
		Input.action_release("dash")
	elif index == _move_idx:
		_move_idx = -1
		move_stick.end()
	elif index == _aim_idx:
		_aim_idx = -1
		aim_stick.end()

func _process(_delta: float) -> void:
	# El stick derecho deflectado = atacar (auto-fire mientras se sostiene).
	if aim_stick.output != Vector2.ZERO:
		Input.action_press("attack")
	else:
		Input.action_release("attack")

func get_move_vector() -> Vector2:
	return move_stick.output

func get_aim_direction() -> Vector2:
	var o: Vector2 = aim_stick.output
	return o.normalized() if o != Vector2.ZERO else Vector2.ZERO
