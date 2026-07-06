
extends TextureButton

@export var ruta_escena_principal: String

func _ready() -> void:
	pressed.connect(jugar)

func jugar():
	ControladorCarga.ir_a_escena(ruta_escena_principal)
