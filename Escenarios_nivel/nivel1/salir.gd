extends TextureButton
@export var ruta_seleccion_personaje: String = "res://personajes/seleccionpersonaje.tscn"
@export var ruta_lobby_multijugador: String = "res://resources/menu_multijugador.tscn"  # AJUSTA a la ruta real de tu lobby

func _ready() -> void:
	pressed.connect(salir)
	if ControladorGlobal.es_partida_en_red:
		if not NetworkDiscovery.abandonar_multijugador_recibido.is_connected(_on_abandonar_recibido):
			NetworkDiscovery.abandonar_multijugador_recibido.connect(_on_abandonar_recibido)
		if not NetworkDiscovery.conexion_perdida.is_connected(_on_conexion_perdida_lobby):
			NetworkDiscovery.conexion_perdida.connect(_on_conexion_perdida_lobby)
func salir():
	if disabled:
		return
	disabled = true
	get_tree().paused = false
	if ControladorGlobal.es_partida_en_red:
		NetworkDiscovery.enviar_abandonar_multijugador()
	else:
		ControladorCarga.ir_a_escena(ruta_seleccion_personaje)
func _on_abandonar_recibido() -> void:
	await get_tree().create_timer(0.2).timeout
	NetworkDiscovery.cerrar_conexion()
	ControladorGlobal.salir_de_partida_en_red()
	get_tree().change_scene_to_file(ruta_lobby_multijugador)

func _on_conexion_perdida_lobby(_id: int) -> void:
	NetworkDiscovery.cerrar_conexion()
	ControladorGlobal.salir_de_partida_en_red()
	get_tree().change_scene_to_file(ruta_lobby_multijugador)
