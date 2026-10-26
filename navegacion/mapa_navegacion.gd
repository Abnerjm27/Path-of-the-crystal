extends Node

## MapaNavegacion: Gestiona el AStar2D conectando todos los PuntosNavegacion del nivel.
## Al arrancar un nivel, se llama a construir_grafo().

var astar: AStar2D = null
var _puntos_activos: Array[Node] = []

var _escena_actual: Node = null

func _process(_delta: float) -> void:
	var root = get_tree().current_scene
	if root != _escena_actual and root != null:
		_escena_actual = root
		limpiar_grafo()
		call_deferred("construir_grafo")

## Construye la red neuronal del nivel conectando los puntos cercanos que tienen visión directa.
func construir_grafo(distancia_maxima_conexion: float = 350.0) -> void:
	astar = AStar2D.new()
	_puntos_activos = get_tree().get_nodes_in_group("puntos_navegacion")
	
	if _puntos_activos.is_empty():
		return
		
	# 1. Registrar todos los puntos en el AStar2D
	for i in _puntos_activos.size():
		astar.add_point(i, _puntos_activos[i].global_position)
	
	var space_state = get_tree().root.get_world_2d().direct_space_state
	
	# 2. Conectar puntos automáticamente (línea de visión clara)
	for i in _puntos_activos.size():
		for j in range(i + 1, _puntos_activos.size()):
			var p1: Vector2 = _puntos_activos[i].global_position
			var p2: Vector2 = _puntos_activos[j].global_position
			
			if p1.distance_to(p2) <= distancia_maxima_conexion:
				# Trazamos un rayo para ver si hay una pared o suelo entre los puntos
				var query = PhysicsRayQueryParameters2D.create(p1, p2, 1) # Capa 1 es CAPA_SOLIDOS
				var result = space_state.intersect_ray(query)
				
				# Si no chocó con nada sólido, los conectamos (se pueden ver)
				if result.is_empty():
					astar.connect_points(i, j, true)


## El jefe llama a esta función pasándole su posición y la posición del jugador
## Devuelve un Array con los puntos a seguir.
func obtener_ruta(origen: Vector2, destino: Vector2) -> PackedVector2Array:
	if astar == null or astar.get_point_count() == 0:
		return PackedVector2Array()
	
	# Encontramos el ID del punto más cercano al jefe
	var id_origen = astar.get_closest_point(origen)
	# Encontramos el ID del punto más cercano al jugador
	var id_destino = astar.get_closest_point(destino)
	
	# Le pedimos al AStar que nos trace la ruta
	return astar.get_point_path(id_origen, id_destino)


## Llama a esto cuando el nivel termina o se reinicia
func limpiar_grafo() -> void:
	if astar != null:
		astar.clear()
	_puntos_activos.clear()
