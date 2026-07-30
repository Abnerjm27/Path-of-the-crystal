extends TextureButton

func _ready() -> void:
	pressed.connect(_salir)

func _salir():
	if disabled:
		return
	disabled = true
	if ControladorGlobal.es_partida_en_red:
		NetworkDiscovery.enviar_salir_del_juego()
		await get_tree().create_timer(0.15).timeout
	get_tree().quit()
