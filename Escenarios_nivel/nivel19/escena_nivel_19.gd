class_name EscenaNivel19
extends Node2D
const RUTA_MENU_NIVELES = "res://resources/menu_partes.tscn"
@export var zoom_camara: Vector2 = Vector2(4.0, 4.0)
var _nivel_completado := false
var _reiniciando := false  
var _muertes_nivel := 0
var _tiempo_nivel := 0.0
@onready var minimapa = $HUD/Minimapa
@onready var hud = $HUD
@onready var control_movil = $controls   
@export var niveles: Array[PackedScene]
@export var ruta_siguiente_nivel: String = ""  #
@export var numero_nivel_global: int = 1  
var _nivel_actual: int = 1
var _nivel_instanciado: Node
@onready var menu_pausa = $menupausa
@onready var pantalla_final = $PantallaFinal
@export var musica_de_esta_escena: AudioStream

func _ready() -> void:
	get_viewport().canvas_cull_mask = 3   
	AvisoNivel.mostrar_nivel("Nivel %d" % (numero_nivel_global + 1))
	ControladorMusica.reproducir(musica_de_esta_escena)
	menu_pausa.reiniciar.connect(_on_reiniciar_menu)
	menu_pausa.salir.connect(_on_salir_menu)
	menu_pausa.visibility_changed.connect(_on_menu_pausa_visibility_changed)
	pantalla_final.reiniciar.connect(_on_reiniciar_menu)
	pantalla_final.salir.connect(_on_salir_menu)
	
	ResourceLoader.load_threaded_request(RUTA_MENU_NIVELES)
	if ruta_siguiente_nivel != "":
		ResourceLoader.load_threaded_request(ruta_siguiente_nivel)
	
	_muertes_nivel = 0
	_tiempo_nivel = 0.0
	_crear_nivel(_nivel_actual)

func _process(delta):
	ControladorGlobal.acumular_tiempo(delta)
	if not _nivel_completado:
		_tiempo_nivel += delta

func _on_menu_pausa_visibility_changed():
	minimapa.visible = not menu_pausa.visible

func _crear_nivel(numero_nivel: int):
	_nivel_completado = false
	_reiniciando = false   # NUEVO
	_nivel_instanciado = niveles[numero_nivel - 1].instantiate()
	add_child(_nivel_instanciado)
	
	var hijos := _nivel_instanciado.get_children()
	var jugador1: Node = null
	for i in hijos.size():
		if hijos[i].is_in_group("personajes"):
			jugador1 = hijos[i]
			hijos[i].personaje_muerto.connect(reiniciar_nivel)
		if hijos[i] is ContenedorMonedas:
			hijos[i].monedas_actualizadas.connect(hud.actualizar_monedas)
	
	if jugador1 == null:
		return
	
	if ControladorGlobal.modo_cooperativo_activo:
		jugador1.esquema_control = ControladorGlobal.esquema_jugador1
		jugador1.indice_mando = ControladorGlobal.indice_mando_jugador1
		var jugador2 = _crear_jugador2(jugador1)
		_crear_camara_cooperativa(jugador1, jugador2)
		control_movil.visible = false   #  cooperativo, ambos usan mando; el táctil no sirve
	else:
		control_movil.visible = true
		# En un solo jugador, si hay un mando conectado, lo usamos automáticamente.
		var mandos_conectados = Input.get_connected_joypads()
		if mandos_conectados.size() > 0:
			jugador1.esquema_control = "mando"
			jugador1.indice_mando = mandos_conectados[0]
			ControladorGlobal.configurar_input_map_mando("mando1", mandos_conectados[0])
			control_movil.visible = false   # con mando conectado tampoco hace falta el táctil
		_ajustar_zoom_camara(jugador1)

# ── NUEVO: crea al Jugador 2 al lado del Jugador 1 y devuelve la referencia ──
func _crear_jugador2(jugador1: Node) -> Node:
	var ruta_escena_personaje = jugador1.scene_file_path
	if ruta_escena_personaje == "":
		push_warning("No se pudo crear al Jugador 2: el Jugador 1 no tiene scene_file_path.")
		return null
	
	var escena_personaje: PackedScene = load(ruta_escena_personaje)
	var jugador2 = escena_personaje.instantiate()
	jugador2.jugador_id = 1
	jugador2.esquema_control = ControladorGlobal.esquema_jugador2
	jugador2.indice_mando = ControladorGlobal.indice_mando_jugador2
	jugador2.position = jugador1.position + Vector2(30, 0)
	
	_nivel_instanciado.add_child(jugador2)
	jugador2.personaje_muerto.connect(reiniciar_nivel)
	return jugador2

# ── NUEVO: apaga las cámaras propias de cada jugador y crea la cámara compartida ──
func _crear_camara_cooperativa(jugador1: Node, jugador2: Node):
	var camara1 = jugador1.get_node_or_null("Camera2D")
	if camara1:
		camara1.enabled = false
	if jugador2:
		var camara2 = jugador2.get_node_or_null("Camera2D")
		if camara2:
			camara2.enabled = false
	
	var camara_coop = preload("res://escenas/camara_cooperativa.gd").new()
	camara_coop.name = "CamaraCooperativa"
	_nivel_instanciado.add_child(camara_coop)
	camara_coop.configurar(jugador1, jugador2, zoom_camara)
	camara_coop.make_current()

func _ajustar_zoom_camara(personaje: Node):
	var camara = personaje.get_node_or_null("Camera2D")
	if camara:
		camara.zoom = zoom_camara

func _eliminar_nivel():
	_nivel_instanciado.queue_free()

func reiniciar_nivel():
	if _nivel_completado or _reiniciando:
		return  # ignora cualquier señal de muerte tardía o duplicada
	_reiniciando = true
	_muertes_nivel += 1
	_eliminar_nivel()
	_crear_nivel.call_deferred(_nivel_actual)

func mostrar_pantalla_final(recogidas: int, total: int):
	_nivel_completado = true  # marca el nivel como completado ANTES de mostrar la pantalla
	
	minimapa.visible = false
	
	var es_ultimo_nivel = ruta_siguiente_nivel == ""
	pantalla_final.mostrar(recogidas, total, es_ultimo_nivel, _muertes_nivel, _tiempo_nivel)
	ControladorGlobal.actualizar_nivel(numero_nivel_global + 1)
	ControladorGlobal.sumar_racha()

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
	_nivel_completado = false
	_reiniciando = false
	_eliminar_nivel()
	_muertes_nivel = 0
	_tiempo_nivel = 0.0
	_crear_nivel.call_deferred(_nivel_actual)

func _on_salir_menu() -> void:
	get_tree().paused = false
	ControladorGlobal.resetear_racha()  # se rompe la racha al salir al menú
	var estado = ResourceLoader.load_threaded_get_status(RUTA_MENU_NIVELES)
	if estado == ResourceLoader.THREAD_LOAD_LOADED:
		var escena = ResourceLoader.load_threaded_get(RUTA_MENU_NIVELES)
		get_tree().change_scene_to_packed(escena)
	else:
		get_tree().change_scene_to_file(RUTA_MENU_NIVELES)
