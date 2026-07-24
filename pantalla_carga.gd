extends Control

@onready var barra_progreso = $ProgressBar
@onready var fondo = $ColorRect
@onready var spinner = $Spinner

var _progreso := []
var _cargando := true

func _ready():
	fondo.modulate.a = 1.0
	_fade_in()
	_girar_spinner()
	ResourceLoader.load_threaded_request(ControladorCarga.ruta_escena_destino)

func _fade_in():
	var tween = create_tween()
	tween.tween_property(fondo, "modulate:a", 0.0, 0.4)

func _girar_spinner():
	var tween = create_tween()
	tween.set_loops()  # se repite infinitamente
	tween.tween_property(spinner, "rotation_degrees", 360.0, 1.0).as_relative()

func _process(_delta):
	if not _cargando:
		return
	
	var estado = ResourceLoader.load_threaded_get_status(ControladorCarga.ruta_escena_destino, _progreso)
	
	match estado:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			barra_progreso.value = _progreso[0] * 200
		ResourceLoader.THREAD_LOAD_LOADED:
			_cargando = false
			_fade_out_y_cambiar()
		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Error al cargar la escena: " + ControladorCarga.ruta_escena_destino)

func _fade_out_y_cambiar():
	var tween = create_tween()
	tween.tween_property(fondo, "modulate:a", 1.0, 0.4)
	tween.tween_callback(_cambiar_escena)

func _cambiar_escena():
	var escena = ResourceLoader.load_threaded_get(ControladorCarga.ruta_escena_destino)
	get_tree().change_scene_to_packed(escena)
