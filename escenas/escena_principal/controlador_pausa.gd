class_name ControladorPausa
extends Node

@onready var menu_pausa: Menupausa = $"../menupausa"

func _ready():
	menu_pausa.visible = false
	menu_pausa.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_pausa.continuar.connect(_solicitar_reanudar)

	if ControladorGlobal.es_partida_en_red:
		if not NetworkDiscovery.pausa_recibida.is_connected(_on_pausa_recibida):
			NetworkDiscovery.pausa_recibida.connect(_on_pausa_recibida)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pausa"):
		if get_tree().paused:
			_solicitar_reanudar()
		else:
			_solicitar_pausar()

func _solicitar_pausar() -> void:
	if ControladorGlobal.es_partida_en_red:
		NetworkDiscovery.enviar_pausa(true)
	else:
		pausar()

func _solicitar_reanudar() -> void:
	if ControladorGlobal.es_partida_en_red:
		NetworkDiscovery.enviar_pausa(false)
	else:
		reanudar()

func _on_pausa_recibida(pausado: bool) -> void:
	if pausado:
		pausar()
	else:
		reanudar()

func pausar():
	get_tree().paused = true
	menu_pausa.visible = true

func reanudar():
	get_tree().paused = false
	menu_pausa.visible = false
