class_name DemonioVolador
extends CharacterBody2D

# ── Señales ──────────────────────────────────────────────
signal jefe_muerto
signal jefe_danado(vida_restante: int)

# ── Estadísticas ─────────────────────────────────────────
@export var vida_maxima: int = 10
@export var velocidad_vuelo: float = 90.0
@export var distancia_objetivo: float = 180.0   # Distancia objetivo hacia el jugador
@export var margen_distancia: float = 30.0       # Zona muerta para evitar oscilaciones
@export var amplitud_vaiven: float = 40.0        # Amplitud de oscilación lateral
@export var velocidad_vaiven: float = 2.5         # Frecuencia de oscilación

# ── Nodos ─────────────────────────────────────────────────
@onready var animacion: AnimatedSprite2D = $animacion
@onready var hitbox: Area2D               = $HitboxArea
@onready var hurtbox: Area2D              = $HurtboxArea
@onready var timer_ataque: Timer          = $TimerAtaque
@onready var timer_fase: Timer            = $TimerFase
@onready var punto_disparo: Marker2D      = $PuntoDisparo

# ── Estado interno ────────────────────────────────────────
enum Estado { IDLE, VOLAR, ATACAR, MORIR }

var estado_actual: Estado = Estado.IDLE
var vida: int
var _muerto: bool = false
var jugador: Node2D = null
var fase_actual: int = 1
var _tiempo_vaiven: float = 0.0
var _offset_disparo_base: Vector2

# ── Sincronización y Red ──
var _indice_sincronizacion: int = -1
var _es_autoridad: bool = true
var _pos_objetivo_red: Vector2
var _flip_h_objetivo_red: bool = false
var _anim_objetivo_red: String = "idle"

# Control de tasa de envío de red (Tickrate)
var _tiempo_acumulado_red: float = 0.0
const INTERVALO_ENVIO_RED: float = 0.033 # ~30 Hz
var _ultima_pos_enviada: Vector2 = Vector2.ZERO


func _enter_tree() -> void:
	if ControladorGlobal.es_partida_en_red:
		add_to_group(NetworkDiscovery.GRUPO_ENEMIGOS_SINCRONIZABLES)


func _ready() -> void:
	add_to_group("jefes")
	vida = vida_maxima
	animacion.play("idle")
	_tiempo_vaiven = randf() * TAU
	_offset_disparo_base = punto_disparo.position

	if ControladorGlobal.es_partida_en_red:
		var lista := get_tree().get_nodes_in_group(NetworkDiscovery.GRUPO_ENEMIGOS_SINCRONIZABLES)
		_indice_sincronizacion = lista.find(self)
		_es_autoridad = NetworkDiscovery.soy_host()
		_pos_objetivo_red = global_position

	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)

	if not _es_autoridad:
		NetworkDiscovery.enemigo_posicion_recibida.connect(_on_posicion_remota)
		NetworkDiscovery.enemigo_golpeado_recibido.connect(_on_golpeado_remoto)
		NetworkDiscovery.enemigo_muerto_recibido.connect(_on_muerto_remoto)
		return

	timer_ataque.wait_time = 2.0
	timer_ataque.timeout.connect(_intentar_atacar)
	timer_ataque.start()

	timer_fase.wait_time = 0.5
	timer_fase.timeout.connect(_revisar_fase)
	timer_fase.start()

	await get_tree().process_frame
	await get_tree().process_frame
	_buscar_jugador()
	estado_actual = Estado.VOLAR


func _buscar_jugador() -> void:
	_actualizar_objetivo()
	if jugador == null:
		push_error("❌ No se encontró ningún personaje en el grupo 'personajes'")


func _actualizar_objetivo() -> void:
	var jugadores := get_tree().get_nodes_in_group("personajes")
	var jugadores_validos: Array = jugadores.filter(func(j): return is_instance_valid(j))

	if jugadores_validos.is_empty():
		jugador = null
		return

	var mas_cercano: Node2D = jugadores_validos[0] as Node2D
	var distancia_mas_cercana: float = global_position.distance_to(mas_cercano.global_position)
	
	for j in jugadores_validos:
		var p := j as Node2D
		if p:
			var distancia := global_position.distance_to(p.global_position)
			if distancia < distancia_mas_cercana:
				mas_cercano = p
				distancia_mas_cercana = distancia
				
	jugador = mas_cercano


func _physics_process(delta: float) -> void:
	if _muerto:
		return

	# --- RENDERIZADO EN CLIENTE (Interpolación Suave) ---
	if ControladorGlobal.es_partida_en_red and not _es_autoridad:
		global_position = global_position.lerp(_pos_objetivo_red, 25.0 * delta)
		animacion.flip_h = _flip_h_objetivo_red
		_actualizar_punto_disparo()
		if animacion.sprite_frames and animacion.sprite_frames.has_animation(_anim_objetivo_red):
			animacion.play(_anim_objetivo_red)
		return

	# --- SIMULACIÓN AUTORITATIVA EN EL HOST ---
	if jugador == null:
		_buscar_jugador()
		return

	match estado_actual:
		Estado.VOLAR:
			_comportamiento_volar(delta)
		Estado.ATACAR, Estado.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, velocidad_vuelo * delta)

	move_and_slide()
	_actualizar_animacion()

	# Transmisión controlada por Tickrate
	if ControladorGlobal.es_partida_en_red:
		_tiempo_acumulado_red += delta
		if _tiempo_acumulado_red >= INTERVALO_ENVIO_RED:
			_tiempo_acumulado_red = 0.0
			if global_position.distance_squared_to(_ultima_pos_enviada) > 0.05 or velocity != Vector2.ZERO:
				_ultima_pos_enviada = global_position
				NetworkDiscovery.enviar_posicion_enemigo(_indice_sincronizacion, global_position, animacion.flip_h, animacion.animation)


# ── Comportamiento de Vuelo ──
func _comportamiento_volar(delta: float) -> void:
	_tiempo_vaiven += delta * velocidad_vaiven

	var hacia_jugador: Vector2 = jugador.global_position - global_position
	var distancia_actual: float = hacia_jugador.length()
	var direccion_normalizada: Vector2 = hacia_jugador.normalized() if distancia_actual > 0.01 else Vector2.ZERO

	var velocidad_deseada := Vector2.ZERO

	if distancia_actual > distancia_objetivo + margen_distancia:
		velocidad_deseada = direccion_normalizada * velocidad_vuelo
	elif distancia_actual < distancia_objetivo - margen_distancia:
		velocidad_deseada = -direccion_normalizada * velocidad_vuelo

	var perpendicular: Vector2 = direccion_normalizada.orthogonal()
	velocidad_deseada += perpendicular * sin(_tiempo_vaiven) * amplitud_vaiven

	velocity = velocity.lerp(velocidad_deseada, 0.08)

	if direccion_normalizada.x != 0:
		animacion.flip_h = direccion_normalizada.x < 0
		_actualizar_punto_disparo()


func _actualizar_punto_disparo() -> void:
	punto_disparo.position.x = -_offset_disparo_base.x if animacion.flip_h else _offset_disparo_base.x


# ── Ataque ──
func _intentar_atacar() -> void:
	if _muerto or jugador == null or estado_actual == Estado.ATACAR:
		return
	_encarar_jugador()
	_lanzar_fuego()
	timer_ataque.wait_time = _tiempo_segun_fase(2.2, 1.6, 1.1)
	timer_ataque.start()


func _encarar_jugador() -> void:
	if jugador == null:
		return
	var direccion_x: float = jugador.global_position.x - global_position.x
	if direccion_x != 0:
		animacion.flip_h = direccion_x < 0
		_actualizar_punto_disparo()


func _lanzar_fuego() -> void:
	estado_actual = Estado.ATACAR
	animacion.play("attack")

	await get_tree().create_timer(0.45).timeout

	if not _muerto and jugador != null:
		var direccion: Vector2 = (jugador.global_position - punto_disparo.global_position).normalized()
		if ControladorGlobal.es_partida_en_red:
			rpc("rpc_disparar_bola", punto_disparo.global_position, direccion)
		else:
			_spawn_bola_fuego(punto_disparo.global_position, direccion)

	await get_tree().create_timer(0.35).timeout
	if not _muerto:
		estado_actual = Estado.VOLAR


@rpc("authority", "call_local", "reliable")
func rpc_disparar_bola(pos: Vector2, direccion: Vector2) -> void:
	_spawn_bola_fuego(pos, direccion)


func _spawn_bola_fuego(pos: Vector2, direccion: Vector2) -> void:
	var escena_bola := preload("res://enemigo/bola_fuego.tscn")
	if escena_bola:
		var bola = escena_bola.instantiate()
		bola.global_position = pos
		bola.direccion = direccion
		get_tree().current_scene.add_child(bola)


# ── Fases ──
func _revisar_fase() -> void:
	_actualizar_objetivo()
	var porcentaje: float = float(vida) / float(vida_maxima)
	if porcentaje <= 0.33 and fase_actual < 3:
		fase_actual = 3
	elif porcentaje <= 0.66 and fase_actual < 2:
		fase_actual = 2


func _tiempo_segun_fase(t1: float, t2: float, t3: float) -> float:
	match fase_actual:
		1: return t1
		2: return t2
		3: return t3
		_: return t1


# ── Colisiones y Daño ──
func _on_hurtbox_body_entered(body: Node2D) -> void:
	if (ControladorGlobal.es_partida_en_red and not _es_autoridad) or _muerto:
		return
	if body.is_in_group("personajes") and body.velocity.y > 0:
		if body.has_method("recibir_empuje"):
			body.recibir_empuje(0, -300.0)
		recibir_danio(1)


func recibir_danio(cantidad: int) -> void:
	if _muerto:
		return
	vida = max(vida - cantidad, 0)
	jefe_danado.emit(vida)
	_parpadeo_danio()

	if ControladorGlobal.es_partida_en_red and _es_autoridad:
		NetworkDiscovery.enviar_enemigo_golpeado(_indice_sincronizacion, vida)

	if vida <= 0:
		_morir()


func _parpadeo_danio() -> void:
	animacion.modulate = Color.RED
	await get_tree().create_timer(0.12).timeout
	if not _muerto:
		animacion.modulate = Color.WHITE


func _on_hitbox_body_entered(body: Node2D) -> void:
	if (ControladorGlobal.es_partida_en_red and not _es_autoridad) or _muerto:
		return
	if body.is_in_group("personajes"):
		var direccion_x: float = sign(body.global_position.x - global_position.x)
		if direccion_x == 0:
			direccion_x = 1.0
		if body.has_method("recibir_empuje"):
			body.recibir_empuje(direccion_x * 300.0, -250.0)
		if body.has_method("morir"):
			body.morir()


# ── Muerte ──
func _morir() -> void:
	_muerto = true
	timer_ataque.stop()
	timer_fase.stop()
	animacion.play("death")
	hitbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitoring", false)
	velocity = Vector2.ZERO

	if ControladorGlobal.es_partida_en_red and _es_autoridad:
		NetworkDiscovery.enviar_enemigo_muerto(_indice_sincronizacion)

	await get_tree().create_timer(1.0).timeout
	jefe_muerto.emit()
	queue_free()


func _actualizar_animacion() -> void:
	match estado_actual:
		Estado.VOLAR:
			animacion.play("flying")
		Estado.IDLE:
			animacion.play("idle")


# ── Respuestas Remotas (Cliente) ──
func _on_posicion_remota(indice: int, pos: Vector2, flip_h: bool, nombre_animacion: String) -> void:
	if indice != _indice_sincronizacion:
		return
	_pos_objetivo_red = pos
	_flip_h_objetivo_red = flip_h
	_anim_objetivo_red = nombre_animacion


func _on_golpeado_remoto(indice: int, vida_restante: int) -> void:
	if indice != _indice_sincronizacion:
		return
	vida = vida_restante
	jefe_danado.emit(vida)
	_parpadeo_danio()


func _on_muerto_remoto(indice: int) -> void:
	if indice != _indice_sincronizacion:
		return
	_muerto = true
	animacion.play("death")
	hitbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitoring", false)
	# Desconectar señales antes de liberar para evitar llamadas sobre nodo destruido
	if NetworkDiscovery.enemigo_posicion_recibida.is_connected(_on_posicion_remota):
		NetworkDiscovery.enemigo_posicion_recibida.disconnect(_on_posicion_remota)
	if NetworkDiscovery.enemigo_golpeado_recibido.is_connected(_on_golpeado_remoto):
		NetworkDiscovery.enemigo_golpeado_recibido.disconnect(_on_golpeado_remoto)
	if NetworkDiscovery.enemigo_muerto_recibido.is_connected(_on_muerto_remoto):
		NetworkDiscovery.enemigo_muerto_recibido.disconnect(_on_muerto_remoto)
	await get_tree().create_timer(1.0).timeout
	queue_free()
