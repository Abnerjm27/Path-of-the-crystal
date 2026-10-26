class_name JefeFinal1
extends CharacterBody2D

# ── Estadísticas y Configuración ─────────────────────────
@export var velocidad: float = 50.0
@export var vida_maxima: int = 1

# ── Nodos ─────────────────────────────────────────────────
@onready var animacion: AnimatedSprite2D = $animacion
@onready var timer_ataque: Timer = $Timerataque

# ── Estado Interno ────────────────────────────────────────
var vida: int = 1
var jugador: Node2D = null
var puede_atacar: bool = true

# ── Sincronización y Red ──
var _indice_sincronizacion: int = -1
var _es_autoridad: bool = true
var _pos_objetivo_red: Vector2
var _flip_h_objetivo_red: bool = false
var _anim_objetivo_red: String = "atak"

# Control de Tasa de Envío (Tickrate)
var _tiempo_acumulado_red: float = 0.0
const INTERVALO_ENVIO_RED: float = 0.033 # ~30 Hz
var _ultima_pos_enviada: Vector2 = Vector2.ZERO


func _enter_tree() -> void:
	if ControladorGlobal.es_partida_en_red:
		add_to_group(NetworkDiscovery.GRUPO_ENEMIGOS_SINCRONIZABLES)


func _ready() -> void:
	vida = vida_maxima
	timer_ataque.timeout.connect(_on_timer_ataque_timeout)
	
	if has_node("Areadebil"):
		$Areadebil.body_entered.connect(_on_areadebil_body_entered)

	if ControladorGlobal.es_partida_en_red:
		var lista := get_tree().get_nodes_in_group(NetworkDiscovery.GRUPO_ENEMIGOS_SINCRONIZABLES)
		_indice_sincronizacion = lista.find(self)
		_es_autoridad = NetworkDiscovery.soy_host()
		_pos_objetivo_red = global_position

		if not _es_autoridad:
			NetworkDiscovery.enemigo_posicion_recibida.connect(_on_posicion_remota)
			NetworkDiscovery.enemigo_golpeado_recibido.connect(_on_golpeado_remoto)
			NetworkDiscovery.enemigo_muerto_recibido.connect(_on_muerto_remoto)
			return

	_buscar_jugador_mas_cercano()

func _buscar_jugador_mas_cercano() -> void:
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
	# --- RENDERIZADO EN CLIENTE (Interpolación Suave) ---
	if ControladorGlobal.es_partida_en_red and not _es_autoridad:
		global_position = global_position.lerp(_pos_objetivo_red, 25.0 * delta)
		animacion.flip_h = _flip_h_objetivo_red
		if animacion.sprite_frames and animacion.sprite_frames.has_animation(_anim_objetivo_red):
			if animacion.animation != _anim_objetivo_red:
				animacion.play(_anim_objetivo_red)
		return

	# --- SIMULACIÓN AUTORITATIVA EN EL HOST ---
	if jugador == null or not is_instance_valid(jugador):
		_buscar_jugador_mas_cercano()
		if jugador == null:
			return

	var distancia := global_position.distance_to(jugador.global_position)
	if distancia < 80.0:
		velocity.x = 0.0
	else:
		var direccion: float = sign(jugador.global_position.x - global_position.x)
		velocity.x = direccion * velocidad
		animacion.flip_h = (direccion > 0)
		if animacion.animation != "atak" and animacion.sprite_frames.has_animation("atak"):
			animacion.play("atak")

	move_and_slide()

	# Transmisión eficiente controlada por Tickrate
	if ControladorGlobal.es_partida_en_red:
		_tiempo_acumulado_red += delta
		if _tiempo_acumulado_red >= INTERVALO_ENVIO_RED:
			_tiempo_acumulado_red = 0.0
			if global_position.distance_squared_to(_ultima_pos_enviada) > 0.05 or velocity != Vector2.ZERO:
				_ultima_pos_enviada = global_position
				NetworkDiscovery.enviar_posicion_enemigo(_indice_sincronizacion, global_position, animacion.flip_h, animacion.animation)


func _on_areadebil_body_entered(body: Node2D) -> void:
	if ControladorGlobal.es_partida_en_red and not _es_autoridad:
		return

	if body is Personaje:
		var personaje := body as Personaje
		if personaje.velocity.y > 0:
			vida -= 1

			if ControladorGlobal.es_partida_en_red and not personaje.es_mio_localmente():
				# Avisar por red el rebote al jugador remoto que realizó el impacto
				NetworkDiscovery.enviar_rebote_jugador(personaje.jugador_id)
			else:
				# Rebote directo local
				personaje.velocity.y = -200.0

			if ControladorGlobal.es_partida_en_red:
				NetworkDiscovery.enviar_enemigo_golpeado(_indice_sincronizacion, vida)

			if vida <= 0:
				if ControladorGlobal.es_partida_en_red:
					NetworkDiscovery.enviar_enemigo_muerto(_indice_sincronizacion)
				queue_free()


func _on_timer_ataque_timeout() -> void:
	puede_atacar = true


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


func _on_muerto_remoto(indice: int) -> void:
	if indice != _indice_sincronizacion:
		return
	# Desconectar señales antes de liberar para evitar llamadas sobre nodo destruido
	if NetworkDiscovery.enemigo_posicion_recibida.is_connected(_on_posicion_remota):
		NetworkDiscovery.enemigo_posicion_recibida.disconnect(_on_posicion_remota)
	if NetworkDiscovery.enemigo_golpeado_recibido.is_connected(_on_golpeado_remoto):
		NetworkDiscovery.enemigo_golpeado_recibido.disconnect(_on_golpeado_remoto)
	if NetworkDiscovery.enemigo_muerto_recibido.is_connected(_on_muerto_remoto):
		NetworkDiscovery.enemigo_muerto_recibido.disconnect(_on_muerto_remoto)
	queue_free()
