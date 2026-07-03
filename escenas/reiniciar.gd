extends Button
@export var escenaprincipal1= EscenaPrincipal1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pressed.connect(_reiniciar)


func _reiniciar():
	escenaprincipal1.reiniciar_nivel
	get_tree().change_scene_to_file("res://escenas/escena_principal/escena_principal.tscn")
