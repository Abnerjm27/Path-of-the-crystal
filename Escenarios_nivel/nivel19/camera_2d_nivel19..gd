extends Camera2D

var jugadores: Array = []

func _ready():
	_buscar_jugadores()

func _buscar_jugadores():
	await get_tree().process_frame
	jugadores = get_tree().get_nodes_in_group("personajes")
	if jugadores.is_empty():
		_buscar_jugadores()

func _process(_delta):
	# limpiamos jugadores que ya no existen (murieron, nivel se reinició, etc.)
	jugadores = jugadores.filter(func(j): return is_instance_valid(j))
	
	if jugadores.is_empty():
		_buscar_jugadores()
		return
	
	var suma := Vector2.ZERO
	for j in jugadores:
		suma += j.global_position
	global_position = suma / jugadores.size()
