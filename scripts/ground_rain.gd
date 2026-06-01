# scripts/ground_rain.gd
extends Node2D

@export var rain_enabled: bool = true
@export var rain_intensity: float = 95.0
@export var active_impact_cap: int = 160
@export var rain_area_padding: float = 96.0
@export var impact_lifetime_min: float = 0.22
@export var impact_lifetime_max: float = 0.5
@export var impact_radius_min: float = 2.0
@export var impact_radius_max: float = 7.0
@export var impact_color: Color = Color(0.55, 0.65, 0.75, 0.28)
@export var splash_wind: Vector2 = Vector2(10.0, 4.0)

var impacts: Array[Dictionary] = []
var spawn_accumulator: float = 0.0

func _ready() -> void:
	z_index = -8

func _process(delta: float) -> void:
	if not rain_enabled:
		return
	
	_spawn_impacts(delta)
	_update_impacts(delta)
	queue_redraw()

func _spawn_impacts(delta: float) -> void:
	spawn_accumulator += rain_intensity * delta
	var spawn_count := int(spawn_accumulator)
	if spawn_count <= 0:
		return
	spawn_accumulator -= float(spawn_count)
	
	for i in range(spawn_count):
		if impacts.size() >= active_impact_cap:
			impacts.pop_front()
		impacts.append(_create_impact())

func _create_impact() -> Dictionary:
	var rect := _get_spawn_rect()
	var impact_position := Vector2(
		randf_range(rect.position.x, rect.position.x + rect.size.x),
		randf_range(rect.position.y, rect.position.y + rect.size.y)
	)
	return {
		"position": impact_position,
		"age": 0.0,
		"lifetime": randf_range(impact_lifetime_min, impact_lifetime_max),
		"max_radius": randf_range(impact_radius_min, impact_radius_max),
		"satellite_count": randi_range(0, 2),
		"satellite_offset": splash_wind.rotated(randf_range(-0.7, 0.7)) * randf_range(0.4, 1.3),
	}

func _get_spawn_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var center := global_position
	var camera := get_viewport().get_camera_2d()
	if camera:
		center = camera.global_position
	
	return Rect2(
		center - viewport_size * 0.5 - Vector2.ONE * rain_area_padding,
		viewport_size + Vector2.ONE * rain_area_padding * 2.0
	)

func _update_impacts(delta: float) -> void:
	for i in range(impacts.size() - 1, -1, -1):
		impacts[i].age += delta
		if impacts[i].age >= impacts[i].lifetime:
			impacts.remove_at(i)

func _draw() -> void:
	for impact in impacts:
		var progress: float = clamp(impact.age / impact.lifetime, 0.0, 1.0)
		var radius: float = impact.max_radius * (0.35 + progress * 0.65)
		var alpha: float = impact_color.a * (1.0 - progress)
		var color := Color(impact_color.r, impact_color.g, impact_color.b, alpha)
		var local_pos: Vector2 = to_local(impact.position)
		
		draw_arc(local_pos, radius, 0.0, TAU, 14, color, 1.0)
		
		for i in range(impact.satellite_count):
			var satellite_progress := float(i + 1) / float(impact.satellite_count + 1)
			var satellite_pos: Vector2 = local_pos + impact.satellite_offset * satellite_progress
			draw_circle(satellite_pos, max(radius * 0.18, 1.0), color)
