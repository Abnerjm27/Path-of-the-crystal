extends TextureButton
@export var escena2: PackedScene

func _ready() -> void:
	pressed.connect(jugar)

func jugar():
	ControladorGlobal.nivel = 1
	get_tree().change_scene_to_packed(escena2)
