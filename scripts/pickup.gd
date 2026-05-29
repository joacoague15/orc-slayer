# scripts/pickup.gd
extends Area2D
class_name Pickup

@export var lifetime: float = 10.0
@export var bonus_points: int = 5

@onready var visual: Sprite2D = $CoinSprite

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		var tween := create_tween()
		tween.tween_property(visual, "modulate:a", 0.0, 0.5)
		tween.tween_callback(queue_free)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		AudioManager.play_pickup()
		for i in range(bonus_points):
			GameState.register_kill(1, false)
		queue_free()
