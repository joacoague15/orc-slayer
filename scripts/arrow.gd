# scripts/arrow.gd
extends Area2D

signal player_hit(player: Node2D)

@export var speed: float = 520.0
@export var lifetime: float = 10.0

var direction: Vector2 = Vector2.RIGHT
var lifetime_timer: float = 0.0

func setup(shoot_direction: Vector2, arrow_speed: float, arrow_lifetime: float) -> void:
	direction = shoot_direction.normalized()
	speed = arrow_speed
	lifetime = arrow_lifetime
	rotation = direction.angle()

func _ready() -> void:
	lifetime_timer = lifetime
	body_entered.connect(_on_body_entered)
	player_hit.connect(_on_player_hit)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime_timer -= delta
	if lifetime_timer <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	player_hit.emit(body)

func _on_player_hit(player: Node2D) -> void:
	if player.has_method("is_damage_invulnerable") and player.is_damage_invulnerable():
		return
	if player.has_method("die"):
		player.die()
	queue_free()
