extends Camera2D

var jugador: Node2D

func _ready():
	_buscar_jugador()

func _buscar_jugador():
	await get_tree().process_frame
	jugador = get_tree().get_first_node_in_group("personajes")
	if not jugador:
		_buscar_jugador()

func _process(_delta):
	if jugador and is_instance_valid(jugador):
		global_position = jugador.global_position
	else:
		jugador = null
		_buscar_jugador()
