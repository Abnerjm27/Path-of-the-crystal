extends GPUParticles2D

func _ready() -> void:
	_configurar_particula()

func _configurar_particula() -> void:
	# Textura del glow, generada por código (sin archivo .png)
	texture = _crear_textura_glow(64)

	# Se posiciona y dimensiona según el tamaño real de la pantalla
	var tam_pantalla: Vector2 = get_viewport_rect().size
	position = tam_pantalla / 2.0

	# Configuración general
	amount = 50
	lifetime = 6.0
	preprocess = 2.0        # ya arrancan partículas visibles, no empieza vacío
	explosiveness = 0.0
	randomness = 0.3
	local_coords = false    # quedan fijas respecto a la pantalla, no al scroll

	# Material de proceso
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

	# Curva de escala: aparece y desaparece suavemente (efecto luciérnaga)
	var curva_escala := Curve.new()
	curva_escala.add_point(Vector2(0.0, 0.0))
	curva_escala.add_point(Vector2(0.2, 1.0))
	curva_escala.add_point(Vector2(0.8, 1.0))
	curva_escala.add_point(Vector2(1.0, 0.0))
	var curva_textura := CurveTexture.new()
	curva_textura.curve = curva_escala
	material.scale_curve = curva_textura

	# Color base: dorado suave (cámbialo aquí si prefieres el azul de los cristales)
	material.color = Color(1.0, 0.85, 0.5, 1.0)

	# Rampa de color: refuerza la aparición/desaparición gradual
	var gradiente := Gradient.new()
	gradiente.set_color(0, Color(1.0, 0.85, 0.5, 0.0))
	gradiente.add_point(0.5, Color(1.0, 0.85, 0.5, 1.0))
	gradiente.set_color(1, Color(1.0, 0.85, 0.5, 0.0))
	var rampa_textura := GradientTexture1D.new()
	rampa_textura.gradient = gradiente
	material.color_ramp = rampa_textura

	process_material = material

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
