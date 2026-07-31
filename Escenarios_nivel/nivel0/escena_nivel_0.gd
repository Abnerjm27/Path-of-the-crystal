class_name EscenaNivel0
extends Node2D

signal muertes_nivel_actualizado(cantidad: int)
const GRUPO_ESCENA_NIVEL_ACTUAL = "escena_nivel_actual"

const RUTA_MENU_NIVELES = "res://resources/menu_partes.tscn"
const RUTA_LOBBY_MULTIJUGADOR = "res://resources/menu_multijugador.tscn"  # AJUSTA a la ruta real

var _nivel_completado := false
var _reiniciando := false   
var _muertes_nivel := 0
var _tiempo_nivel := 0.0
var _jugador1_ref: Node = null   # referencia para reasignar mandos en caliente
var _jugador2_ref: Node = null
@onready var hud = $HUD
@onready var control_movil = $controls   
@export var niveles: Array[PackedScene]
@export var ruta_siguiente_nivel: String = ""
@export var numero_nivel_global: int = 1
@export var zoom_camara: Vector2 = Vector2(1, 1)

var _nivel_actual: int = 1
var _nivel_instanciado: Node
@onready var menu_pausa = $menupausa
@onready var pantalla_final = $PantallaFinal
@export var musica_de_esta_escena: AudioStream

func _enter_tree() -> void:
	add_to_group(GRUPO_ESCENA_NIVEL_ACTUAL)

func _ready() -> void:
	AvisoNivel.mostrar_nivel("Nivel %d" % (numero_nivel_global))
	ControladorMusica.reproducir(musica_de_esta_escena)
	menu_pausa.reiniciar.connect(_on_pausa_reiniciar_pressed)
	menu_pausa.salir.connect(_on_pausa_salir_pressed)
	pantalla_final.reiniciar.connect(_on_pantalla_reiniciar_pressed)
	pantalla_final.salir.connect(_on_pantalla_salir_pressed)
	ResourceLoader.load_threaded_request(RUTA_MENU_NIVELES)
	if ruta_siguiente_nivel != "":
		ResourceLoader.load_threaded_request(ruta_siguiente_nivel)
	_muertes_nivel = 0
	_tiempo_nivel = 0.0
	
	# Todas las conexiones de red van aquí, UNA sola vez, con guarda por seguridad
	if ControladorGlobal.es_partida_en_red:
		if not NetworkDiscovery.muerte_remota_recibida.is_connected(_on_muerte_remota_nivel):
			NetworkDiscovery.muerte_remota_recibida.connect(_on_muerte_remota_nivel)
		if not NetworkDiscovery.siguiente_nivel_recibido.is_connected(ir_a_siguiente_nivel):
			NetworkDiscovery.siguiente_nivel_recibido.connect(ir_a_siguiente_nivel)
		if not NetworkDiscovery.reiniciar_nivel_recibido.is_connected(_on_reiniciar_menu):
			NetworkDiscovery.reiniciar_nivel_recibido.connect(_on_reiniciar_menu)
		if not NetworkDiscovery.salir_recibido.is_connected(_ejecutar_salir_red):
			NetworkDiscovery.salir_recibido.connect(_ejecutar_salir_red)
		if not NetworkDiscovery.conexion_perdida.is_connected(_on_conexion_perdida):
			NetworkDiscovery.conexion_perdida.connect(_on_conexion_perdida)
	_crear_nivel(_nivel_actual)
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _process(delta):
	ControladorGlobal.acumular_tiempo(delta)
	if not _nivel_completado:
		_tiempo_nivel += delta
func _crear_nivel(numero_nivel: int):
	_nivel_completado = false
	_reiniciando = false   
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
		if ControladorGlobal.es_partida_en_red:
			var mandos_conectados_red := Input.get_connected_joypads()
			if mandos_conectados_red.size() > 0:
				jugador1.esquema_control = "mando"
				jugador1.indice_mando = mandos_conectados_red[0]
				ControladorGlobal.configurar_input_map_mando("mando1", mandos_conectados_red[0])
			else:
				jugador1.esquema_control = "teclado"
			# En red cada teléfono controla solo su propio personaje, así
			# que el táctil debe seguir visible si es móvil Y no se está
			# usando mando.
			var es_movil_red = OS.has_feature("mobile")
			control_movil.visible = es_movil_red and jugador1.esquema_control != "mando"
			var jugador2 = _crear_jugador2(jugador1)
			_crear_camara_cooperativa(jugador1, jugador2)
		else:
			control_movil.visible = false
			var jugador2 = _crear_jugador2(jugador1)
			_crear_camara_cooperativa(jugador1, jugador2)
			_jugador1_ref = jugador1
			_jugador2_ref = jugador2
			_reasignar_mandos_cooperativo_local()
	else:
		var es_movil = OS.has_feature("mobile")
		control_movil.visible = es_movil
		var mandos_conectados = Input.get_connected_joypads()
		if mandos_conectados.size() > 0:
			jugador1.esquema_control = "mando"
			jugador1.indice_mando = mandos_conectados[0]
			ControladorGlobal.configurar_input_map_mando("mando1", mandos_conectados[0])
			control_movil.visible = false
		_ajustar_zoom_camara(jugador1)

	# Sincronización determinista de animadores en loop (plataformas,
	# enemigos). Host y cliente entran los dos, cada uno por su lado:
	# ninguno deja que su AnimationPlayer avance solo por fotograma, así
	# no hay margen para que se desvíen entre sí con el paso del tiempo.
	if ControladorGlobal.es_partida_en_red:
		await get_tree().process_frame
		if multiplayer.is_server():
			# El host se vuelve determinista usando su propia posición
			# actual como punto de partida (no necesita pedírsela a nadie).
			NetworkDiscovery.inicializar_animadores_host()
		else:
			# El cliente deja de avanzar solo y pide la fase real al host.
			for animador in get_tree().get_nodes_in_group(NetworkDiscovery.GRUPO_ANIMADORES_SINCRONIZABLES):
				if animador is AnimationPlayer:
					animador.stop()
			NetworkDiscovery.solicitar_sincronizacion_nivel()
func _crear_jugador2(jugador1: Node) -> Node:
	var ruta_escena_personaje = jugador1.scene_file_path
	if ruta_escena_personaje == "":
		push_warning("No se pudo crear al Jugador 2: el Jugador 1 no tiene scene_file_path.")
		return null
	
	var escena_personaje: PackedScene = load(ruta_escena_personaje)
	var jugador2 = escena_personaje.instantiate()
	jugador2.jugador_id = 1
	if ControladorGlobal.es_partida_en_red:
		# En red, cada peer usa su propio teclado completo (sin prefijo p2_)
		jugador2.esquema_control = "teclado"
	else:
		jugador2.esquema_control = ControladorGlobal.esquema_jugador2
		jugador2.indice_mando = ControladorGlobal.indice_mando_jugador2
	jugador2.position = jugador1.position + Vector2(16, 0)
	
	_nivel_instanciado.add_child(jugador2)
	jugador2.personaje_muerto.connect(reiniciar_nivel)
	return jugador2
func _reasignar_mandos_cooperativo_local() -> void:
	if not is_instance_valid(_jugador1_ref) or not is_instance_valid(_jugador2_ref):
		return
	var mandos := Input.get_connected_joypads()
	if mandos.size() >= 2:
		_jugador1_ref.esquema_control = "mando"
		_jugador1_ref.indice_mando = mandos[0]
		ControladorGlobal.configurar_input_map_mando("mando1", mandos[0])
		_jugador2_ref.esquema_control = "mando"
		_jugador2_ref.indice_mando = mandos[1]
		ControladorGlobal.configurar_input_map_mando("mando2", mandos[1])
	elif mandos.size() == 1:
		_jugador1_ref.esquema_control = "teclado"
		_jugador2_ref.esquema_control = "mando"
		_jugador2_ref.indice_mando = mandos[0]
		ControladorGlobal.configurar_input_map_mando("mando2", mandos[0])
	else:
		_jugador1_ref.esquema_control = "teclado"
		_jugador2_ref.esquema_control = "teclado"
func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	if not is_inside_tree():
		return
	if ControladorGlobal.es_partida_en_red:
		return   # en red cada peer usa su propio esquema, esto no aplica
	if not ControladorGlobal.modo_cooperativo_activo:
		return
	_reasignar_mandos_cooperativo_local()
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
	NetworkDiscovery.limpiar_animadores_deterministas()
	_nivel_instanciado.queue_free()
func reiniciar_nivel():
	if _nivel_completado or _reiniciando:
		return
	_reiniciando = true
	if not ControladorGlobal.es_partida_en_red:
		_registrar_muerte()   # en red, el conteo va por _on_muerte_remota_nivel
	_eliminar_nivel()
	_crear_nivel.call_deferred(_nivel_actual)
func _on_muerte_remota_nivel(id_emisor: int) -> void:
	if not is_inside_tree():
		return
	_registrar_muerte()
	if id_emisor != NetworkDiscovery.mi_id():
		await get_tree().create_timer(0.5).timeout
		if not is_inside_tree():
			return
		reiniciar_nivel()
func _registrar_muerte() -> void:
	_muertes_nivel += 1
	print("Muerte registrada. Total en este nivel: ", _muertes_nivel)
	muertes_nivel_actualizado.emit(_muertes_nivel)
func mostrar_pantalla_final(recogidas: int, total: int):
	_nivel_completado = true
	print("Mostrando pantalla final con muertes: ", _muertes_nivel)
	var es_ultimo_nivel = ruta_siguiente_nivel == ""
	pantalla_final.mostrar(recogidas, total, es_ultimo_nivel, _muertes_nivel, _tiempo_nivel)
	ControladorGlobal.actualizar_nivel(numero_nivel_global + 1)
	ControladorGlobal.sumar_racha()
var _cambiando_de_nivel := false   

func ir_a_siguiente_nivel() -> void:
	if not is_inside_tree() or _cambiando_de_nivel:
		return   # esta instancia ya quedó huérfana, o ya se está yendo
	_cambiando_de_nivel = true
	get_tree().paused = false
	if ruta_siguiente_nivel == "":
		_on_salir_menu()
		return
	ControladorCarga.ir_a_escena(ruta_siguiente_nivel)
func _on_reiniciar_menu():
	if not is_inside_tree():
		return
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
	ControladorGlobal.resetear_racha()
	var estado = ResourceLoader.load_threaded_get_status(RUTA_MENU_NIVELES)
	if estado == ResourceLoader.THREAD_LOAD_LOADED:
		var escena = ResourceLoader.load_threaded_get(RUTA_MENU_NIVELES)
		get_tree().change_scene_to_packed(escena)
	else:
		get_tree().change_scene_to_file(RUTA_MENU_NIVELES)

func _on_pantalla_reiniciar_pressed() -> void:
	if ControladorGlobal.es_partida_en_red:
		NetworkDiscovery.enviar_reiniciar_nivel()
	else:
		_on_reiniciar_menu()

func _on_pantalla_salir_pressed() -> void:
	if ControladorGlobal.es_partida_en_red:
		NetworkDiscovery.enviar_salir()
	else:
		_on_salir_menu()

func _ejecutar_salir_red() -> void:
	if not is_inside_tree():
		return
	get_tree().paused = false
	ControladorGlobal.resetear_racha()
	get_tree().change_scene_to_file(RUTA_MENU_NIVELES)
func _on_conexion_perdida(_id: int) -> void:
	if not is_inside_tree():
		return
	get_tree().paused = false
	NetworkDiscovery.cerrar_conexion()
	ControladorGlobal.salir_de_partida_en_red()
	ControladorGlobal.resetear_racha()
	get_tree().change_scene_to_file(RUTA_LOBBY_MULTIJUGADOR)
func _on_pausa_reiniciar_pressed() -> void:
	if ControladorGlobal.es_partida_en_red:
		NetworkDiscovery.enviar_reiniciar_nivel()
	else:
		_on_reiniciar_menu()

func _on_pausa_salir_pressed() -> void:
	if ControladorGlobal.es_partida_en_red:
		NetworkDiscovery.enviar_salir()
	else:
		_on_salir_menu()
