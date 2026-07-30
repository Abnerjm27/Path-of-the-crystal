extends TextureButton

@export var ruta :String
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pressed.connect(jugar,4)

func jugar():
	ControladorCarga.ir_a_escena(ruta)
