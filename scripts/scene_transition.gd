# scripts/scene_transition.gd
# Autoload: transición fade-to-black entre escenas SIN trabones.
#
# El problema: change_scene_to_file() carga la escena y compila shaders en el
# hilo principal justo al cambiar, lo que produce un freeze visible.
#
# Solución acá:
# 1. Fundido a negro (mientras la escena vieja sigue viva, así el fade es fluido).
# 2. Carga de la escena nueva en SEGUNDO PLANO (ResourceLoader threaded), de modo
#    que el hilo principal no se traba y la pantalla negra no se congela.
# 3. Cambio de escena y unos frames en negro para que corra _ready y se compilen
#    los shaders ocultos detrás del negro.
# 4. Fundido desde negro a la escena ya lista.
extends CanvasLayer

@export var fade_in_duration: float = 0.3    # cuánto tarda en taparse con negro
@export var fade_out_duration: float = 0.35  # cuánto tarda en destaparse
@export var warmup_frames: int = 3           # frames en negro tras el swap (shaders)

var _overlay: ColorRect
var _busy: bool = false
var _loading_path: String = ""

func _ready() -> void:
	layer = 128  # por encima de cualquier CanvasLayer del juego
	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # transparente => no bloquea
	_overlay.modulate.a = 0.0
	add_child(_overlay)
	set_process(false)

# Cambia a `path` con fundido. Ignora llamadas mientras ya hay una transición.
func transition_to_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # bloquea input durante la transición

	var fade_in := create_tween()
	fade_in.tween_property(_overlay, "modulate:a", 1.0, fade_in_duration)
	await fade_in.finished

	# Carga en segundo plano: el hilo principal queda libre y el negro no se traba.
	_loading_path = path
	ResourceLoader.load_threaded_request(path)
	set_process(true)

func _process(_delta: float) -> void:
	if _loading_path == "":
		return
	var status := ResourceLoader.load_threaded_get_status(_loading_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		var packed: PackedScene = ResourceLoader.load_threaded_get(_loading_path)
		_loading_path = ""
		_swap_and_reveal(packed)
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		set_process(false)
		push_error("SceneTransition: no se pudo cargar " + _loading_path)
		_loading_path = ""
		_reveal()

func _swap_and_reveal(packed: PackedScene) -> void:
	get_tree().change_scene_to_packed(packed)
	# Unos frames en negro: corre _ready de la escena nueva y se compilan los
	# shaders detrás del negro, así no se ve el hitch.
	for _i in range(maxi(warmup_frames, 1)):
		await get_tree().process_frame
	_reveal()

func _reveal() -> void:
	var fade_out := create_tween()
	fade_out.tween_property(_overlay, "modulate:a", 0.0, fade_out_duration)
	await fade_out.finished
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
