extends TextureButton

func _ready() -> void:
	pressed.connect(salir)

func salir():
	get_tree().paused = false
	ControladorCarga.ir_a_escena("res://resources/menu_partes.tscn")
