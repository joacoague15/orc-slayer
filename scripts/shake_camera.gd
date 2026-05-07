# scripts/shake_camera.gd
extends Camera2D
class_name ShakeCamera

var shake_intensity: float = 0.0
var shake_decay: float = 5.0  # más alto = se calma más rápido

func _process(delta: float) -> void:
	if shake_intensity > 0.0:
		offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		shake_intensity = max(0.0, shake_intensity - shake_decay * delta * 10.0)
	else:
		offset = Vector2.ZERO

func shake(intensity: float, decay: float = 5.0) -> void:
	# Si ya hay un shake más fuerte, no lo pisamos con uno débil
	if intensity > shake_intensity:
		shake_intensity = intensity
	shake_decay = decay
