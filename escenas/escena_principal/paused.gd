extends TouchScreenButton


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pressed.connect(jugar,4)
func jugar():
	get_tree().change_scene_to_file("res://escenas/menu_pausa.tscn")
