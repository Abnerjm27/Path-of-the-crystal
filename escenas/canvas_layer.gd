class_name MenuPausa
extends CanvasLayer

signal continuar
signal reiniciar
signal salir

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _on_continuar_pressed():
	continuar.emit()

func _on_reiniciar_pressed():
	reiniciar.emit()

func _on_salir_pressed():
	salir.emit()
