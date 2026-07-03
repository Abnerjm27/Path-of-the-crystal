extends Button

@export var escena2: PackedScene
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pressed.connect(jugar,4)

func jugar():
	get_tree().change_scene_to_packed(escena2)
