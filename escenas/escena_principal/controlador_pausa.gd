class_name ControladorPausa
extends Node

@onready var menu_pausa: Menupausa = $"../menupausa"

func _ready():
	menu_pausa.visible = false
	menu_pausa.process_mode = Node.PROCESS_MODE_ALWAYS
	print(menu_pausa)
	menu_pausa.continuar.connect(reanudar)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pausa"):
		if get_tree().paused:
			reanudar()
		else:
			pausar()

func pausar():
	get_tree().paused = true
	menu_pausa.visible = true

func reanudar():
	get_tree().paused = false
	menu_pausa.visible = false
