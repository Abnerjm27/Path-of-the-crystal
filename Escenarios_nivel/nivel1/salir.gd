extends TextureButton
@export var ruta_seleccion_personaje: String = "res://personajes/seleccionpersonaje.tscn"

func _ready() -> void:
	pressed.connect(salir)

func salir():
	get_tree().paused = false
	ControladorCarga.ir_a_escena(ruta_seleccion_personaje)
