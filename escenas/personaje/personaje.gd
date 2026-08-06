class_name Personaje
extends CharacterBody2D
signal dash_iniciado
signal dash_listo
signal personaje_muerto
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
@export var multiplicador_segundo_salto: float = 0.75
var _saltos_disponibles: int

# --- DASH ---
@export var velocidad_dash: float = 320.0
@export var duracion_dash: float = 0.12
@export var cooldown_dash: float = 1.0
@export var colores_estela: Array[Color] = [
	Color(0.8, 0.1, 0.1, 0.6),   # Asesino - rojo sangre
	Color(0.4, 0.6, 0.2, 0.6),   # Salvaje - verde selva
	Color(0.3, 0.5, 1.0, 0.6),   # Vikingo - azul hielo
	Color(1.0, 0.85, 0.3, 0.6),  # Valkyrie - dorado
	Color(0.6, 0.2, 0.8, 0.6),   # Vidente - morado místico
]
var _puede_dash := true
var _dashing := false
var _timer_estela: Timer
signal dash_bloqueado
# --- COOPERATIVO: identidad y esquema de control de este personaje ---
@export var jugador_id: int = 0          # 0 = Jugador 1, 1 = Jugador 2
@export var esquema_control: String = "teclado"   # "teclado" o "mando"
@export var indice_mando: int = 0

# --- NUEVO: cooperativo EN RED ---
var _es_red := false            # true si esta partida es en red (host+cliente)
var _es_mio_en_red := true       # true si ESTE peer controla este personaje localmente
var _pos_objetivo_red: Vector2
var _anim_objetivo_red := "idle"
var _flip_h_red := false
const CAPA_JUGADOR_REMOTO := 1 << 4  # Layer 5: "jugador_remoto"
var _vel_objetivo_red: Vector2
func _nombre_accion(base: String) -> String:
	if esquema_control == "mando":
		var prefijo = "mando1" if jugador_id == 0 else "mando2"
		return "%s_%s" % [prefijo, base]
	if _es_red:
		# En red cada jugador tiene su propio teclado completo: sin prefijo p2_
		return base
	return base if jugador_id == 0 else "p2_%s" % base

func _leer_izquierda() -> bool:
	return Input.is_action_pressed(_nombre_accion("izquierda"))

func _leer_derecha() -> bool:
	return Input.is_action_pressed(_nombre_accion("derecha"))

func _leer_saltar_recien_presionado() -> bool:
	return Input.is_action_just_pressed(_nombre_accion("saltar"))

func _leer_dash_recien_presionado() -> bool:
	return Input.is_action_just_pressed(_nombre_accion("dash"))

# NUEVO: true si este nodo es controlado localmente por ESTE peer
# (siempre true fuera de red; en red, solo true para el muñeco propio)
func es_mio_localmente() -> bool:
	if not _es_red:
		return true
	return _es_mio_en_red

var _indice_personaje_propio: int = 0

func _ready():
	_indice_personaje_propio = ControladorGlobal.personaje_seleccionado if jugador_id == 0 else ControladorGlobal.personaje_seleccionado_jugador2
	animacion1.sprite_frames = apariencias[_indice_personaje_propio]
	animacion.play("idle")
	animacion.sprite_frames = apariencias[_indice_personaje_propio]
	area_2d.body_entered.connect(_on_area_2d_body_entered)
	add_to_group("personajes")

	_saltos_disponibles = saltos_maximos

	_timer_estela = Timer.new()
	_timer_estela.wait_time = 0.03
	_timer_estela.timeout.connect(_crear_estela)
	add_child(_timer_estela)

	# --- NUEVO: configuración de red ---
	if ControladorGlobal.es_partida_en_red:
		_es_red = true
		var mi_rol_esperado := 0 if ControladorGlobal.mi_id_jugador_red == 1 else 1
		_es_mio_en_red = (jugador_id == mi_rol_esperado)
		if not _es_mio_en_red:
			collision_layer = CAPA_JUGADOR_REMOTO  # antes era 0: ahora detectable por enemigos
			collision_mask = 0
			area_2d.monitoring = false
			area_2d.monitorable = false
			NetworkDiscovery.posicion_remota_recibida.connect(_on_posicion_remota_recibida)
			NetworkDiscovery.muerte_remota_recibida.connect(_on_muerte_remota_recibida)
			NetworkDiscovery.evento_animacion_recibido.connect(_on_evento_animacion_remoto)  # NUEVO
			_pos_objetivo_red = global_position
	if _es_red or not ControladorGlobal.modo_cooperativo_activo:
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if not NetworkDiscovery.rebote_jugador_recibido.is_connected(_on_rebote_jugador_recibido):
		NetworkDiscovery.rebote_jugador_recibido.connect(_on_rebote_jugador_recibido)
func _on_rebote_jugador_recibido(id_afectado: int) -> void:
	if id_afectado != jugador_id:
		return
	if not es_mio_localmente():
		return
	velocity.y = -200
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not es_mio_localmente():
		return  # esto es el muñeco del OTRO jugador en red, no reacciona

	if connected:
		if esquema_control != "mando":
			esquema_control = "mando"
			indice_mando = device
			var prefijo := "mando1" if jugador_id == 0 else "mando2"
			ControladorGlobal.configurar_input_map_mando(prefijo, device)
			print("Mando conectado en pleno juego (dispositivo ", device, "), cambiando a control por mando")
	else:
		if esquema_control == "mando" and indice_mando == device:
			esquema_control = "teclado"
			print("Mando desconectado, volviendo a teclado")

func _on_posicion_remota_recibida(_id_emisor: int, pos: Vector2, vel: Vector2, animacion_nombre: String, flip_h: bool) -> void:
	if _es_mio_en_red:
		return
	_pos_objetivo_red = pos
	_vel_objetivo_red = vel   # antes era _vel y se descartaba
	_anim_objetivo_red = animacion_nombre
	_flip_h_red = flip_h
# NUEVO: recibe el aviso de que el jugador real (dueño de este muñeco) murió
func _on_muerte_remota_recibida(_id_emisor: int) -> void:
	if _es_mio_en_red:
		return
	_ejecutar_muerte_visual()

# NUEVO: recibe eventos puntuales (dash / doble salto) del jugador remoto
func _on_evento_animacion_remoto(evento: String) -> void:
	if _es_mio_en_red:
		return
	match evento:
		"dash":
			_iniciar_dash_visual()
		"doble_salto":
			_efecto_doble_salto()
func _physics_process(delta):
	if _muerto:
		return

	# --- NUEVO: si este nodo es el jugador REMOTO, no procesamos input ni física local ---
	if _es_red and not _es_mio_en_red:
		global_position = global_position.lerp(_pos_objetivo_red, 0.35)
		velocity = _vel_objetivo_red   # NUEVO: refleja la velocidad real (caída, salto, etc.)
		animacion.flip_h = _flip_h_red
		if animacion.sprite_frames and animacion.sprite_frames.has_animation(_anim_objetivo_red):
			animacion.play(_anim_objetivo_red)
		return

	if _dashing:
		move_and_slide()
		if _es_red:
			NetworkDiscovery.enviar_posicion(global_position, velocity, animacion.animation, animacion.flip_h)
		return

	velocity += get_gravity() * delta

	if is_on_floor():
		# NUEVO: si el doble salto todavía no se desbloqueó, se limita a 1 salto
		_saltos_disponibles = saltos_maximos if ControladorGlobal.doble_salto_desbloqueado() else 1
	if _leer_dash_recien_presionado() and _puede_dash:
		if ControladorGlobal.dash_desbloqueado():
			_iniciar_dash()
			return
		else:
			dash_bloqueado.emit()  # NUEVO: avisa a la UI que intentaron usarlo bloqueado
	if _leer_saltar_recien_presionado() and _saltos_disponibles > 0:
		# NUEVO: tope efectivo de saltos según si el doble salto está desbloqueado
		var saltos_maximos_efectivos := saltos_maximos if ControladorGlobal.doble_salto_desbloqueado() else 1
		var era_doble_salto = not is_on_floor() and _saltos_disponibles < saltos_maximos_efectivos

		if era_doble_salto:
			velocity.y = _velocidad_salto * multiplicador_segundo_salto
		else:
			velocity.y = _velocidad_salto

		_saltos_disponibles -= 1
		if era_doble_salto:
			_efecto_doble_salto()
			if _es_red and _es_mio_en_red:  # NUEVO: avisar al otro peer
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

	if !is_on_floor():
		animacion.play("saltar")
	elif velocity.x != 0:
		animacion.play("correr")
	else:
		animacion.play("idle")

	# --- NUEVO: si soy mi propio jugador en red, envío mi estado al otro peer ---
	if _es_red and _es_mio_en_red:
		NetworkDiscovery.enviar_posicion(global_position, velocity, animacion.animation, animacion.flip_h)
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

	if _es_red and _es_mio_en_red:  # NUEVO: avisar al otro peer
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

# NUEVO: versión puramente visual del dash para el muñeco remoto.
# No toca velocity ni posición (eso ya lo maneja el lerp hacia _pos_objetivo_red),
# solo activa la estela durante la misma duración que el dash real.
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
	if _muerto:
		return
	# NUEVO: el muñeco remoto no debería poder llegar aquí (ya no monitorea
	# colisiones), pero por seguridad, si alguna vez pasa, no dejamos que
	# se auto-declare muerto: solo el dueño local decide su propia muerte.
	if _es_red and not _es_mio_en_red:
		return
	_ejecutar_muerte_local()

func morir():
	if _muerto:
		return
	if _es_red and not _es_mio_en_red:
		return
	_ejecutar_muerte_local()

# NUEVO: muerte decidida localmente por el dueño real del personaje.
# Reproduce la animación, emite las señales locales y, si es partida en
# red, avisa al otro peer para que también reaccione.
func _ejecutar_muerte_local() -> void:
	animacion.material = material_personaje_rojo
	_muerto = true
	animacion.stop()

	if _es_red and _es_mio_en_red:
		NetworkDiscovery.enviar_muerte()   # NUEVO: avisar de inmediato, no después del timer

	await get_tree().create_timer(0.5).timeout
	personaje_muerto.emit()
	ControladorGlobal.sumar_muerte()
# NUEVO: reproduce solo la animación/estado de muerte, sin volver a avisar
# por RPC ni sumar muerte otra vez. Se usa en el muñeco remoto cuando le
# llega el aviso de que el jugador real murió.
func _ejecutar_muerte_visual() -> void:
	if _muerto:
		return
	animacion.material = material_personaje_rojo
	_muerto = true
	animacion.stop()
