# scripts/arcane_residue.gd
extends Node2D

@export var lifetime: float = 0.65
@export var base_radius: float = 18.0
@export var spark_count_min: int = 3
@export var spark_count_max: int = 6

@onready var visual: Polygon2D = $Visual

var sparks: Array[Dictionary] = []

func _ready() -> void:
	visual.visible = false
	_generate_sparks()
	scale *= randf_range(0.85, 1.25)
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "scale", scale * 0.65, lifetime)
	tween.parallel().tween_property(self, "modulate:a", 0.0, lifetime)
	tween.tween_callback(queue_free)

func _generate_sparks() -> void:
	var count := randi_range(spark_count_min, spark_count_max)
	for i in range(count):
		var angle := randf() * TAU
		var distance := randf_range(base_radius * 0.25, base_radius * 1.25)
		sparks.append({
			"position": Vector2(cos(angle), sin(angle)) * distance,
			"length": randf_range(5.0, 18.0),
			"angle": angle + randf_range(-0.8, 0.8),
			"alpha": randf_range(0.45, 1.0),
		})

func _draw() -> void:
	var core := Color(0.72, 0.96, 1.0, 0.76)
	var glow := Color(0.22, 0.86, 1.0, 0.36)
	var dark := Color(0.04, 0.18, 0.38, 0.42)
	
	draw_circle(Vector2.ZERO, base_radius * 0.55, dark)
	draw_arc(Vector2.ZERO, base_radius, 0.0, TAU, 24, glow, 2.0)
	draw_arc(Vector2.ZERO, base_radius * 0.62, 0.4, TAU - 0.6, 20, core, 1.4)
	draw_arc(Vector2.ZERO, base_radius * 1.32, -0.9, 1.9, 18, Color(0.8, 0.95, 1.0, 0.28), 1.0)
	
	for i in range(6):
		var angle := TAU * float(i) / 6.0
		var inner := Vector2(cos(angle), sin(angle)) * base_radius * 0.22
		var outer := Vector2(cos(angle), sin(angle)) * base_radius * 0.82
		draw_line(inner, outer, Color(0.62, 0.94, 1.0, 0.4), 1.0)
	
	for spark in sparks:
		var spark_alpha: float = spark.alpha
		var start: Vector2 = spark.position
		var dir: Vector2 = Vector2(cos(spark.angle), sin(spark.angle))
		var end: Vector2 = start + dir * spark.length
		draw_line(start, end, Color(0.85, 0.95, 1.0, 0.55 * spark_alpha), 1.2)
		draw_circle(start, 1.8, Color(0.62, 0.94, 1.0, 0.78 * spark_alpha))
