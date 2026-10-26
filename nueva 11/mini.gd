class_name MiniJefe
extends CharacterBody2D

@onready var animacion = $animacion1

var vida := 1
var jugador
var _indice_sincronizacion := -1
var _es_autoridad := true

# Caché de jugadores para no llamar get_nodes_in_group cada frame de física
var _cache_jugadores: Array = []
var _frames_sin_actualizar_cache := 0
const INTERVALO_ACTUALIZAR_CACHE := 60  # refrescar caché cada 60 frames (~1s)


func _enter_tree() -> void:
	if ControladorGlobal.es_partida_en_red:
		add_to_group(NetworkDiscovery.GRUPO_ENEMIGOS_SINCRONIZABLES)


func _ready():
	jugador = get_tree().get_first_node_in_group("personajes")
	$Areadebil.body_entered.connect(_on_areadebil_body_entered)
	if ControladorGlobal.es_partida_en_red:
		var lista := get_tree().get_nodes_in_group(NetworkDiscovery.GRUPO_ENEMIGOS_SINCRONIZABLES)
		_indice_sincronizacion = lista.find(self)
		# Corregido: usar NetworkDiscovery.soy_host() en vez de multiplayer.is_server()
		_es_autoridad = NetworkDiscovery.soy_host()
		if not _es_autoridad:
			NetworkDiscovery.enemigo_golpeado_recibido.connect(_on_golpeado_remoto)
			NetworkDiscovery.enemigo_muerto_recibido.connect(_on_muerto_remoto)


func _physics_process(_delta: float) -> void:
	# El cliente no necesita buscar jugadores (no simula lógica de IA)
	if ControladorGlobal.es_partida_en_red and not _es_autoridad:
		return
	_actualizar_direccion()


func _actualizar_direccion() -> void:
	var mas_cercano = _obtener_jugador_mas_cercano()
	if mas_cercano == null:
		return
	if mas_cercano.global_position.x < global_position.x:
		animacion.flip_h = true
	elif mas_cercano.global_position.x > global_position.x:
		animacion.flip_h = false


func _obtener_jugador_mas_cercano() -> Node2D:
	# Caché: solo refresca la lista cada INTERVALO_ACTUALIZAR_CACHE frames
	_frames_sin_actualizar_cache += 1
	if _frames_sin_actualizar_cache >= INTERVALO_ACTUALIZAR_CACHE or _cache_jugadores.is_empty():
		_cache_jugadores = get_tree().get_nodes_in_group("personajes")
		_frames_sin_actualizar_cache = 0

	var mas_cercano: Node2D = null
	var distancia_minima := INF
	for j in _cache_jugadores:
		if not is_instance_valid(j):
			continue
		var distancia := global_position.distance_squared_to(j.global_position)
		if distancia < distancia_minima:
			distancia_minima = distancia
			mas_cercano = j
	return mas_cercano


func _on_areadebil_body_entered(body):
	if ControladorGlobal.es_partida_en_red and not _es_autoridad:
		return
	if body is Personaje:
		if body.velocity.y > 0:
			vida -= 1
			print("Vida restante:", vida)
			if ControladorGlobal.es_partida_en_red and not body.es_mio_localmente():
				# Golpeó el dummy de un jugador remoto: avisarle por RPC para que rebote en su propia máquina
				NetworkDiscovery.enviar_rebote_jugador(body.jugador_id)
			else:
				# Jugador local (host) o partida sin red: rebote directo
				body.velocity.y = -200
			if ControladorGlobal.es_partida_en_red:
				NetworkDiscovery.enviar_enemigo_golpeado(_indice_sincronizacion, vida)
			if vida <= 0:
				if ControladorGlobal.es_partida_en_red:
					NetworkDiscovery.enviar_enemigo_muerto(_indice_sincronizacion)
				queue_free()


func _on_golpeado_remoto(indice: int, vida_restante: int) -> void:
	if indice != _indice_sincronizacion:
		return
	vida = vida_restante


func _on_muerto_remoto(indice: int) -> void:
	if indice != _indice_sincronizacion:
		return
	# Desconectar señales antes de liberar para evitar llamadas sobre nodo destruido
	if NetworkDiscovery.enemigo_golpeado_recibido.is_connected(_on_golpeado_remoto):
		NetworkDiscovery.enemigo_golpeado_recibido.disconnect(_on_golpeado_remoto)
	if NetworkDiscovery.enemigo_muerto_recibido.is_connected(_on_muerto_remoto):
		NetworkDiscovery.enemigo_muerto_recibido.disconnect(_on_muerto_remoto)
	queue_free()
