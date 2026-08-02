class_name JefeFinal1
extends CharacterBody2D

@export var velocidad := 50.0
@onready var animacion = $animacion
@onready var timer_ataque = $Timerataque
var vida := 1
var jugador
var puede_atacar := true

var _indice_sincronizacion := -1
var _es_autoridad := true   # true si no hay red, o si soy el host

func _enter_tree() -> void:
	if ControladorGlobal.es_partida_en_red:
		add_to_group(NetworkDiscovery.GRUPO_ENEMIGOS_SINCRONIZABLES)

func _ready():
	jugador = get_tree().get_first_node_in_group("personajes")
	timer_ataque.timeout.connect(_on_timer_ataque_timeout)
	$Areadebil.body_entered.connect(_on_areadebil_body_entered)

	if ControladorGlobal.es_partida_en_red:
		var lista := get_tree().get_nodes_in_group(NetworkDiscovery.GRUPO_ENEMIGOS_SINCRONIZABLES)
		_indice_sincronizacion = lista.find(self)
		_es_autoridad = multiplayer.is_server()
		if not _es_autoridad:
			NetworkDiscovery.enemigo_posicion_recibida.connect(_on_posicion_remota)
			NetworkDiscovery.enemigo_golpeado_recibido.connect(_on_golpeado_remoto)
			NetworkDiscovery.enemigo_muerto_recibido.connect(_on_muerto_remoto)

func _physics_process(_delta):
	# El cliente no simula IA propia: solo aplica lo que le llega del host.
	if ControladorGlobal.es_partida_en_red and not _es_autoridad:
		return
	if jugador == null:
		return

	var distancia = global_position.distance_to(jugador.global_position)
	if distancia < 80:
		velocity.x = 0
	else:
		var direccion = sign(jugador.global_position.x - global_position.x)
		velocity.x = direccion * velocidad
		animacion.flip_h = direccion > 0
		if animacion.animation != "atak":
			animacion.play("atak")
	move_and_slide()

	if ControladorGlobal.es_partida_en_red and _es_autoridad:
		NetworkDiscovery.enviar_posicion_enemigo(_indice_sincronizacion, global_position, animacion.flip_h, animacion.animation)

func _on_areadebil_body_entered(body):
	# Solo el host decide golpes: si el cliente también los procesara,
	# un mismo salto le restaría vida al jefe dos veces.
	if ControladorGlobal.es_partida_en_red and not _es_autoridad:
		return
	if body is Personaje:
		if body.velocity.y > 0:
			vida -= 1
			print("Vida restante:", vida)
			body.velocity.y = -200
			if ControladorGlobal.es_partida_en_red:
				NetworkDiscovery.enviar_enemigo_golpeado(_indice_sincronizacion, vida)
			if vida <= 0:
				if ControladorGlobal.es_partida_en_red:
					NetworkDiscovery.enviar_enemigo_muerto(_indice_sincronizacion)
				queue_free()

func _on_timer_ataque_timeout():
	puede_atacar = true

# ---------- lado cliente: solo aplicar lo que manda el host ----------
func _on_posicion_remota(indice: int, pos: Vector2, flip_h: bool, nombre_animacion: String) -> void:
	if indice != _indice_sincronizacion:
		return
	global_position = pos
	animacion.flip_h = flip_h
	if animacion.animation != nombre_animacion:
		animacion.play(nombre_animacion)

func _on_golpeado_remoto(indice: int, vida_restante: int) -> void:
	if indice != _indice_sincronizacion:
		return
	vida = vida_restante

func _on_muerto_remoto(indice: int) -> void:
	if indice != _indice_sincronizacion:
		return
	queue_free()
