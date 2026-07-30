extends TextureButton

@export var menu_principal : String
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pressed.connect(play)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func play():
	ControladorCarga.ir_a_escena(menu_principal)
