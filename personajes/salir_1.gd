extends TextureButton
@export var ruta_seleccion_personaje: String = "res://escenas/menuprincipal/menu_principal.tscn"

func _ready() -> void:
	pressed.connect(salir)

func salir():
	get_tree().paused = false
	ControladorCarga.ir_a_escena(ruta_seleccion_personaje)
