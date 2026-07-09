class_name EscenaNivel0
extends Node2D

const RUTA_MENU_NIVELES = "res://resources/menu_partes.tscn"

@onready var hud = $HUD
@export var niveles: Array[PackedScene]
@export var ruta_siguiente_nivel: String = ""  # vacío si es el último nivel
@export var numero_nivel_global: int = 1  # número real de este nivel (1, 2, 3...20)

var _nivel_actual: int = 1
var _nivel_instanciado: Node
@onready var menu_pausa = $menupausa
@onready var pantalla_final = $PantallaFinal
@export var musica_de_esta_escena: AudioStream

func _ready() -> void:
	ControladorMusica.reproducir(musica_de_esta_escena)
	menu_pausa.reiniciar.connect(_on_reiniciar_menu)
	menu_pausa.salir.connect(_on_salir_menu)
	pantalla_final.reiniciar.connect(_on_reiniciar_menu)
	pantalla_final.salir.connect(_on_salir_menu)
	
	ResourceLoader.load_threaded_request(RUTA_MENU_NIVELES)
	if ruta_siguiente_nivel != "":
		ResourceLoader.load_threaded_request(ruta_siguiente_nivel)  # precarga el siguiente nivel también
	
	_crear_nivel(_nivel_actual)

func _crear_nivel(numero_nivel: int):
	_nivel_instanciado = niveles[numero_nivel - 1].instantiate()
	add_child(_nivel_instanciado)
	
	var hijos := _nivel_instanciado.get_children()
	for i in hijos.size():
		if hijos[i].is_in_group("personajes"):
			hijos[i].personaje_muerto.connect(reiniciar_nivel)
		if hijos[i] is ContenedorMonedas:
			hijos[i].monedas_actualizadas.connect(hud.actualizar_monedas)

func _eliminar_nivel():
	_nivel_instanciado.queue_free()

func reiniciar_nivel():
	_eliminar_nivel()
	_crear_nivel.call_deferred(_nivel_actual)

func mostrar_pantalla_final(recogidas: int, total: int):
	ControladorGlobal.actualizar_nivel(numero_nivel_global + 1)
	
	var es_ultimo_nivel = ruta_siguiente_nivel == ""
	pantalla_final.mostrar(recogidas, total, es_ultimo_nivel)
func ir_a_siguiente_nivel():
	get_tree().paused = false
	if ruta_siguiente_nivel == "":
		_on_salir_menu()  # no hay más niveles, vuelve al menú de niveles
		return
	
	var estado = ResourceLoader.load_threaded_get_status(ruta_siguiente_nivel)
	if estado == ResourceLoader.THREAD_LOAD_LOADED:
		var escena = ResourceLoader.load_threaded_get(ruta_siguiente_nivel)
		get_tree().change_scene_to_packed(escena)
	else:
		ControladorCarga.ir_a_escena(ruta_siguiente_nivel)  # usa tu pantalla de carga con spinner

func _on_reiniciar_menu():
	get_tree().paused = false
	menu_pausa.visible = false
	pantalla_final.visible = false
	reiniciar_nivel()

func _on_salir_menu() -> void:
	get_tree().paused = false
	var estado = ResourceLoader.load_threaded_get_status(RUTA_MENU_NIVELES)
	if estado == ResourceLoader.THREAD_LOAD_LOADED:
		var escena = ResourceLoader.load_threaded_get(RUTA_MENU_NIVELES)
		get_tree().change_scene_to_packed(escena)
	else:
		get_tree().change_scene_to_file(RUTA_MENU_NIVELES)
