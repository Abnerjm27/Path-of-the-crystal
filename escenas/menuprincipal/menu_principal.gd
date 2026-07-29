extends Control
@export var musica_de_esta_escena: AudioStream
@onready var menu_opciones = $MenuOpciones
@onready var fondo_opciones = $FondoOpciones
@onready var boton_opciones = $BotonOpciones
const RUTA_PANTALLA_LOGROS = "res://sistemas logros/pantalla_logros.tscn"

func _ready() -> void:
	ControladorMusica.reproducir(musica_de_esta_escena)
	ResourceLoader.load_threaded_request(RUTA_PANTALLA_LOGROS)
	fondo_opciones.visible = false
	NavegacionMando.conectar_efecto_foco(get_tree().get_nodes_in_group("botones_menu_principal"))
	boton_opciones.grab_focus()

func _on_boton_opciones_pressed():
	menu_opciones.visible = true
	fondo_opciones.visible = true
	menu_opciones.enfocar_primer_boton()
	NavegacionMando.bloquear_controles(get_tree().get_nodes_in_group("botones_menu_principal"), true)

func _on_menu_opciones_volver():
	menu_opciones.visible = false
	fondo_opciones.visible = false
	NavegacionMando.bloquear_controles(get_tree().get_nodes_in_group("botones_menu_principal"), false)
	NavegacionMando.enfocar_con_seguridad(boton_opciones)

func _on_boton_logros_pressed():
	var estado = ResourceLoader.load_threaded_get_status(RUTA_PANTALLA_LOGROS)
	if estado == ResourceLoader.THREAD_LOAD_LOADED:
		var escena = ResourceLoader.load_threaded_get(RUTA_PANTALLA_LOGROS)
		get_tree().change_scene_to_packed(escena)
	else:
		get_tree().change_scene_to_file(RUTA_PANTALLA_LOGROS)
