extends Node

# --- Configuración ---
const PUERTO_DESCUBRIMIENTO := 8910
const PUERTO_JUEGO := 7777
const INTERVALO_BROADCAST := 1.0
const IDENTIFICADOR := "PATH_CRYSTAL"

# --- Señales que la UI escucha ---
signal partida_encontrada(ip: String, nombre_partida: String)
signal conexion_exitosa
signal conexion_fallida
signal conexion_perdida(id: int)
signal jugador_remoto_conectado(id: int)
signal jugador_listo(id: int, indice_personaje: int)
signal nivel_debe_iniciar(selecciones: Dictionary)
signal posicion_remota_recibida(id_emisor: int, pos: Vector2, vel: Vector2, animacion: String, flip_h: bool)
signal confirmacion_host_recibida(tick: int, pos_valida: Vector2, vel_valida: Vector2) # Para Reconciliación
signal muerte_remota_recibida(id_emisor: int)
signal evento_animacion_recibido(evento: String)
signal nivel_cooperativo_host_recibido(nivel: int)
signal moneda_remota_recogida(indice: int)
signal siguiente_nivel_recibido
signal reiniciar_nivel_recibido
signal salir_recibido
signal saltar_cinematica_recibido
signal nivel_elegido_recibido(ruta: String)
signal abandonar_multijugador_recibido
signal pausa_recibida(pausado: bool)
signal trampa_caida_recibida(indice: int)
signal enemigo_posicion_recibida(indice: int, pos: Vector2, flip_h: bool, animacion: String)
signal enemigo_golpeado_recibido(indice: int, vida_restante: int)
signal enemigo_muerto_recibido(indice: int)
signal rebote_jugador_recibido(jugador_id: int)

# --- Grupos Sincronizables ---
const GRUPO_ANIMADORES_SINCRONIZABLES := "animadores_sincronizables"
const GRUPO_TRAMPAS_CAIDA_SINCRONIZABLES := "trampas_caida_sincronizables"
const GRUPO_ENEMIGOS_SINCRONIZABLES := "enemigos_sincronizables"

# --- Variables de estado ---
var _socket_broadcast: PacketPeerUDP
var _socket_escucha: PacketPeerUDP
var _timer_broadcast: Timer

var _es_host := false
var _nombre_partida := ""
var _partidas_ya_vistas := {}
var _selecciones_personaje := {}
var _saliendo_intencionalmente := false
var _abandonando_multijugador := false

var _animadores_deterministas: Dictionary = {}
var _generacion_sincronizacion := 0
var _tiempos_envio_generacion: Dictionary = {}


func _ready() -> void:
	set_process(false)
	set_physics_process(false)

	_timer_broadcast = Timer.new()
	_timer_broadcast.wait_time = INTERVALO_BROADCAST
	_timer_broadcast.timeout.connect(_enviar_broadcast)
	add_child(_timer_broadcast)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_manejador_salida_repentina()


func _manejador_salida_repentina() -> void:
	if multiplayer.multiplayer_peer != null and multiplayer.get_peers().size() > 0:
		enviar_salir_del_juego()
		await get_tree().create_timer(0.05).timeout

	cerrar_conexion()
	get_tree().quit()


func _on_peer_connected(id: int) -> void:
	jugador_remoto_conectado.emit(id)
	if multiplayer.is_server():
		rpc_id(id, "_rpc_recibir_nivel_cooperativo_host", ControladorGlobal.nivel_cooperativo)


func _on_peer_disconnected(id: int) -> void:
	_selecciones_personaje.erase(id)
	if not _saliendo_intencionalmente and not _abandonando_multijugador:
		conexion_perdida.emit(id)


func _on_server_disconnected() -> void:
	if not _saliendo_intencionalmente:
		conexion_perdida.emit(0)


# ---------- HOST & SERVIDOR ----------
func iniciar_partida(nombre_partida: String) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PUERTO_JUEGO, 2)
	if error != OK:
		push_error("No se pudo crear el servidor: %s" % error)
		return false

	var host: ENetConnection = peer.get_host()
	if host:
		host.bandwidth_limit(0, 0)

	multiplayer.multiplayer_peer = peer
	_es_host = true
	_nombre_partida = nombre_partida

	_socket_broadcast = PacketPeerUDP.new()
	_socket_broadcast.set_broadcast_enabled(true)
	_socket_broadcast.set_dest_address("255.255.255.255", PUERTO_DESCUBRIMIENTO)
	_timer_broadcast.start()

	return true


func detener_host() -> void:
	_es_host = false
	_timer_broadcast.stop()
	if _socket_broadcast:
		_socket_broadcast.close()
		_socket_broadcast = null


func _enviar_broadcast() -> void:
	if not _es_host or _socket_broadcast == null:
		return
	var mensaje := "%s|%s|%d" % [IDENTIFICADOR, _nombre_partida, PUERTO_JUEGO]
	_socket_broadcast.put_packet(mensaje.to_utf8_buffer())


# ---------- CLIENTE ----------
func buscar_partidas() -> void:
	_partidas_ya_vistas.clear()
	_socket_escucha = PacketPeerUDP.new()
	var error := _socket_escucha.bind(PUERTO_DESCUBRIMIENTO)
	if error != OK:
		push_error("No se pudo escuchar en el puerto de descubrimiento: %s" % error)
		return
	set_process(true)


func dejar_de_buscar() -> void:
	set_process(false)
	if _socket_escucha:
		_socket_escucha.close()
		_socket_escucha = null


func conectarse_a(ip: String) -> void:
	dejar_de_buscar()

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ip, PUERTO_JUEGO)
	if error != OK:
		conexion_fallida.emit()
		return

	var host: ENetConnection = peer.get_host()
	if host:
		host.bandwidth_limit(0, 0)

	multiplayer.multiplayer_peer = peer
	
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)


func _on_connected_to_server() -> void:
	conexion_exitosa.emit()


func _on_connection_failed() -> void:
	conexion_fallida.emit()


func _process(_delta: float) -> void:
	if _socket_escucha != null:
		while _socket_escucha.get_available_packet_count() > 0:
			var datos := _socket_escucha.get_packet().get_string_from_utf8()
			var ip_origen := _socket_escucha.get_packet_ip()
			var partes := datos.split("|")

			if partes.size() == 3 and partes[0] == IDENTIFICADOR:
				var nombre_partida := partes[1]
				if not _partidas_ya_vistas.has(ip_origen):
					_partidas_ya_vistas[ip_origen] = true
					partida_encontrada.emit(ip_origen, nombre_partida)


# ---------- TRANSMISIÓN DE POSICIONES Y PREDICCIÓN ----------
func enviar_posicion(pos: Vector2, vel: Vector2, animacion: String, flip_h: bool) -> void:
	rpc("rpc_posicion", pos, vel, animacion, flip_h)

@rpc("any_peer", "unreliable")
func rpc_posicion(pos: Vector2, vel: Vector2, animacion: String, flip_h: bool) -> void:
	var id_emisor := multiplayer.get_remote_sender_id()
	posicion_remota_recibida.emit(id_emisor, pos, vel, animacion, flip_h)


func enviar_estado_predicho(tick: int, pos: Vector2, vel: Vector2) -> void:
	rpc_id(1, "rpc_validar_estado_cliente", tick, pos, vel)

@rpc("any_peer", "unreliable")
func rpc_validar_estado_cliente(tick: int, pos: Vector2, vel: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var id_emisor := multiplayer.get_remote_sender_id()

	var pos_real := pos
	var vel_real := vel

	# Se consulta al Host por los datos autoritativos reales del personaje del cliente.
	# Usamos el estado de red "crudo" (el último dato recibido por RPC), no la posición
	# visual ya suavizada por el lerp de renderizado remoto: si tomáramos global_position
	# directamente, le devolveríamos al cliente un valor con un retraso extra acumulado
	# por ese suavizado, que crece con la velocidad del personaje (por ejemplo, en un dash).
	var personajes := get_tree().get_nodes_in_group("personajes")
	for p in personajes:
		var personaje := p as Personaje
		if personaje and not personaje.es_mio_localmente():
			var estado := personaje.obtener_estado_red_crudo()
			pos_real = estado["pos"]
			vel_real = estado["vel"]
			break

	# El Host devuelve la posición y velocidad autoritativa
	rpc_id(id_emisor, "rpc_confirmar_estado_host", tick, pos_real, vel_real)

@rpc("authority", "unreliable")
func rpc_confirmar_estado_host(tick: int, pos_valida: Vector2, vel_valida: Vector2) -> void:
	confirmacion_host_recibida.emit(tick, pos_valida, vel_valida)


func enviar_posicion_enemigo(indice: int, pos: Vector2, flip_h: bool, animacion: String) -> void:
	rpc("rpc_posicion_enemigo", indice, pos, flip_h, animacion)

@rpc("authority", "unreliable")
func rpc_posicion_enemigo(indice: int, pos: Vector2, flip_h: bool, animacion: String) -> void:
	enemigo_posicion_recibida.emit(indice, pos, flip_h, animacion)


func enviar_evento_animacion(evento: String) -> void:
	rpc("rpc_evento_animacion", evento)

@rpc("any_peer", "reliable")
func rpc_evento_animacion(evento: String) -> void:
	evento_animacion_recibido.emit(evento)


# ---------- SINCRONIZACIÓN DE ANIMADORES DETERMINISTAS ----------
func _physics_process(_delta: float) -> void:
	if _animadores_deterministas.is_empty():
		set_physics_process(false)
		return

	var ahora := Time.get_ticks_msec()
	for animador in _animadores_deterministas.keys():
		if not is_instance_valid(animador):
			_animadores_deterministas.erase(animador)
			continue
		var datos_anim: Dictionary = _animadores_deterministas[animador]
		var posicion := _posicion_actual_animador(datos_anim, ahora)
		animador.seek(posicion, true)


func _posicion_actual_animador(datos_anim: Dictionary, ahora_ms: float) -> float:
	if datos_anim.duracion <= 0.0:
		return 0.0
	var transcurrido: float = (ahora_ms - datos_anim.epoch_ms) / 1000.0
	if datos_anim.modo_loop == Animation.LOOP_PINGPONG:
		var ciclo: float = datos_anim.duracion * 2.0
		var t: float = fmod(transcurrido, ciclo)
		if t < 0.0:
			t += ciclo
		return t if t <= datos_anim.duracion else ciclo - t
	else:
		var posicion: float = fmod(transcurrido, datos_anim.duracion)
		if posicion < 0.0:
			posicion += datos_anim.duracion
		return posicion


func inicializar_animadores_host() -> void:
	var ahora := Time.get_ticks_msec()
	var lista := get_tree().get_nodes_in_group(GRUPO_ANIMADORES_SINCRONIZABLES)
	
	for i in lista.size():
		var animador = lista[i] as AnimationPlayer
		if not animador or animador.current_animation == "":
			continue
		
		var anim := animador.get_animation(animador.current_animation)
		if not anim:
			continue

		var posicion_inicial: float = animador.current_animation_position
		animador.seek(posicion_inicial, true)
		animador.speed_scale = 0.0
		
		_animadores_deterministas[animador] = {
			"epoch_ms": ahora - posicion_inicial * 1000.0,
			"duracion": anim.length,
			"modo_loop": anim.loop_mode,
		}

	if not _animadores_deterministas.is_empty():
		set_physics_process(true)


func solicitar_sincronizacion_nivel() -> void:
	_generacion_sincronizacion += 1
	_tiempos_envio_generacion[_generacion_sincronizacion] = Time.get_ticks_msec()
	rpc_id(1, "_rpc_solicitar_sincronizacion_nivel", _generacion_sincronizacion)


@rpc("any_peer", "reliable")
func _rpc_solicitar_sincronizacion_nivel(generacion: int) -> void:
	if not multiplayer.is_server():
		return
	var id_emisor := multiplayer.get_remote_sender_id()
	var lista := get_tree().get_nodes_in_group(GRUPO_ANIMADORES_SINCRONIZABLES)
	var ahora := Time.get_ticks_msec()
	var datos: Array = []
	
	for i in lista.size():
		var animador = lista[i] as AnimationPlayer
		if not animador or animador.current_animation == "":
			continue

		var posicion_exacta: float
		var modo_loop: int
		if _animadores_deterministas.has(animador):
			var datos_anim: Dictionary = _animadores_deterministas[animador]
			posicion_exacta = _posicion_actual_animador(datos_anim, ahora)
			modo_loop = datos_anim.modo_loop
		else:
			var anim := animador.get_animation(animador.current_animation)
			if not anim:
				continue
			posicion_exacta = animador.current_animation_position
			modo_loop = anim.loop_mode

		datos.append({
			"indice": i,
			"animacion": animador.current_animation,
			"posicion": posicion_exacta,
			"modo_loop": modo_loop,
		})

	rpc_id(id_emisor, "_rpc_recibir_sincronizacion_nivel", datos, generacion)


@rpc("authority", "reliable")
func _rpc_recibir_sincronizacion_nivel(datos: Array, generacion: int) -> void:
	if generacion != _generacion_sincronizacion:
		return
	var ahora_ms := Time.get_ticks_msec()
	var tiempo_envio: float = _tiempos_envio_generacion.get(generacion, ahora_ms)
	_tiempos_envio_generacion.erase(generacion)
	var latencia_estimada_ms: float = (ahora_ms - tiempo_envio) / 2.0

	var lista := get_tree().get_nodes_in_group(GRUPO_ANIMADORES_SINCRONIZABLES)
	var hubo_fallas := false

	for entrada in datos:
		var i: int = entrada["indice"]
		if i < 0 or i >= lista.size():
			hubo_fallas = true
			continue
		var nodo = lista[i] as AnimationPlayer
		if not nodo:
			hubo_fallas = true
			continue

		var nombre_animacion: String = entrada["animacion"]
		var posicion: float = entrada["posicion"]
		var modo_loop: int = entrada["modo_loop"]
		var anim := nodo.get_animation(nombre_animacion)
		if not anim:
			continue

		var epoch_ms: float = ahora_ms - posicion * 1000.0 - latencia_estimada_ms
		nodo.play(nombre_animacion)
		nodo.speed_scale = 0.0
		_animadores_deterministas[nodo] = {
			"epoch_ms": epoch_ms,
			"duracion": anim.length,
			"modo_loop": modo_loop,
		}

	if not _animadores_deterministas.is_empty():
		set_physics_process(true)

	if hubo_fallas:
		await get_tree().create_timer(0.2).timeout
		solicitar_sincronizacion_nivel()


func limpiar_animadores_deterministas() -> void:
	set_physics_process(false)
	for animador in _animadores_deterministas.keys():
		if is_instance_valid(animador):
			animador.speed_scale = 1.0
	_animadores_deterministas.clear()


# ---------- RPCS GENERALES DEL JUEGO ----------
@rpc("authority", "reliable")
func _rpc_recibir_nivel_cooperativo_host(nivel_host: int) -> void:
	nivel_cooperativo_host_recibido.emit(nivel_host)

func enviar_mi_personaje(indice_personaje: int) -> void:
	rpc("rpc_notificar_personaje", indice_personaje)

@rpc("any_peer", "call_local", "reliable")
func rpc_notificar_personaje(indice_personaje: int) -> void:
	var id_emisor := multiplayer.get_remote_sender_id()
	if id_emisor == 0:
		id_emisor = multiplayer.get_unique_id()

	_selecciones_personaje[id_emisor] = indice_personaje
	jugador_listo.emit(id_emisor, indice_personaje)

	if multiplayer.is_server() and _selecciones_personaje.size() >= 2:
		rpc("rpc_iniciar_nivel", _selecciones_personaje)

@rpc("authority", "call_local", "reliable")
func rpc_iniciar_nivel(selecciones: Dictionary) -> void:
	nivel_debe_iniciar.emit(selecciones)

func enviar_moneda_recogida(indice: int) -> void:
	rpc("rpc_moneda_recogida", indice)

@rpc("any_peer", "reliable")
func rpc_moneda_recogida(indice: int) -> void:
	moneda_remota_recogida.emit(indice)

func enviar_muerte() -> void:
	rpc("rpc_muerte")

@rpc("any_peer", "call_local", "reliable")
func rpc_muerte() -> void:
	var id_emisor := multiplayer.get_remote_sender_id()
	if id_emisor == 0:
		id_emisor = multiplayer.get_unique_id()
	muerte_remota_recibida.emit(id_emisor)

func enviar_siguiente_nivel() -> void:
	rpc("rpc_siguiente_nivel")

@rpc("any_peer", "call_local", "reliable")
func rpc_siguiente_nivel() -> void:
	siguiente_nivel_recibido.emit()

func enviar_saltar_cinematica() -> void:
	rpc("rpc_saltar_cinematica")

@rpc("any_peer", "call_local", "reliable")
func rpc_saltar_cinematica() -> void:
	saltar_cinematica_recibido.emit()

func enviar_reiniciar_nivel() -> void:
	rpc("rpc_reiniciar_nivel")

@rpc("any_peer", "call_local", "reliable")
func rpc_reiniciar_nivel() -> void:
	reiniciar_nivel_recibido.emit()

func enviar_salir() -> void:
	rpc("rpc_salir")

@rpc("any_peer", "call_local", "reliable")
func rpc_salir() -> void:
	salir_recibido.emit()

func enviar_abandonar_multijugador() -> void:
	if _abandonando_multijugador:
		return
	rpc("rpc_abandonar_multijugador")

@rpc("any_peer", "call_local", "reliable")
func rpc_abandonar_multijugador() -> void:
	if _abandonando_multijugador:
		return
	_abandonando_multijugador = true
	abandonar_multijugador_recibido.emit()

func enviar_nivel_elegido(ruta: String) -> void:
	rpc("rpc_nivel_elegido", ruta)

@rpc("authority", "call_local", "reliable")
func rpc_nivel_elegido(ruta: String) -> void:
	nivel_elegido_recibido.emit(ruta)

func enviar_pausa(pausado: bool) -> void:
	rpc("rpc_pausa", pausado)

@rpc("any_peer", "call_local", "reliable")
func rpc_pausa(pausado: bool) -> void:
	pausa_recibida.emit(pausado)

func enviar_salir_del_juego() -> void:
	_saliendo_intencionalmente = true
	rpc("rpc_salir_del_juego")

@rpc("any_peer", "reliable")
func rpc_salir_del_juego() -> void:
	var id_emisor := multiplayer.get_remote_sender_id()
	conexion_perdida.emit(id_emisor)

func enviar_trampa_caida(indice: int) -> void:
	rpc("rpc_trampa_caida", indice)

@rpc("any_peer", "call_local", "reliable")
func rpc_trampa_caida(indice: int) -> void:
	trampa_caida_recibida.emit(indice)

func enviar_enemigo_golpeado(indice: int, vida_restante: int) -> void:
	rpc("rpc_enemigo_golpeado", indice, vida_restante)

@rpc("authority", "reliable")
func rpc_enemigo_golpeado(indice: int, vida_restante: int) -> void:
	enemigo_golpeado_recibido.emit(indice, vida_restante)

func enviar_enemigo_muerto(indice: int) -> void:
	rpc("rpc_enemigo_muerto", indice)

@rpc("authority", "reliable")
func rpc_enemigo_muerto(indice: int) -> void:
	enemigo_muerto_recibido.emit(indice)

func enviar_nivel_cooperativo_actualizado(nivel: int) -> void:
	if not multiplayer.is_server():
		return
	rpc("_rpc_recibir_nivel_cooperativo_host", nivel)

func enviar_rebote_jugador(jugador_id: int) -> void:
	rpc("rpc_rebote_jugador", jugador_id)

@rpc("any_peer", "call_local", "reliable")
func rpc_rebote_jugador(jugador_id: int) -> void:
	rebote_jugador_recibido.emit(jugador_id)


# ---------- UTILIDADES Y LIMPIEZA ----------
func soy_host() -> bool:
	if multiplayer.multiplayer_peer == null:
		# Si no hay red inicializada, por defecto tratamos como autoridad local (singleplayer)
		return true
	return multiplayer.is_server()
func mi_id() -> int:
	return multiplayer.get_unique_id()

func obtener_ping_ms() -> float:
	if multiplayer.multiplayer_peer == null:
		return -1.0
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null:
		return -1.0
	var ids := multiplayer.get_peers()
	if ids.is_empty():
		return -1.0
	var enet_peer := peer.get_peer(ids[0])
	if enet_peer == null:
		return -1.0
	return enet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)

func reiniciar_estado_partida() -> void:
	_selecciones_personaje.clear()
	_abandonando_multijugador = false

func cerrar_conexion() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	_saliendo_intencionalmente = true
	var peer_anterior := multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = null
	peer_anterior.close()
	detener_host()
	dejar_de_buscar()
	reiniciar_estado_partida()
	limpiar_animadores_deterministas()
	_saliendo_intencionalmente = false
