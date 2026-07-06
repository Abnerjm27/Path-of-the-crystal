extends TextureButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pressed.connect(siguiente)

func siguiente():
	get_tree().current_scene.ir_a_siguiente_nivel()
