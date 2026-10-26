class_name VisualPersonaje
extends RefCounted

var _personaje: CharacterBody2D
var _animacion: AnimatedSprite2D
var _alas: AnimatedSprite2D
var _pool_estelas: PoolObjetos
var _indice_personaje := 0
var _colores_estela: Array[Color]


func inicializar(personaje: CharacterBody2D, animacion: AnimatedSprite2D, alas: AnimatedSprite2D,
		indice: int, colores: Array[Color]) -> void:
	_personaje = personaje
	_animacion = animacion
	_alas = alas
	_indice_personaje = indice
	_colores_estela = colores

	# Creamos un template de estela (Sprite2D sin padre) que el pool clonará.
	var escena_estela := PackedScene.new()
	var sprite := Sprite2D.new()
	sprite.name = "EstelaTemplate"
	escena_estela.pack(sprite)

	# El pool NO se pre-popula en _init(); se llena perezosamente cuando se
	# pide la primera estela. Después podemos pre-calentar de forma diferida.
	_pool_estelas = PoolObjetos.new(escena_estela, personaje.get_parent(), 0, 40)
	_pool_estelas.pre_calentar_diferido(8)


func actualizar_alas(mostrar: bool) -> void:
	if not _alas:
		return
	_alas.flip_h = _animacion.flip_h
	if mostrar:
		if not _alas.visible:
			_alas.visible = true
		if _alas.sprite_frames and _alas.sprite_frames.has_animation("volar"):
			if _alas.animation != "volar" or not _alas.is_playing():
				_alas.play("volar")
	else:
		if _alas.visible:
			_alas.visible = false
			_alas.stop()


func crear_estela() -> void:
	if not _animacion.sprite_frames:
		return
	var textura = _animacion.sprite_frames.get_frame_texture(_animacion.animation, _animacion.frame)
	if not textura:
		return

	var estela := _pool_estelas.obtener() as Sprite2D
	estela.texture = textura
	estela.global_position = _animacion.global_position
	estela.flip_h = _animacion.flip_h
	estela.z_index = _personaje.z_index
	estela.z_as_relative = _personaje.z_as_relative
	estela.modulate = Color(1, 1, 1, 0.8)

	var color_personaje = _colores_estela[_indice_personaje]
	var tween := estela.create_tween()
	tween.tween_property(estela, "modulate", color_personaje, 0.1)
	tween.tween_property(estela, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_pool_estelas.devolver.bind(estela))


var _particulas_doble_salto: CPUParticles2D = null

func efecto_doble_salto() -> void:
	# Reutilizar el nodo de partículas si ya existe (evita GC pressure)
	if not is_instance_valid(_particulas_doble_salto):
		_particulas_doble_salto = CPUParticles2D.new()
		_particulas_doble_salto.one_shot = true
		_particulas_doble_salto.amount = 12
		_particulas_doble_salto.lifetime = 0.4
		_particulas_doble_salto.explosiveness = 1.0
		_particulas_doble_salto.direction = Vector2(0, -1)
		_particulas_doble_salto.spread = 180
		_particulas_doble_salto.initial_velocity_min = 40
		_particulas_doble_salto.initial_velocity_max = 80
		_particulas_doble_salto.gravity = Vector2(0, 200)
		_particulas_doble_salto.scale_amount_min = 2
		_particulas_doble_salto.scale_amount_max = 4
		_personaje.get_parent().add_child(_particulas_doble_salto)
	_particulas_doble_salto.color = _colores_estela[_indice_personaje]
	_particulas_doble_salto.z_index = _personaje.z_index
	_particulas_doble_salto.z_as_relative = _personaje.z_as_relative
	_particulas_doble_salto.global_position = _animacion.global_position
	_particulas_doble_salto.restart()
