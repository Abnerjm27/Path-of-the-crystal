extends Control

@export var musica_de_esta_escena: AudioStream
const RUTA_SELECCION_PERSONAJE = "res://personajes/seleccionpersonaje.tscn"

@onready var grid: HBoxContainer = $HBoxContainer/ScrollContainer/GridContainer
@onready var boton_salir: Control = $HBoxContainer/Salir
@onready var scroll: ScrollContainer = $HBoxContainer/ScrollContainer

# --- Fondo parallax ---
@export var factor_capa_montanas: float = 0.15
@export var factor_capa_nubes: float = 0.3
@onready var capa_montanas: TextureRect = $FondoParallax/CapaMontañas
@onready var capa_nubes: TextureRect = $FondoParallax/CapaNubes

# --- Partículas flotantes ---
@onready var particulas_flotantes: GPUParticles2D = $ParticulasFlotantes


func _ready() -> void:
	ControladorMusica.reproducir(musica_de_esta_escena)
	_refrescar_botones()
	ResourceLoader.load_threaded_request(RUTA_SELECCION_PERSONAJE)

	if ControladorGlobal.es_partida_en_red:
		if not NetworkDiscovery.nivel_elegido_recibido.is_connected(_on_nivel_elegido_recibido):
			NetworkDiscovery.nivel_elegido_recibido.connect(_on_nivel_elegido_recibido)

	scroll.get_h_scroll_bar().value_changed.connect(_on_scroll_cambiado)
	_configurar_particulas_flotantes()

	await get_tree().process_frame
	_configurar_navegacion_mando()


func _on_nivel_elegido_recibido(ruta: String) -> void:
	ControladorCarga.ir_a_escena(ruta)


func _refrescar_botones():
	for boton in get_tree().get_nodes_in_group("botones_nivel"):
		boton.actualizar_estado()


# --- Parallax ---
func _on_scroll_cambiado(valor: float) -> void:
	capa_montanas.position.x = -valor * factor_capa_montanas
	capa_nubes.position.x = -valor * factor_capa_nubes


# --- Navegación con mando ---
# Una sola fila horizontal de niveles (con scroll)
# y el botón Salir debajo, siempre alcanzable con "abajo".
func _configurar_navegacion_mando():
	var todos: Array = grid.get_children()
	var fila: Array = todos.filter(_puede_enfocar)
	_asignar_navegacion_horizontal(fila)
	_conectar_boton_salir(fila)
	var enfocables: Array = fila.duplicate()
	enfocables.append(boton_salir)
	NavegacionMando.conectar_efecto_foco(enfocables)
	var continuar = _buscar_nivel_a_continuar(fila)
	if continuar:
		NavegacionMando.enfocar_con_seguridad(continuar)
	else:
		NavegacionMando.enfocar_con_seguridad(boton_salir)


func _puede_enfocar(boton: Control) -> bool:
	if "disabled" in boton and boton.disabled:
		return boton.focus_mode != Control.FOCUS_NONE
	return true


func _asignar_navegacion_horizontal(fila: Array) -> void:
	for i in fila.size():
		var boton = fila[i]
		boton.focus_neighbor_left = fila[i - 1].get_path() if i > 0 else NodePath()
		boton.focus_neighbor_right = fila[i + 1].get_path() if i < fila.size() - 1 else NodePath()
		# Desde cualquier nivel, "abajo" lleva directo a Salir
		boton.focus_neighbor_bottom = boton_salir.get_path()


func _conectar_boton_salir(fila: Array) -> void:
	if fila.size() > 0:
		# Desde Salir, "arriba" regresa al primer nivel enfocable
		boton_salir.focus_neighbor_top = fila[0].get_path()


func _buscar_nivel_a_continuar(botones: Array):
	var mejor = null
	for boton in botones:
		if "numero_nivel" in boton and (mejor == null or boton.numero_nivel > mejor.numero_nivel):
			mejor = boton
	return mejor


# --- Partículas flotantes (polvo mágico), generadas por código ---
func _configurar_particulas_flotantes() -> void:
	particulas_flotantes.texture = _crear_textura_glow(64)

	var tam_pantalla: Vector2 = get_viewport_rect().size
	particulas_flotantes.position = tam_pantalla / 2.0

	particulas_flotantes.amount = 50
	particulas_flotantes.lifetime = 6.0
	particulas_flotantes.preprocess = 2.0
	particulas_flotantes.explosiveness = 0.0
	particulas_flotantes.randomness = 0.3
	particulas_flotantes.local_coords = false

	var material := ParticleProcessMaterial.new()

	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(tam_pantalla.x / 2.0, tam_pantalla.y / 2.0, 0.0)

	material.direction = Vector3(0, -1, 0)
	material.spread = 35.0

	material.gravity = Vector3(0, -8, 0)

	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 15.0

	material.scale_min = 0.05
	material.scale_max = 0.15

	var curva_escala := Curve.new()
	curva_escala.add_point(Vector2(0.0, 0.0))
	curva_escala.add_point(Vector2(0.2, 1.0))
	curva_escala.add_point(Vector2(0.8, 1.0))
	curva_escala.add_point(Vector2(1.0, 0.0))
	var curva_textura := CurveTexture.new()
	curva_textura.curve = curva_escala
	material.scale_curve = curva_textura

	material.color = Color(1.0, 0.85, 0.5, 1.0)

	var gradiente := Gradient.new()
	gradiente.set_color(0, Color(1.0, 0.85, 0.5, 0.0))
	gradiente.add_point(0.5, Color(1.0, 0.85, 0.5, 1.0))
	gradiente.set_color(1, Color(1.0, 0.85, 0.5, 0.0))
	var rampa_textura := GradientTexture1D.new()
	rampa_textura.gradient = gradiente
	material.color_ramp = rampa_textura

	particulas_flotantes.process_material = material


func _crear_textura_glow(tamano: int) -> ImageTexture:
	var imagen := Image.create(tamano, tamano, false, Image.FORMAT_RGBA8)
	var centro := Vector2(tamano / 2.0, tamano / 2.0)
	var radio_max: float = tamano / 2.0

	for y in tamano:
		for x in tamano:
			var distancia: float = Vector2(x, y).distance_to(centro)
			var t: float = clamp(distancia / radio_max, 0.0, 1.0)
			var alpha: float = pow(1.0 - t, 2.0)
			imagen.set_pixel(x, y, Color(1, 1, 1, alpha))

	return ImageTexture.create_from_image(imagen)
