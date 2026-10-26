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
var _muerto: bool = false
var _indice_personaje_propio: int = 0

@export var apariencias: Array[SpriteFrames]
@onready var animacion1: AnimatedSprite2D = $animacion
@export var animacion: AnimatedSprite2D
@export var area_2d: Area2D
@export var material_personaje_rojo: ShaderMaterial

@export var saltos_maximos: int = 2
@export var multiplicador_segundo_salto: float = 0.80
var _saltos_disponibles: int

@export var velocidad_dash: float = 320.0
@export var duracion_dash: float = 0.12
@export var cooldown_dash: float = 1.0
@export var colores_estela: Array[Color] = [
	Color(0.8, 0.1, 0.1, 0.6),
	Color(0.4, 0.6, 0.2, 0.6),
	Color(0.3, 0.5, 1.0, 0.6),
	Color(1.0, 0.85, 0.3, 0.6),
	Color(0.6, 0.2, 0.8, 0.6),
]
var _puede_dash := true
var _dashing := false
var _timer_estela: Timer

@export var jugador_id: int = 0
@export var esquema_control: String = "teclado"
@export var indice_mando: int = 0

@export var apariencias_alas: Array[SpriteFrames]
@onready var alas: AnimatedSprite2D = $animacion/alas
@export var velocidad_ascenso_vuelo: float = -210.0
@export var velocidad_descenso_vuelo: float = 50.0
@export var duracion_vuelo_maxima: float = 0.8
@export var offset_alas: Vector2 = Vector2(0, -8)
var _volando := false
var _tiempo_vuelo_restante: float
var _puede_volar := true

const CAPA_SOLIDOS := 1
const CAPA_DANO := 1 << 1
const CAPA_JUGADOR := 1 << 2
const CAPA_RECOLECTABLES := 1 << 3
const CAPA_JUGADOR_REMOTO := 1 << 4

var _red: RedPersonaje
var _visual: VisualPersonaje
var _acciones: Dictionary = {}

var _area_pies: Area2D


func _ready() -> void:
	_indice_personaje_propio = ControladorGlobal.personaje_seleccionado if jugador_id == 0 else ControladorGlobal.personaje_seleccionado_jugador2
	animacion1.sprite_frames = apariencias[_indice_personaje_propio]
	animacion.sprite_frames = apariencias[_indice_personaje_propio]
	animacion.play("idle")
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

	_actualizar_mapa_acciones()

	_red = RedPersonaje.new()
	_red.inicializar(self)

	_visual = VisualPersonaje.new()
	_visual.inicializar(self, animacion1, alas, _indice_personaje_propio, colores_estela)

	if _red.es_remoto():
		# 4a: El muñeco remoto no simula física ni colisiona con el mundo
		collision_layer = CAPA_JUGADOR_REMOTO
		collision_mask = 0
		if ControladorGlobal.es_partida_en_red and NetworkDiscovery.soy_host() and is_instance_valid(area_2d):
			# El host sí monitorea al jugador remoto para calcular si fue golpeado por daños
			area_2d.monitoring = true
			area_2d.monitorable = false
			area_2d.collision_layer = CAPA_JUGADOR_REMOTO
			area_2d.collision_mask = CAPA_DANO
		else:
			area_2d.monitoring = false
			area_2d.monitorable = false
		NetworkDiscovery.posicion_remota_recibida.connect(_on_posicion_remota_recibida)
		NetworkDiscovery.muerte_remota_recibida.connect(_on_muerte_remota_recibida)
		NetworkDiscovery.evento_animacion_recibido.connect(_on_evento_animacion_remoto)
	else:
		collision_layer = CAPA_JUGADOR
		collision_mask = CAPA_SOLIDOS
		if ControladorGlobal.modo_cooperativo_activo and not ControladorGlobal.es_partida_en_red:
			collision_mask |= CAPA_JUGADOR
		if is_instance_valid(area_2d):
			area_2d.monitoring = true
			area_2d.monitorable = true
			area_2d.collision_layer = CAPA_JUGADOR
			area_2d.collision_mask = CAPA_DANO
		# 4c: Área para detectar pisotón sobre el otro jugador sin bloquear el paso
		_crear_area_pies()
		if _red.es_red() and _red.es_mio():
			NetworkDiscovery.muerte_forzada_recibida.connect(_on_muerte_forzada_recibida)

	if _red.es_red() or not ControladorGlobal.modo_cooperativo_activo:
		Input.joy_connection_changed.connect(_on_joy_connection_changed)

	if not NetworkDiscovery.rebote_jugador_recibido.is_connected(_on_rebote_jugador_recibido):
		NetworkDiscovery.rebote_jugador_recibido.connect(_on_rebote_jugador_recibido)


func _crear_area_pies() -> void:
	_area_pies = Area2D.new()
	_area_pies.name = "AreaPies"
	_area_pies.collision_layer = 0
	_area_pies.collision_mask = CAPA_JUGADOR | CAPA_JUGADOR_REMOTO
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 6)
	forma.shape = rect
	forma.position = Vector2(0, 10)
	_area_pies.add_child(forma)
	add_child(_area_pies)


func _actualizar_mapa_acciones() -> void:
	var prefijo: String = ""
	if esquema_control == "mando":
		prefijo = "mando1_" if jugador_id == 0 else "mando2_"
	elif ControladorGlobal.modo_cooperativo_activo and not ControladorGlobal.es_partida_en_red:
		prefijo = "" if jugador_id == 0 else "p2_"

	_acciones = {
		"izquierda": prefijo + "izquierda",
		"derecha": prefijo + "derecha",
		"saltar": prefijo + "saltar",
		"dash": prefijo + "dash",
		"volar": prefijo + "volar",
	}


func _leer_izquierda() -> bool: return Input.is_action_pressed(_acciones["izquierda"])
func _leer_derecha() -> bool: return Input.is_action_pressed(_acciones["derecha"])
func _leer_saltar_recien_presionado() -> bool: return Input.is_action_just_pressed(_acciones["saltar"])
func _leer_dash_recien_presionado() -> bool: return Input.is_action_just_pressed(_acciones["dash"])
func _leer_volar_presionado() -> bool: return Input.is_action_pressed(_acciones["volar"])
func _leer_volar_recien_presionado() -> bool: return Input.is_action_just_pressed(_acciones["volar"])


func _capturar_input() -> InputPersonaje:
	var i: InputPersonaje = InputPersonaje.new()
	i.izquierda = _leer_izquierda()
	i.derecha = _leer_derecha()
	i.saltar = _leer_saltar_recien_presionado()
	i.dash = _leer_dash_recien_presionado()
	i.volar_pressed = _leer_volar_presionado()
	i.volar_just = _leer_volar_recien_presionado()
	return i


func es_mio_localmente() -> bool:
	return _red.es_mio() if _red else true


func _on_rebote_jugador_recibido(id_afectado: int) -> void:
	if id_afectado != jugador_id or not es_mio_localmente():
		return
	velocity.y = -220.0


func _comprobar_pisoton() -> void:
	if _muerto or not es_mio_localmente() or _area_pies == null:
		return
	if velocity.y <= 0:
		return
	for cuerpo in _area_pies.get_overlapping_bodies():
		if cuerpo == self or not cuerpo.is_in_group("personajes"):
			continue
		if global_position.y >= cuerpo.global_position.y - 10.0:
			continue
		velocity.y = _velocidad_salto * 0.7
		NetworkDiscovery.enviar_rebote_jugador(cuerpo.jugador_id)
		return


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not es_mio_localmente():
		return
	if connected:
		if esquema_control != "mando":
			esquema_control = "mando"
			indice_mando = device
			var prefijo: String = "mando1" if jugador_id == 0 else "mando2"
			ControladorGlobal.configurar_input_map_mando(prefijo, device)
			_actualizar_mapa_acciones()
	else:
		if esquema_control == "mando" and indice_mando == device:
			esquema_control = "teclado"
			_actualizar_mapa_acciones()


func _jugador_de_emisor(id: int) -> int:
	return 0 if id == 1 else 1   # host -> jugador_id 0, cliente -> jugador_id 1


func _on_posicion_remota_recibida(id: int, t_red: float, pos: Vector2, anim: String, flip: bool) -> void:
	if not _red.es_remoto():
		return
	if _jugador_de_emisor(id) != jugador_id:
		return
	_red.recibir_posicion(t_red, pos, anim, flip)


func _on_muerte_remota_recibida(id: int) -> void:
	if not _red.es_remoto():
		return
	if _jugador_de_emisor(id) != jugador_id:
		return
	_ejecutar_muerte_visual()


func _on_muerte_forzada_recibida(id_obj: int) -> void:
	if not _red.es_remoto() and jugador_id == id_obj:
		morir()


func _on_evento_animacion_remoto(evento: String) -> void:
	if _red.es_mio():
		return
	match evento:
		"dash": _iniciar_dash_visual()
		"doble_salto": _visual.efecto_doble_salto()


# ═════════════════════════════════════════════════════════════
#  FÍSICA
# ═════════════════════════════════════════════════════════════
func _physics_process(delta: float) -> void:
	if _muerto:
		return

	# Jugador remoto: renderizar con suavizado visual
	if _red.es_remoto():
		var estado: Dictionary = _red.calcular_posicion_render()
		
		# Asignar directamente (la interpolación ya ocurre en calcular_posicion_render)
		global_position = estado["pos"]

		var anim_remota: String = estado["anim"]
		if animacion.sprite_frames and animacion.sprite_frames.has_animation(anim_remota):
			animacion.play(anim_remota)
		animacion.flip_h = estado["flip"]
		_visual.actualizar_alas(anim_remota == "volar")
		return

	# Jugador local
	var input: InputPersonaje = _capturar_input()
	_simular_tick(input, delta)

	if _red.es_red() and _red.es_mio():
		_red.transmitir(delta, animacion.animation, animacion.flip_h)


func _simular_tick(input: InputPersonaje, delta: float) -> void:
	if _muerto:
		return

	if _dashing:
		move_and_slide()
		return

	if is_on_floor():
		_puede_volar = true
		_tiempo_vuelo_restante = duracion_vuelo_maxima
		if _volando:
			_volando = false
			vuelo_terminado.emit()
		_saltos_disponibles = saltos_maximos if ControladorGlobal.doble_salto_desbloqueado() else 1

	if not is_on_floor() and input.volar_just and not ControladorGlobal.vuelo_desbloqueado():
		vuelo_bloqueado.emit()

	var intenta_volar: bool = (
		ControladorGlobal.vuelo_desbloqueado()
		and input.volar_pressed
		and not is_on_floor()
	)

	if intenta_volar and (_volando or _puede_volar) and _tiempo_vuelo_restante > 0.0:
		if not _volando:
			_volando = true
			vuelo_iniciado.emit()
		_tiempo_vuelo_restante -= delta
		velocity.y = velocidad_ascenso_vuelo if input.volar_pressed else velocidad_descenso_vuelo
		if _tiempo_vuelo_restante <= 0.0:
			_puede_volar = false
			_volando = false
			vuelo_terminado.emit()
	else:
		if _volando:
			_volando = false
			vuelo_terminado.emit()
		velocity += get_gravity() * delta

	if input.dash and _puede_dash:
		if ControladorGlobal.dash_desbloqueado():
			_iniciar_dash()
			return
		else:
			dash_bloqueado.emit()

	if not _volando and input.saltar and _saltos_disponibles > 0:
		var max_efectivos: int = saltos_maximos if ControladorGlobal.doble_salto_desbloqueado() else 1
		var era_doble: bool = not is_on_floor() and _saltos_disponibles < max_efectivos
		velocity.y = _velocidad_salto * (multiplicador_segundo_salto if era_doble else 1.0)
		_saltos_disponibles -= 1
		if era_doble:
			_visual.efecto_doble_salto()
			if _red.es_red() and _red.es_mio():
				NetworkDiscovery.enviar_evento_animacion("doble_salto")

	if input.derecha:
		velocity.x = _velocidad
		animacion.flip_h = false
	elif input.izquierda:
		velocity.x = -_velocidad
		animacion.flip_h = true
	else:
		velocity.x = 0

	move_and_slide()

	_comprobar_pisoton()

	var vel_real := get_real_velocity()
	if _volando or not is_on_floor():
		animacion.play("saltar")
	elif absf(vel_real.x) > 20.0: # Umbral mayor para no correr solo por micro-deslizamientos
		animacion.play("correr")
	else:
		animacion.play("idle")

	_visual.actualizar_alas(_volando)


func _iniciar_dash() -> void:
	_dashing = true
	_puede_dash = false
	dash_iniciado.emit(cooldown_dash)

	if _red.es_red() and _red.es_mio():
		NetworkDiscovery.enviar_evento_animacion("dash")

	var direccion: float = -1.0 if animacion.flip_h else 1.0
	velocity = Vector2(direccion * velocidad_dash, 0)
	_timer_estela.start()

	await get_tree().create_timer(duracion_dash).timeout
	if not is_instance_valid(self): return
	_dashing = false
	_timer_estela.stop()

	await get_tree().create_timer(cooldown_dash - duracion_dash).timeout
	if not is_instance_valid(self): return
	_puede_dash = true
	dash_listo.emit()


func _iniciar_dash_visual() -> void:
	_timer_estela.start()
	await get_tree().create_timer(duracion_dash).timeout
	if is_instance_valid(self):
		_timer_estela.stop()


func _crear_estela() -> void:
	_visual.crear_estela()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if _muerto:
		return
	if body.is_in_group("personajes"):
		return
	
	if _red.es_remoto():
		if ControladorGlobal.es_partida_en_red and NetworkDiscovery.soy_host():
			NetworkDiscovery.forzar_muerte_jugador(jugador_id)
		return
		
	_ejecutar_muerte_local()


func morir() -> void:
	if _muerto:
		return
	if _red.es_remoto():
		if ControladorGlobal.es_partida_en_red and NetworkDiscovery.soy_host():
			# El host decreta la muerte del cliente (por ej. si el host detecta la colisión)
			NetworkDiscovery.forzar_muerte_jugador(jugador_id)
		return
	_ejecutar_muerte_local()


func _ejecutar_muerte_local() -> void:
	animacion.material = material_personaje_rojo
	_muerto = true
	animacion.stop()
	alas.visible = false
	alas.stop()
	if _red.es_red() and _red.es_mio():
		NetworkDiscovery.enviar_muerte()
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self): return
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
