extends Control
@export var musica_de_esta_escena: AudioStream
const RUTA_SELECCION_PERSONAJE = "res://personajes/seleccionpersonaje.tscn"

func _ready() -> void:
	ControladorMusica.reproducir(musica_de_esta_escena)
	_refrescar_botones()
	ResourceLoader.load_threaded_request(RUTA_SELECCION_PERSONAJE)
	await get_tree().process_frame  # esperar a que los contenedores terminen el layout
	_configurar_navegacion_mando()

func _refrescar_botones():
	for boton in get_tree().get_nodes_in_group("botones_nivel"):
		boton.actualizar_estado()

func _configurar_navegacion_mando():
	var filas: Array = [
		$HBoxContainer.get_children(),
		$HBoxContainer2.get_children(),
		$HBoxContainer3.get_children(),  # incluye niveles 18-20 + botón Salir
	]
	_asignar_navegacion_por_filas(filas)

	var todos_los_botones: Array = []
	for fila in filas:
		todos_los_botones.append_array(fila)
	NavegacionMando.conectar_efecto_foco(todos_los_botones)

	var continuar = _buscar_nivel_a_continuar(todos_los_botones)
	if continuar:
		NavegacionMando.enfocar_con_seguridad(continuar)

func _asignar_navegacion_por_filas(filas: Array) -> void:
	# Izquierda/derecha: dentro de cada fila, en orden de aparición
	for fila in filas:
		for i in fila.size():
			var boton = fila[i]
			boton.focus_neighbor_left = fila[i - 1].get_path() if i > 0 else NodePath()
			boton.focus_neighbor_right = fila[i + 1].get_path() if i < fila.size() - 1 else NodePath()

	# Arriba/abajo: entre filas, según el botón más cercano en X (no por índice,
	# porque las filas tienen distinta cantidad de botones)
	for f in filas.size():
		if f > 0:
			for boton in filas[f]:
				boton.focus_neighbor_top = _boton_mas_cercano_en_x(boton, filas[f - 1]).get_path()
		if f < filas.size() - 1:
			for boton in filas[f]:
				boton.focus_neighbor_bottom = _boton_mas_cercano_en_x(boton, filas[f + 1]).get_path()

func _boton_mas_cercano_en_x(boton: Control, fila: Array) -> Control:
	var mejor: Control = fila[0]
	var menor_distancia = abs(boton.global_position.x - fila[0].global_position.x)
	for candidato in fila:
		var distancia = abs(boton.global_position.x - candidato.global_position.x)
		if distancia < menor_distancia:
			menor_distancia = distancia
			mejor = candidato
	return mejor

func _buscar_nivel_a_continuar(botones: Array):
	var mejor = null
	for boton in botones:
		if "disabled" in boton and boton.disabled:
			continue
		if "numero_nivel" in boton and (mejor == null or boton.numero_nivel > mejor.numero_nivel):
			mejor = boton
	return mejor
