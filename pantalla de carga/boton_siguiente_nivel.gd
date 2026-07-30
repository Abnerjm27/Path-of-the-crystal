extends TextureButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pressed.connect(siguiente)

func siguiente():
	disabled = true   # NUEVO: evita doble click mientras se procesa el cambio
	if ControladorGlobal.es_partida_en_red:
		NetworkDiscovery.enviar_siguiente_nivel()
	else:
		get_tree().current_scene.ir_a_siguiente_nivel()
