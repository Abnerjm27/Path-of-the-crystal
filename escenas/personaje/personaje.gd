class_name Personaje
extends CharacterBody2D

signal dash_iniciado
signal dash_listo
signal personaje_muerto
signal dash_bloqueado
signal vuelo_bloqueado
signal vuelo_iniciado
signal vuelo_terminado

var _velocidad: float = 160.0
var _velocidad_salto: float = -320.0
var _muerto: bool

@export var apariencias: Array[SpriteFrames]
@onready var animacion1 = $animacion
@export var animacion: Node
@export var area_2d: Area2D
@export var material_personaje_rojo = ShaderMaterial

# --- SALTO ---
@export var saltos_maximos: int = 2
@export var multiplicador_segundo_salto: float = 0.80
var _saltos_disponibles: int

# --- DASH ---
@export var velocidad_dash: float = 320.0
@export var duracion_dash: float = 0.12
@export var cooldown_dash: float = 1.0
@export var colores_estela: Array[Color] = [
	Color(0.8, 0.1, 0.1, 0.6),   # Asesino
	Color(0.4, 0.6, 0.2, 0.6),   # Salvaje
	Color(0.3, 0.5, 1.0, 0.6),   # Vikingo
	Color(1.0, 0.85, 0.3, 0.6),  # Valkyrie
	Color(0.6, 0.2, 0.8, 0.6),   # Vidente
]
var _puede_dash := true
var _dashing := false
var _timer_estela: Timer

# --- COOPERATIVO ---
@export var jugador_id: int = 0
@export var esquema_control: String = "teclado"
@export var indice_mando: int = 0

# --- VUELO ---
@export var apariencias_alas: Array[SpriteFrames]
@onready var alas: AnimatedSprite2D = $animacion/alas
@export var velocidad_ascenso_vuelo: float = -210.0
@export var velocidad_descenso_vuelo: float = 50.0
@export var duracion_vuelo_maxima: float = 0.8
@export var offset_alas: Vector2 = Vector2(0, -8)
var _volando := false
var _tiempo_vuelo_restante: float
var _puede_volar := true

# --- PREDICCIÓN Y RECONCILIACIÓN EN RED ---
var _es_red := false
var _es_mio_en_red := true
var _pos_objetivo_red: Vector2
var _anim_objetivo_red := "idle"
var _flip_h_red := false
var _vel_objetivo_red: Vector2
const CAPA_JUGADOR_REMOTO := 1 << 4

# Buffer de Entradas y Ticks de Física
var _current_tick: int = 0
var _input_history: Array = [] # {tick, pos, vel}

var _tiempo_acumulado_red: float = 0.0
const INTERVALO_ENVIO_RED: float = 0.033 # ~30 Hz
var _ultima_pos_enviada: Vector2 = Vector2.ZERO

var _indice_personaje_propio: int = 0


func _ready():
	_indice_personaje_propio = ControladorGlobal.personaje_seleccionado if jugador_id == 0 else ControladorGlobal.personaje_seleccionado_jugador2
	animacion1.sprite_frames = apariencias[_indice_personaje_propio]
	animacion.play("idle")
	animacion.sprite_frames = apariencias[_indice_personaje_propio]
	area_2d.body_entered.connect(_on_area_2d_body_entered)
	add_to_group("personajes")

	_saltos_disponibles = saltos_maximos
	_tiempo_vuelo_restante = duracion_vuelo_maxima

	if apariencias_alas.size() > _indice_personaje_propio:
		alas.sprite_frames = apariencias_alas[_indice_personaje_propio]
	alas.visible = false
	alas.position = offset_alas
	alas.z_index = -1

	_timer_estela = Timer.new()
	_timer_estela.wait_time = 0.03
	_timer_estela.timeout.connect(_crear_estela)
	add_child(_timer_estela)

	if ControladorGlobal.es_partida_en_red:
		_es_red = true
		var mi_rol_esperado := 0 if ControladorGlobal.mi_id_jugador_red == 1 else 1
		_es_mio_en_red = (jugador_id == mi_rol_esperado)
		
		if not _es_mio_en_red:
			collision_layer = CAPA_JUGADOR_REMOTO
			collision_mask = 1 # Colisiona con el escenario
			area_2d.monitoring = false
			area_2d.monitorable = false
			NetworkDiscovery.posicion_remota_recibida.connect(_on_posicion_remota_recibida)
			NetworkDiscovery.muerte_remota_recibida.connect(_on_muerte_remota_recibida)
			NetworkDiscovery.evento_animacion_recibido.connect(_on_evento_animacion_remoto)
			_pos_objetivo_red = global_position
		else:
			NetworkDiscovery.confirmacion_host_recibida.connect(_on_confirmacion_host_recibida)

	if _es_red or not ControladorGlobal.modo_cooperativo_activo:
		Input.joy_connection_changed.connect(_on_joy_connection_changed)

	if not NetworkDiscovery.rebote_jugador_recibido.is_connected(_on_rebote_jugador_recibido):
		NetworkDiscovery.rebote_jugador_recibido.connect(_on_rebote_jugador_recibido)


func es_mio_localmente() -> bool:
	return _es_mio_en_red if _es_red else true


func obtener_estado_red_crudo() -> Dictionary:
	# Último estado recibido por RPC (rpc_posicion), sin el suavizado visual del
	# lerp de renderizado remoto. El host usa esto para validar al cliente en vez
	# de leer global_position, que siempre va un poco "atrás" de este valor.
	return {"pos": _pos_objetivo_red, "vel": _vel_objetivo_red}


func _nombre_accion(base: String) -> String:
	if esquema_control == "mando":
		var prefijo = "mando1" if jugador_id == 0 else "mando2"
		return "%s_%s" % [prefijo, base]
	if _es_red:
		return base
	return base if jugador_id == 0 else "p2_%s" % base

func _leer_izquierda() -> bool: return Input.is_action_pressed(_nombre_accion("izquierda"))
func _leer_derecha() -> bool: return Input.is_action_pressed(_nombre_accion("derecha"))
func _leer_saltar_recien_presionado() -> bool: return Input.is_action_just_pressed(_nombre_accion("saltar"))
func _leer_dash_recien_presionado() -> bool: return Input.is_action_just_pressed(_nombre_accion("dash"))
func _leer_volar_presionado() -> bool: return Input.is_action_pressed(_nombre_accion("volar"))
func _leer_volar_recien_presionado() -> bool: return Input.is_action_just_pressed(_nombre_accion("volar"))


# --- DETECCIÓN DE REBOTES Y CHOQUES ENTRE JUGADORES ---
func _on_rebote_jugador_recibido(id_afectado: int) -> void:
	if id_afectado != jugador_id or not es_mio_localmente():
		return
	velocity.y = -220.0


func _comprobar_choque_sobre_otro_jugador() -> void:
	if not is_on_floor() and velocity.y > 0:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var col_node := col.get_collider() as Node2D
			if col_node and col_node.is_in_group("personajes") and col_node != self:
				if global_position.y < col_node.global_position.y - 10.0:
					velocity.y = _velocidad_salto * 0.7
					NetworkDiscovery.enviar_rebote_jugador(col_node.jugador_id)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not es_mio_localmente():
		return

	if connected:
		if esquema_control != "mando":
			esquema_control = "mando"
			indice_mando = device
			var prefijo := "mando1" if jugador_id == 0 else "mando2"
			ControladorGlobal.configurar_input_map_mando(prefijo, device)
	else:
		if esquema_control == "mando" and indice_mando == device:
			esquema_control = "teclado"


func _on_posicion_remota_recibida(_id_emisor: int, pos: Vector2, vel: Vector2, animacion_nombre: String, flip_h: bool) -> void:
	if _es_mio_en_red:
		return
	_pos_objetivo_red = pos
	_vel_objetivo_red = vel
	_anim_objetivo_red = animacion_nombre
	_flip_h_red = flip_h


# --- RECONCILIACIÓN OPTIMIZADA PARA COOPERATIVO ---
func _on_confirmacion_host_recibida(server_tick: int, pos_valida: Vector2, _vel_valida: Vector2) -> void:
	if not _es_mio_en_red or _es_host_local():
		return

	# Buscamos la posición que NOSOTROS predijimos en ese mismo tick, para comparar
	# manzanas con manzanas (en vez de comparar contra la posición ACTUAL, que ya
	# avanzó lo que dure el viaje de ida y vuelta al host).
	var pos_predicha: Vector2
	var encontrada := false
	for entrada in _input_history:
		if entrada["tick"] == server_tick:
			pos_predicha = entrada["pos"]
			encontrada = true
			break

	# Descartar ticks ya procesados por el servidor
	while _input_history.size() > 0 and _input_history[0]["tick"] <= server_tick:
		_input_history.pop_front()

	if not encontrada:
		return  # ya no tenemos ese tick en el historial, no hay con qué comparar

	# Solo corregimos si hay una desincronización real (ej. el host te empujó o moriste).
	# Aplicamos el error como un desplazamiento sobre la posición ACTUAL, no saltamos
	# a la posición vieja que reporta el host.
	var error := pos_predicha.distance_to(pos_valida)
	if error > 50.0:
		var offset := pos_valida - pos_predicha
		global_position = global_position.lerp(global_position + offset, 0.3)


func _es_host_local() -> bool:
	return NetworkDiscovery.soy_host()


func _on_muerte_remota_recibida(_id_emisor: int) -> void:
	if _es_mio_en_red:
		return
	_ejecutar_muerte_visual()


func _on_evento_animacion_remoto(evento: String) -> void:
	if _es_mio_en_red:
		return
	match evento:
		"dash":
			_iniciar_dash_visual()
		"doble_salto":
			_efecto_doble_salto()


# --- FÍSICA Y PREDICCIÓN LOCAL EN TIEMPO REAL ---
func _physics_process(delta: float) -> void:
	if _muerto:
		return

	# --- RENDERIZADO REMOTO SUAVE ---
	if _es_red and not _es_mio_en_red:
		global_position = global_position.lerp(_pos_objetivo_red, 25.0 * delta)
		velocity = _vel_objetivo_red
		animacion.flip_h = _flip_h_red
		
		if animacion.sprite_frames and animacion.sprite_frames.has_animation(_anim_objetivo_red):
			animacion.play(_anim_objetivo_red)
		_actualizar_visual_alas(_anim_objetivo_red == "volar")
		return

	# --- PREDICCIÓN LOCAL EN TIEMPO REAL ---
	_current_tick += 1

	if _dashing:
		move_and_slide()
		if _es_red and _es_mio_en_red:
			_input_history.append({"tick": _current_tick, "pos": global_position, "vel": velocity})
		_transmitir_posicion_red(delta)
		return

	if is_on_floor():
		_puede_volar = true
		_tiempo_vuelo_restante = duracion_vuelo_maxima
		if _volando:
			_volando = false
			vuelo_terminado.emit()
		_saltos_disponibles = saltos_maximos if ControladorGlobal.doble_salto_desbloqueado() else 1

	if not is_on_floor() and _leer_volar_recien_presionado() and not ControladorGlobal.vuelo_desbloqueado():
		vuelo_bloqueado.emit()

	var intenta_volar := ControladorGlobal.vuelo_desbloqueado() and _leer_volar_presionado() and not is_on_floor()

	if intenta_volar and (_volando or _puede_volar) and _tiempo_vuelo_restante > 0.0:
		if not _volando:
			_volando = true
			vuelo_iniciado.emit()
		_tiempo_vuelo_restante -= delta
		velocity.y = velocidad_ascenso_vuelo if _leer_volar_presionado() else velocidad_descenso_vuelo
		if _tiempo_vuelo_restante <= 0.0:
			_puede_volar = false
			_volando = false
			vuelo_terminado.emit()
	else:
		if _volando:
			_volando = false
			vuelo_terminado.emit()
		velocity += get_gravity() * delta

	if _leer_dash_recien_presionado() and _puede_dash:
		if ControladorGlobal.dash_desbloqueado():
			_iniciar_dash()
			return
		else:
			dash_bloqueado.emit()

	if not _volando and _leer_saltar_recien_presionado() and _saltos_disponibles > 0:
		var saltos_maximos_efectivos := saltos_maximos if ControladorGlobal.doble_salto_desbloqueado() else 1
		var era_doble_salto = not is_on_floor() and _saltos_disponibles < saltos_maximos_efectivos

		if era_doble_salto:
			velocity.y = _velocidad_salto * multiplicador_segundo_salto
		else:
			velocity.y = _velocidad_salto

		_saltos_disponibles -= 1
		if era_doble_salto:
			_efecto_doble_salto()
			if _es_red and _es_mio_en_red:
				NetworkDiscovery.enviar_evento_animacion("doble_salto")

	if _leer_derecha():
		velocity.x = _velocidad
		animacion.flip_h = false
	elif _leer_izquierda():
		velocity.x = -_velocidad
		animacion.flip_h = true
	else:
		velocity.x = 0

	move_and_slide()
	_comprobar_choque_sobre_otro_jugador()

	if _volando:
		animacion.play("saltar")
	elif !is_on_floor():
		animacion.play("saltar")
	elif velocity.x != 0:
		animacion.play("correr")
	else:
		animacion.play("idle")

	_actualizar_visual_alas(_volando)

	if _es_red and _es_mio_en_red:
		_input_history.append({"tick": _current_tick, "pos": global_position, "vel": velocity})
		_transmitir_posicion_red(delta)


func _transmitir_posicion_red(delta: float) -> void:
	if not (_es_red and _es_mio_en_red):
		return

	_tiempo_acumulado_red += delta
	if _tiempo_acumulado_red >= INTERVALO_ENVIO_RED:
		_tiempo_acumulado_red = 0.0
		if global_position.distance_squared_to(_ultima_pos_enviada) > 0.05 or velocity != Vector2.ZERO:
			_ultima_pos_enviada = global_position
			NetworkDiscovery.enviar_posicion(global_position, velocity, animacion.animation, animacion.flip_h)
			if not _es_host_local():
				NetworkDiscovery.enviar_estado_predicho(_current_tick, global_position, velocity)


func _actualizar_visual_alas(mostrar: bool) -> void:
	alas.flip_h = animacion.flip_h
	if mostrar:
		if not alas.visible:
			alas.visible = true
		if alas.sprite_frames and alas.sprite_frames.has_animation("volar") and alas.animation != "volar":
			alas.play("volar")
		elif not alas.is_playing():
			alas.play("volar")
	else:
		if alas.visible:
			alas.visible = false
			alas.stop()


func _efecto_doble_salto():
	var particulas = CPUParticles2D.new()
	particulas.global_position = animacion.global_position
	particulas.z_index = z_index
	particulas.z_as_relative = z_as_relative
	get_parent().add_child(particulas)

	particulas.emitting = true
	particulas.one_shot = true
	particulas.amount = 12
	particulas.lifetime = 0.4
	particulas.explosiveness = 1.0
	particulas.direction = Vector2(0, -1)
	particulas.spread = 180
	particulas.initial_velocity_min = 40
	particulas.initial_velocity_max = 80
	particulas.gravity = Vector2(0, 200)
	particulas.scale_amount_min = 2
	particulas.scale_amount_max = 4
	particulas.color = colores_estela[_indice_personaje_propio]

	await get_tree().create_timer(0.6).timeout
	particulas.queue_free()


func _iniciar_dash():
	_dashing = true
	_puede_dash = false
	dash_iniciado.emit(cooldown_dash)

	if _es_red and _es_mio_en_red:
		NetworkDiscovery.enviar_evento_animacion("dash")

	var direccion := -1.0 if animacion.flip_h else 1.0
	velocity = Vector2(direccion * velocidad_dash, 0)

	_timer_estela.start()

	await get_tree().create_timer(duracion_dash).timeout
	_dashing = false
	_timer_estela.stop()

	await get_tree().create_timer(cooldown_dash - duracion_dash).timeout
	_puede_dash = true
	dash_listo.emit()


func _iniciar_dash_visual() -> void:
	_timer_estela.start()
	await get_tree().create_timer(duracion_dash).timeout
	_timer_estela.stop()


func _crear_estela():
	if not animacion.sprite_frames:
		return

	var textura = animacion.sprite_frames.get_frame_texture(animacion.animation, animacion.frame)
	if not textura:
		return

	var color_personaje = colores_estela[_indice_personaje_propio]

	var estela = Sprite2D.new()
	estela.texture = textura
	estela.global_transform = animacion.global_transform
	estela.flip_h = animacion.flip_h
	estela.z_index = z_index
	estela.z_as_relative = z_as_relative
	get_parent().add_child(estela)

	estela.modulate = Color(1, 1, 1, 0.8)
	var tween = estela.create_tween()
	tween.tween_property(estela, "modulate", color_personaje, 0.1)
	tween.tween_property(estela, "modulate:a", 0.0, 0.2)
	tween.tween_callback(estela.queue_free)


func _on_area_2d_body_entered(_body: Node2D) -> void:
	if _muerto or (_es_red and not _es_mio_en_red):
		return
	_ejecutar_muerte_local()


func morir():
	if _muerto or (_es_red and not _es_mio_en_red):
		return
	_ejecutar_muerte_local()


func _ejecutar_muerte_local() -> void:
	animacion.material = material_personaje_rojo
	_muerto = true
	animacion.stop()
	alas.visible = false
	alas.stop()

	if _es_red and _es_mio_en_red:
		NetworkDiscovery.enviar_muerte()

	await get_tree().create_timer(0.5).timeout
	personaje_muerto.emit()
	ControladorGlobal.sumar_muerte()


func _ejecutar_muerte_visual() -> void:
	if _muerto:
		return
	animacion.material = material_personaje_rojo
	_muerto = true
	animacion.stop()
	alas.visible = false
	alas.stop()
