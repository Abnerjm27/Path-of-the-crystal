extends Button
@export var controlador_partida: ControladorPartida
@export var boton_jugar: Button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pressed.connect(_cargar)

func _cargar():
	controlador_partida.cargar_partida()
	get_tree().change_scene_to_file("res://resources/menu_partes.tscn")
