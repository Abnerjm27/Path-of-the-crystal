class_name JefeFinal
extends CharacterBody2D

# ── Señales ──────────────────────────────────────────────
signal jefe_muerto
signal jefe_danado(vida_restante: int)

# ── Estadísticas ─────────────────────────────────────────
@export var vida_maxima: int = 20
@export var velocidad_movimiento: float = 120.0
@export var velocidad_carga: float = 220.0

# ── Nodos ─────────────────────────────────────────────────
@onready var animacion: AnimatedSprite2D = $animacion
@onready var hitbox: Area2D              = $HitboxArea
@onready var hurtbox: Area2D             = $HurtboxArea
@onready var timer_ataque: Timer         = $TimerAtaque
@onready var timer_fase: Timer           = $TimerFase

# ── Estado interno ────────────────────────────────────────
enum Estado { IDLE, CAMINAR, CARGAR, ATACAR_SALTO, MORIR }

var estado_actual: Estado = Estado.IDLE
var vida: int
var _muerto: bool = false
var jugador: Node2D = null
var _direccion: float = -1.0
var _saltando: bool = false
var _velocidad_salto: float = -400.0
var fase_actual: int = 1

# ─────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("jefes")
	vida = vida_maxima
	animacion.play("idle")
	print("HurtboxArea layer: ", hurtbox.collision_layer)
	print("HurtboxArea mask: ", hurtbox.collision_mask)
	print("HitboxArea layer: ", hitbox.collision_layer)
	print("HitboxArea mask: ", hitbox.collision_mask)

	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)

	timer_ataque.wait_time = 1.5
	timer_ataque.timeout.connect(_elegir_ataque)
	timer_ataque.start()

	timer_fase.wait_time = 0.5
	timer_fase.timeout.connect(_revisar_fase)
	timer_fase.start()

	await get_tree().process_frame
	await get_tree().process_frame
	_buscar_jugador()

	estado_actual = Estado.CAMINAR

# ─────────────────────────────────────────────────────────
func _buscar_jugador() -> void:
	var jugadores = get_tree().get_nodes_in_group("personajes")
	if jugadores.size() > 0:
		jugador = jugadores[0]
		print("✅ Jefe encontró al jugador: ", jugador.name)
	else:
		push_error("❌ No se encontró ningún personaje en el grupo 'personajes'")

# ─────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if _muerto:
		return

	if jugador == null:
		_buscar_jugador()
		return

	velocity += get_gravity() * delta

	match estado_actual:
		Estado.CAMINAR:
			_comportamiento_caminar()

		Estado.CARGAR:
			_comportamiento_cargar()

		Estado.ATACAR_SALTO:
			velocity.x = _direccion * velocidad_carga * 0.8
			if _saltando and is_on_floor() and velocity.y >= 0:
				_saltando = false
				estado_actual = Estado.IDLE
				velocity.x = 0
				timer_ataque.wait_time = _tiempo_segun_fase(2.0, 1.5, 1.0)
				timer_ataque.start()

		Estado.IDLE:
			velocity.x = move_toward(velocity.x, 0, velocidad_movimiento)

	move_and_slide()
	_actualizar_animacion()

# ── Comportamientos ───────────────────────────────────────
func _comportamiento_caminar() -> void:
	if jugador == null:
		return
	_direccion = sign(jugador.global_position.x - global_position.x)
	velocity.x = _direccion * velocidad_movimiento
	animacion.flip_h = _direccion < 0

func _comportamiento_cargar() -> void:
	velocity.x = _direccion * velocidad_carga

# ── Selección de ataque ───────────────────────────────────
func _elegir_ataque() -> void:
	if _muerto:
		return

	var opciones: Array[String]
	match fase_actual:
		1: opciones = ["caminar", "caminar", "salto"]
		2: opciones = ["caminar", "salto", "cargar"]
		3: opciones = ["salto", "salto", "cargar", "cargar"]
		_: opciones = ["caminar"]

	var elegido: String = opciones[randi() % opciones.size()]
	match elegido:
		"caminar": _iniciar_caminar()
		"cargar":  _iniciar_carga()
		"salto":   _iniciar_salto()

	print("🎯 Jefe eligió: ", elegido, " | Fase: ", fase_actual)

# ── Acciones ─────────────────────────────────────────────
func _iniciar_caminar() -> void:
	estado_actual = Estado.CAMINAR
	timer_ataque.wait_time = _tiempo_segun_fase(2.0, 1.4, 1.0)
	timer_ataque.start()

func _iniciar_carga() -> void:
	if jugador == null:
		return
	estado_actual = Estado.CARGAR
	_direccion = sign(jugador.global_position.x - global_position.x)
	animacion.flip_h = _direccion < 0
	animacion.play("cargar")

	await get_tree().create_timer(0.7).timeout
	if not _muerto:
		estado_actual = Estado.IDLE
		timer_ataque.wait_time = _tiempo_segun_fase(2.0, 1.2, 0.8)
		timer_ataque.start()

func _iniciar_salto() -> void:
	if jugador == null or _saltando:
		_iniciar_caminar()
		return

	if not is_on_floor():
		_iniciar_caminar()
		return

	estado_actual = Estado.ATACAR_SALTO
	_saltando = true

	_direccion = sign(jugador.global_position.x - global_position.x)
	animacion.flip_h = _direccion < 0

	velocity.y = _velocidad_salto
	velocity.x = _direccion * velocidad_carga

	animacion.play("saltar")

# ── Fases ─────────────────────────────────────────────────
func _revisar_fase() -> void:
	var porcentaje: float = float(vida) / float(vida_maxima)
	if porcentaje <= 0.33 and fase_actual < 3:
		fase_actual = 3
		_efecto_cambio_fase()
	elif porcentaje <= 0.66 and fase_actual < 2:
		fase_actual = 2
		_efecto_cambio_fase()

func _efecto_cambio_fase() -> void:
	timer_ataque.stop()
	estado_actual = Estado.IDLE
	animacion.play("idle")
	await get_tree().create_timer(1.0).timeout
	if not _muerto:
		timer_ataque.start()

# ── Hurtbox — daña al jefe y empuja al jugador ───────────
func _on_hurtbox_body_entered(body: Node2D) -> void:
	if _muerto:
		return
	if body.is_in_group("personajes"):
		# Calcular dirección del empuje alejando al jugador del jefe
		var diferencia: Vector2 = body.global_position - global_position
		var direccion_x = sign(diferencia.x)
		if direccion_x == 0:
			direccion_x = 1.0

		# Empujar al jugador lejos sin matarlo
		if body.has_method("recibir_empuje"):
			body.recibir_empuje(direccion_x * 350.0, -300.0)

		# El jefe recibe daño
		recibir_danio(1)
		print("💥 Jefe recibió daño, vida: ", vida)

func recibir_danio(cantidad: int) -> void:
	if _muerto:
		return
	vida -= cantidad
	vida = max(vida, 0)
	jefe_danado.emit(vida)
	_parpadeo_danio()
	if vida <= 0:
		_morir()

func recibir_golpe(cantidad: int = 1) -> void:
	recibir_danio(cantidad)

func _parpadeo_danio() -> void:
	animacion.modulate = Color.RED
	await get_tree().create_timer(0.12).timeout
	if not _muerto:
		animacion.modulate = Color.WHITE

# ── Hitbox — mata y empuja al jugador ────────────────────
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("personajes"):
		var diferencia: Vector2 = body.global_position - global_position
		var viene_de_arriba: bool = diferencia.y < -10.0

		var fuerza_x: float
		var fuerza_y: float

		if viene_de_arriba:
			var direccion_x = sign(diferencia.x)
			if direccion_x == 0:
				direccion_x = 1.0
			fuerza_x = direccion_x * 200.0
			fuerza_y = -350.0
		else:
			var direccion_x = sign(diferencia.x)
			if direccion_x == 0:
				direccion_x = 1.0
			fuerza_x = direccion_x * 350.0
			fuerza_y = -250.0

		if body.has_method("recibir_empuje"):
			body.recibir_empuje(fuerza_x, fuerza_y)

		if body.has_method("morir"):
			body.morir()

# ── Muerte ────────────────────────────────────────────────
func _morir() -> void:
	_muerto = true
	timer_ataque.stop()
	timer_fase.stop()
	animacion.play("morir")
	hitbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitoring", false)

	await get_tree().create_timer(1.2).timeout
	jefe_muerto.emit()
	queue_free()

# ── Animaciones ───────────────────────────────────────────
func _actualizar_animacion() -> void:
	match estado_actual:
		Estado.CAMINAR:
			animacion.play("correr")
		Estado.CARGAR:
			animacion.play("cargar")
		Estado.ATACAR_SALTO:
			if not is_on_floor():
				animacion.play("saltar")
			else:
				animacion.play("idle")
		Estado.IDLE:
			if is_on_floor():
				animacion.play("idle")

# ── Utilidades ────────────────────────────────────────────
func _tiempo_segun_fase(t1: float, t2: float, t3: float) -> float:
	match fase_actual:
		1: return t1
		2: return t2
		3: return t3
		_: return t1
