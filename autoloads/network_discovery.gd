extends Node

enum EstadoConexion { DESCONECTADO, CONECTANDO, CONECTADO, DESCONECTANDO, ERROR }

const PUERTO_DESCUBRIMIENTO := 8910
const PUERTO_JUEGO := 7777
const INTERVALO_BROADCAST := 1.0
const IDENTIFICADOR := "PATH_CRYSTAL"
const MAX_REINTENTOS_CONEXION := 3
const TIMEOUT_CONEXION_MS := 5000
const TIMEOUT_SIN_PEERS := 3.0

# --- Sincronización de reloj ---
const INTERVALO_RESINCRONIZACION_RELOJ := 10.0
const MUESTRAS_RELOJ := 5
const CORRECCION_RELOJ_MS_POR_SEG := 15.0  # era 3.0 — corrección más rápida

# --- Animadores ---
const UMBRAL_CORRECCION_ANIM_MS := 35.0
const INTERVALO_REVISION_ANIM := 0.25

# --- Enemigos ---
const FRECUENCIA_ENEMIGOS := 15.0
const DISTANCIA_RELEVANTE := 900.0

# --- Retardo Adaptativo ---
const RETARDO_MIN_MS := 50.0   # era 60 — más agresivo en red local
const RETARDO_MAX_MS := 250.0  # era 260
const MARGEN_SEGURIDAD_MS := 20.0  # era 30 — menos colchón innecesario

# --- Señales ---
signal partida_encontrada(ip: String, nombre_partida: String)
signal conexion_exitosa
signal conexion_fallida
signal conexion_perdida(id: int)
signal jugador_remoto_conectado(id: int)
signal jugador_listo(id: int, indice_personaje: int)
signal nivel_debe_iniciar(selecciones: Dictionary)
signal posicion_remota_recibida(id_emisor: int, t_red: float, pos: Vector2, animacion: String, flip_h: bool)
signal muerte_remota_recibida(id_emisor: int)
signal muerte_forzada_recibida(id_jugador: int)
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
signal estado_conexion_cambiado(nuevo_estado: int)
signal reloj_sincronizado

# --- Grupos ---
const GRUPO_ANIMADORES_SINCRONIZABLES := "animadores_sincronizables"
const GRUPO_TRAMPAS_CAIDA_SINCRONIZABLES := "trampas_caida_sincronizables"
const GRUPO_ENEMIGOS_SINCRONIZABLES := "enemigos_sincronizables"

# --- Estado ---
var _socket_broadcast: PacketPeerUDP
var _socket_escucha: PacketPeerUDP
var _timer_broadcast: Timer
var _timer_timeout_conexion: Timer

var _es_host := false
var _nombre_partida := ""
var _partidas_ya_vistas := {}
var _selecciones_personaje := {}
var _saliendo_intencionalmente := false
var _abandonando_multijugador := false

var _estado: int = EstadoConexion.DESCONECTADO
var _ip_objetivo := ""
var _intentos_conexion := 0

var nivel_cooperativo_actual: int = 1

var _animadores_deterministas: Dictionary = {}
var _generacion_sincronizacion := 0
var _acumulador_revision_anim := 0.0

# --- Estado Reloj ---
var _offset_reloj_ms := 0.0
var _offset_objetivo_ms := 0.0
var _reloj_listo := false
var _muestras_reloj: Array[Dictionary] = []
var _pings_reloj_pendientes: Dictionary = {}
var _contador_muestra_reloj := 0
var _timer_reloj: Timer

# --- Estado Enemigos e Interpolación Adaptativa ---
var _acumulador_enemigos := 0.0
var _interpoladores_enemigos: Dictionary = {}
var _cache_lista_enemigos: Array = []  # caché para evitar get_nodes_in_group cada frame
var _retardo_interp_ms := 90.0
var _edades_recientes: Array[float] = []

# --- Detección de desconexión del host ---
var _tiempo_sin_peers := 0.0


func _ready() -> void:
	set_process(false)
	set_physics_process(false)

	_timer_broadcast = Timer.new()
	_timer_broadcast.wait_time = INTERVALO_BROADCAST
	_timer_broadcast.timeout.connect(_enviar_broadcast)
	add_child(_timer_broadcast)

	_timer_timeout_conexion = Timer.new()
	_timer_timeout_conexion.one_shot = true
	_timer_timeout_conexion.wait_time = TIMEOUT_CONEXION_MS / 1000.0
	_timer_timeout_conexion.timeout.connect(_on_timeout_conexion)
	add_child(_timer_timeout_conexion)

	_timer_reloj = Timer.new()
	_timer_reloj.wait_time = INTERVALO_RESINCRONIZACION_RELOJ
	_timer_reloj.timeout.connect(_enviar_ping_reloj)
	add_child(_timer_reloj)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _actualizar_process() -> void:
	set_process(_socket_escucha != null or multiplayer.multiplayer_peer != null)


func _cambiar_estado(nuevo: int) -> void:
	if _estado == nuevo:
		return
	_estado = nuevo
	estado_conexion_cambiado.emit(nuevo)


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
		rpc_id(id, "_rpc_recibir_nivel_cooperativo_host", nivel_cooperativo_actual)


func _on_peer_disconnected(id: int) -> void:
	_selecciones_personaje.erase(id)
	if not _saliendo_intencionalmente and not _abandonando_multijugador:
		conexion_perdida.emit(id)


func _on_server_disconnected() -> void:
	if not _saliendo_intencionalmente:
		_cambiar_estado(EstadoConexion.ERROR)
		conexion_perdida.emit(0)


func _on_timeout_conexion() -> void:
	if _estado == EstadoConexion.CONECTANDO:
		_intentar_reconectar()


# ═════════════════════════════════════════════════════════════
#  RELOJ DE RED COMPARTIDO & RETARDO ADAPTATIVO
# ═════════════════════════════════════════════════════════════
func tiempo_red_ms() -> float:
	return float(Time.get_ticks_msec()) + _offset_reloj_ms


func reloj_listo() -> bool:
	return _reloj_listo


func retardo_interpolacion_ms() -> float:
	return _retardo_interp_ms


func registrar_llegada(t_red_paquete: float) -> void:
	var edad: float = tiempo_red_ms() - t_red_paquete
	_edades_recientes.append(edad)
	if _edades_recientes.size() > 20:  # era 30 — menos memoria, reacciona más rápido
		_edades_recientes.pop_front()
	# Percentil 90 en vez del máximo absoluto: ignoramos outliers y el retardo
	# baja más rápido cuando la red mejora.
	var ordenadas := _edades_recientes.duplicate()
	ordenadas.sort()
	var idx_p90 := int(ordenadas.size() * 0.9)
	if idx_p90 >= ordenadas.size():
		idx_p90 = ordenadas.size() - 1
	var p90: float = ordenadas[idx_p90]
	var objetivo: float = clampf(p90 + MARGEN_SEGURIDAD_MS, RETARDO_MIN_MS, RETARDO_MAX_MS)
	if objetivo > _retardo_interp_ms:
		# Sube inmediato para evitar que el buffer se vacíe y el personaje se pare
		_retardo_interp_ms = objetivo
	else:
		# Baja MUY lento (0.005) para evitar tirones (rubber-banding). 
		# Si baja rápido, el tiempo objetivo acelera y la velocidad visual del personaje fluctúa.
		_retardo_interp_ms = lerpf(_retardo_interp_ms, objetivo, 0.005)


func iniciar_sincronizacion_reloj() -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		_offset_reloj_ms = 0.0
		_offset_objetivo_ms = 0.0
		_reloj_listo = true
		reloj_sincronizado.emit()
		return

	_muestras_reloj.clear()
	_pings_reloj_pendientes.clear()
	_reloj_listo = false
	_enviar_ping_reloj()
	_timer_reloj.start()


func _enviar_ping_reloj() -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		return
	_contador_muestra_reloj += 1
	_pings_reloj_pendientes[_contador_muestra_reloj] = float(Time.get_ticks_msec())
	rpc_id(1, "_rpc_ping_reloj", _contador_muestra_reloj)


@rpc("any_peer", "reliable")
func _rpc_ping_reloj(id_muestra: int) -> void:
	if not multiplayer.is_server():
		return
	rpc_id(multiplayer.get_remote_sender_id(), "_rpc_pong_reloj",
		id_muestra, float(Time.get_ticks_msec()))


@rpc("authority", "reliable")
func _rpc_pong_reloj(id_muestra: int, tiempo_host: float) -> void:
	if not _pings_reloj_pendientes.has(id_muestra):
		return
	var t_envio: float = _pings_reloj_pendientes[id_muestra]
	_pings_reloj_pendientes.erase(id_muestra)
	var ahora := float(Time.get_ticks_msec())
	var rtt := ahora - t_envio

	var offset := tiempo_host - (ahora - rtt * 0.5)
	_muestras_reloj.append({"rtt": rtt, "offset": offset})

	while _muestras_reloj.size() > MUESTRAS_RELOJ:
		_muestras_reloj.pop_front()

	_aplicar_mejor_offset()

	if _muestras_reloj.size() < MUESTRAS_RELOJ:
		await get_tree().create_timer(0.1).timeout
		_enviar_ping_reloj()


func _aplicar_mejor_offset() -> void:
	if _muestras_reloj.is_empty():
		return
	var mejor: Dictionary = _muestras_reloj[0]
	for m in _muestras_reloj:
		if m["rtt"] < mejor["rtt"]:
			mejor = m

	_offset_objetivo_ms = mejor["offset"]
	# Umbral de 80 ms (era 250): si el error es mayor saltamos directo para
	# evitar deslizamientos lentos que se ven como teleports retardados.
	if not _reloj_listo or absf(_offset_objetivo_ms - _offset_reloj_ms) > 80.0:
		_offset_reloj_ms = _offset_objetivo_ms
		if not _reloj_listo:
			_reloj_listo = true
			reloj_sincronizado.emit()


# ---------- HOST ----------
func iniciar_partida(nombre_partida: String) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PUERTO_JUEGO, 2)
	if error != OK:
		push_error("No se pudo crear el servidor: %s" % error)
		_cambiar_estado(EstadoConexion.ERROR)
		return false

	var host: ENetConnection = peer.get_host()
	if host:
		host.bandwidth_limit(0, 0)

	multiplayer.multiplayer_peer = peer
	ControladorGlobal.actualizar_rol_jugador_red()
	_es_host = true
	_nombre_partida = nombre_partida
	_cambiar_estado(EstadoConexion.CONECTADO)

	_socket_broadcast = PacketPeerUDP.new()
	_socket_broadcast.set_broadcast_enabled(true)
	_socket_broadcast.set_dest_address("255.255.255.255", PUERTO_DESCUBRIMIENTO)
	_timer_broadcast.start()

	iniciar_sincronizacion_reloj()
	_actualizar_process()
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
	_actualizar_process()


func dejar_de_buscar() -> void:
	if _socket_escucha:
		_socket_escucha.close()
		_socket_escucha = null
	_actualizar_process()


func conectarse_a(ip: String) -> void:
	dejar_de_buscar()
	_ip_objetivo = ip
	_intentos_conexion = 0
	_intentar_conectar()


func _intentar_conectar() -> void:
	_intentos_conexion += 1
	_cambiar_estado(EstadoConexion.CONECTANDO)

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(_ip_objetivo, PUERTO_JUEGO)
	if error != OK:
		_intentar_reconectar()
		return

	var host: ENetConnection = peer.get_host()
	if host:
		host.bandwidth_limit(0, 0)

	multiplayer.multiplayer_peer = peer

	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)

	_timer_timeout_conexion.start()


func _intentar_reconectar() -> void:
	_timer_timeout_conexion.stop()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
		ControladorGlobal.actualizar_rol_jugador_red()

	if _intentos_conexion >= MAX_REINTENTOS_CONEXION:
		_cambiar_estado(EstadoConexion.ERROR)
		conexion_fallida.emit()
		return

	await get_tree().create_timer(0.5).timeout
	_intentar_conectar()


func _on_connected_to_server() -> void:
	_timer_timeout_conexion.stop()
	_cambiar_estado(EstadoConexion.CONECTADO)
	ControladorGlobal.actualizar_rol_jugador_red()
	_tiempo_sin_peers = 0.0
	iniciar_sincronizacion_reloj()
	_actualizar_process()
	conexion_exitosa.emit()


func _on_connection_failed() -> void:
	_timer_timeout_conexion.stop()
	_intentar_reconectar()


func _process(delta: float) -> void:
	if _offset_reloj_ms != _offset_objetivo_ms:
		_offset_reloj_ms = move_toward(_offset_reloj_ms, _offset_objetivo_ms, CORRECCION_RELOJ_MS_POR_SEG * delta)

	# --- Búsqueda de partidas ---
	if _socket_escucha != null:
		while _socket_escucha.get_available_packet_count() > 0:
			var datos := _socket_escucha.get_packet().get_string_from_utf8()
			var ip_origen := _socket_escucha.get_packet_ip()
			var partes := datos.split("|")
			if partes.size() == 3 and partes[0] == IDENTIFICADOR:
				if not _partidas_ya_vistas.has(ip_origen):
					_partidas_ya_vistas[ip_origen] = true
					partida_encontrada.emit(ip_origen, partes[1])

	# --- Detección de host caído ---
	if multiplayer.multiplayer_peer == null:
		_tiempo_sin_peers = 0.0
		return

	if not multiplayer.is_server():
		if multiplayer.get_peers().size() == 0:
			_tiempo_sin_peers += delta
			if _tiempo_sin_peers >= TIMEOUT_SIN_PEERS:
				_tiempo_sin_peers = 0.0
				print("[NetworkDiscovery] Host inactivo durante %.1fs. Desconectando cliente." % TIMEOUT_SIN_PEERS)
				_on_server_disconnected()
		else:
			_tiempo_sin_peers = 0.0

	# --- Sincronización de Enemigos ---
	if multiplayer.is_server():
		_acumulador_enemigos += delta
		if _acumulador_enemigos >= 1.0 / FRECUENCIA_ENEMIGOS:
			_acumulador_enemigos = 0.0
			_enviar_estado_enemigos()
	elif not _interpoladores_enemigos.is_empty():
		# Usamos la caché de la lista para no llamar get_nodes_in_group cada frame
		if _cache_lista_enemigos.is_empty():
			_cache_lista_enemigos = get_tree().get_nodes_in_group(GRUPO_ENEMIGOS_SINCRONIZABLES)
		for idx in _interpoladores_enemigos.keys():
			if idx < 0 or idx >= _cache_lista_enemigos.size():
				continue
			var e = _cache_lista_enemigos[idx]
			if not is_instance_valid(e):
				continue
			var estado: Dictionary = (_interpoladores_enemigos[idx] as InterpoladorRed).muestrear()
			if e.has_method("aplicar_estado_red"):
				e.aplicar_estado_red(estado["pos"], estado["flip"], estado["anim"])
			else:
				e.global_position = estado["pos"]


# ═════════════════════════════════════════════════════════════
#  POSICIONES JUGADOR
# ═════════════════════════════════════════════════════════════
func enviar_posicion(pos: Vector2, animacion: String, flip_h: bool) -> void:
	rpc("rpc_posicion", tiempo_red_ms(), pos, animacion, flip_h)

@rpc("any_peer", "unreliable_ordered")
func rpc_posicion(t_red: float, pos: Vector2, animacion: String, flip_h: bool) -> void:
	registrar_llegada(t_red)
	var id_emisor := multiplayer.get_remote_sender_id()
	posicion_remota_recibida.emit(id_emisor, t_red, pos, animacion, flip_h)


# ═════════════════════════════════════════════════════════════
#  ENEMIGOS (ENPAQUETADO MASIVO)
# ═════════════════════════════════════════════════════════════
func _enviar_estado_enemigos() -> void:
	var lista := get_tree().get_nodes_in_group(GRUPO_ENEMIGOS_SINCRONIZABLES)
	if lista.is_empty():
		return
	var referencias := get_tree().get_nodes_in_group("personajes")
	var indices := PackedInt32Array()
	var posiciones := PackedFloat32Array()
	var flips := PackedByteArray()
	var anims := PackedStringArray()

	for i in lista.size():
		var e = lista[i] as Node2D
		if not is_instance_valid(e) or not e.visible:
			continue
		if not _es_relevante(e, referencias):
			continue
		indices.append(i)
		posiciones.append(e.global_position.x)
		posiciones.append(e.global_position.y)
		var estado: Dictionary = e.estado_red() if e.has_method("estado_red") else {}
		flips.append(1 if estado.get("flip", false) else 0)
		anims.append(estado.get("anim", ""))

	if indices.is_empty():
		return
	rpc("rpc_estado_enemigos", tiempo_red_ms(), indices, posiciones, flips, anims)


func _es_relevante(nodo: Node2D, referencias: Array) -> bool:
	for p in referencias:
		if is_instance_valid(p) and nodo.global_position.distance_to(p.global_position) < DISTANCIA_RELEVANTE:
			return true
	return false


@rpc("authority", "unreliable_ordered")
func rpc_estado_enemigos(t_red: float, indices: PackedInt32Array, posiciones: PackedFloat32Array, flips: PackedByteArray, anims: PackedStringArray) -> void:
	registrar_llegada(t_red)
	for k in indices.size():
		var idx: int = indices[k]
		if not _interpoladores_enemigos.has(idx):
			_interpoladores_enemigos[idx] = InterpoladorRed.new()
			_cache_lista_enemigos.clear()  # invalidar caché al añadir nuevo enemigo
		var interp: InterpoladorRed = _interpoladores_enemigos[idx]
		interp.agregar(t_red, Vector2(posiciones[k * 2], posiciones[k * 2 + 1]), anims[k], flips[k] == 1)


## Envía el estado de UN solo enemigo por índice.
## Lo usan enemigos que gestionan su propio tickrate (ej. jefe_final.gd).
## Reutiliza el mismo RPC batch para no crear un canal extra.
func enviar_posicion_enemigo(indice: int, pos: Vector2, flip_h: bool, animacion: String) -> void:
	if not multiplayer.is_server():
		return
	var indices := PackedInt32Array([indice])
	var posiciones := PackedFloat32Array([pos.x, pos.y])
	var flips := PackedByteArray([1 if flip_h else 0])
	var anims := PackedStringArray([animacion])
	rpc("rpc_estado_enemigos", tiempo_red_ms(), indices, posiciones, flips, anims)


func enviar_evento_animacion(evento: String) -> void:
	rpc("rpc_evento_animacion", evento)

@rpc("any_peer", "reliable")
func rpc_evento_animacion(evento: String) -> void:
	evento_animacion_recibido.emit(evento)


# ═════════════════════════════════════════════════════════════
#  ANIMADORES DETERMINISTAS (OPTIMIZADOS)
# ═════════════════════════════════════════════════════════════
func _physics_process(delta: float) -> void:
	if _animadores_deterministas.is_empty():
		set_physics_process(false)
		return
	_acumulador_revision_anim += delta
	if _acumulador_revision_anim < INTERVALO_REVISION_ANIM:
		return
	_acumulador_revision_anim = 0.0

	var ahora := tiempo_red_ms()
	for animador in _animadores_deterministas.keys():
		if not is_instance_valid(animador):
			_animadores_deterministas.erase(animador)
			continue
		var d: Dictionary = _animadores_deterministas[animador]
		if d["duracion"] <= 0.0:
			continue

		var esperada: float = _posicion_actual_animador(d, ahora)
		var error: float = esperada - animador.current_animation_position

		if d["modo_loop"] != Animation.LOOP_PINGPONG:
			var mitad: float = d["duracion"] * 0.5
			while error > mitad:
				error -= d["duracion"]
			while error < -mitad:
				error += d["duracion"]

		if absf(error) * 1000.0 > UMBRAL_CORRECCION_ANIM_MS:
			animador.seek(esperada, true)


func _posicion_actual_animador(datos_anim: Dictionary, ahora_ms: float) -> float:
	if datos_anim.duracion <= 0.0:
		return 0.0
	var transcurrido: float = (ahora_ms - datos_anim.epoch_ms) / 1000.0
	if datos_anim.modo_loop == Animation.LOOP_PINGPONG:
		var ciclo: float = datos_anim.duracion * 2.0
		var t: float = fmod(transcurrido, ciclo)
		if t < 0.0: t += ciclo
		return t if t <= datos_anim.duracion else ciclo - t
	var posicion: float = fmod(transcurrido, datos_anim.duracion)
	if posicion < 0.0: posicion += datos_anim.duracion
	return posicion


func inicializar_animadores_host() -> void:
	var ahora := tiempo_red_ms()
	var lista := get_tree().get_nodes_in_group(GRUPO_ANIMADORES_SINCRONIZABLES)
	lista.sort_custom(func(a, b): return str(a.get_path()) < str(b.get_path()))
	for i in lista.size():
		var animador = lista[i] as AnimationPlayer
		if not animador or animador.current_animation == "":
			continue
		var anim := animador.get_animation(animador.current_animation)
		if not anim:
			continue
		var posicion_inicial: float = animador.current_animation_position
		animador.seek(posicion_inicial, true)
		_animadores_deterministas[animador] = {
			"epoch_ms": ahora - posicion_inicial * 1000.0,
			"duracion": anim.length,
			"modo_loop": anim.loop_mode,
		}
	if not _animadores_deterministas.is_empty():
		set_physics_process(true)


func solicitar_sincronizacion_nivel() -> void:
	if not multiplayer.is_server() and not _reloj_listo:
		await reloj_sincronizado
	_generacion_sincronizacion += 1
	rpc_id(1, "_rpc_solicitar_sincronizacion_nivel", _generacion_sincronizacion)


@rpc("any_peer", "reliable")
func _rpc_solicitar_sincronizacion_nivel(generacion: int) -> void:
	if not multiplayer.is_server():
		return
	var id_emisor := multiplayer.get_remote_sender_id()
	var lista := get_tree().get_nodes_in_group(GRUPO_ANIMADORES_SINCRONIZABLES)
	lista.sort_custom(func(a, b): return str(a.get_path()) < str(b.get_path()))
	var datos: Array = []
	for i in lista.size():
		var animador = lista[i] as AnimationPlayer
		if not animador or animador.current_animation == "":
			continue
		var anim := animador.get_animation(animador.current_animation)
		if not anim:
			continue

		if not _animadores_deterministas.has(animador):
			_animadores_deterministas[animador] = {
				"epoch_ms": tiempo_red_ms() - animador.current_animation_position * 1000.0,
				"duracion": anim.length,
				"modo_loop": anim.loop_mode,
			}

		var d: Dictionary = _animadores_deterministas[animador]
		datos.append({
			"indice": i,
			"animacion": animador.current_animation,
			"epoch": d["epoch_ms"],
			"duracion": d["duracion"],
			"modo_loop": d["modo_loop"],
		})
	set_physics_process(not _animadores_deterministas.is_empty())
	rpc_id(id_emisor, "_rpc_recibir_sincronizacion_nivel", datos, generacion)


@rpc("authority", "reliable")
func _rpc_recibir_sincronizacion_nivel(datos: Array, generacion: int) -> void:
	if generacion != _generacion_sincronizacion:
		return
	var lista := get_tree().get_nodes_in_group(GRUPO_ANIMADORES_SINCRONIZABLES)
	lista.sort_custom(func(a, b): return str(a.get_path()) < str(b.get_path()))
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
		nodo.play(entrada["animacion"])
		_animadores_deterministas[nodo] = {
			"epoch_ms": entrada["epoch"],
			"duracion": entrada["duracion"],
			"modo_loop": entrada["modo_loop"],
		}
	if not _animadores_deterministas.is_empty():
		set_physics_process(true)
	if hubo_fallas:
		await get_tree().create_timer(0.2).timeout
		solicitar_sincronizacion_nivel()


func limpiar_animadores_deterministas() -> void:
	set_physics_process(false)
	_animadores_deterministas.clear()


# ═════════════════════════════════════════════════════════════
#  RPCs GENERALES
# ═════════════════════════════════════════════════════════════
func actualizar_nivel_cooperativo(nivel: int) -> void:
	nivel_cooperativo_actual = nivel
	if multiplayer.is_server():
		rpc("_rpc_recibir_nivel_cooperativo_host", nivel)


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

func forzar_muerte_jugador(id_jugador: int) -> void:
	if not soy_host():
		return
	rpc("rpc_forzar_muerte", id_jugador)

@rpc("authority", "call_local", "reliable")
func rpc_forzar_muerte(id_jugador: int) -> void:
	muerte_forzada_recibida.emit(id_jugador)

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
	if _abandonando_multijugador: return
	rpc("rpc_abandonar_multijugador")

@rpc("any_peer", "call_local", "reliable")
func rpc_abandonar_multijugador() -> void:
	if _abandonando_multijugador: return
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
	actualizar_nivel_cooperativo(nivel)

func enviar_rebote_jugador(jugador_id: int) -> void:
	rpc("rpc_rebote_jugador", jugador_id)

@rpc("any_peer", "call_local", "reliable")
func rpc_rebote_jugador(jugador_id: int) -> void:
	rebote_jugador_recibido.emit(jugador_id)


# ═════════════════════════════════════════════════════════════
#  UTILIDADES
# ═════════════════════════════════════════════════════════════
func soy_host() -> bool:
	if multiplayer.multiplayer_peer == null:
		return true
	return multiplayer.is_server()

func mi_id() -> int:
	return multiplayer.get_unique_id()

func estado_actual() -> int:
	return _estado

func obtener_ping_ms() -> float:
	if multiplayer.multiplayer_peer == null:
		return -1.0
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null: return -1.0
	var ids := multiplayer.get_peers()
	if ids.is_empty(): return -1.0
	var enet_peer := peer.get_peer(ids[0])
	if enet_peer == null: return -1.0
	return enet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)

func reiniciar_estado_partida() -> void:
	_selecciones_personaje.clear()
	_abandonando_multijugador = false
	_tiempo_sin_peers = 0.0

func cerrar_conexion() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	_saliendo_intencionalmente = true
	if _timer_reloj:
		_timer_reloj.stop()
	_reloj_listo = false
	_offset_reloj_ms = 0.0
	_offset_objetivo_ms = 0.0
	_interpoladores_enemigos.clear()
	_cache_lista_enemigos.clear()
	_edades_recientes.clear()
	_retardo_interp_ms = RETARDO_MIN_MS  # resetear para la próxima sesión

	var peer_anterior := multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = null
	peer_anterior.close()

	detener_host()
	dejar_de_buscar()
	reiniciar_estado_partida()
	limpiar_animadores_deterministas()
	_cambiar_estado(EstadoConexion.DESCONECTADO)
	ControladorGlobal.actualizar_rol_jugador_red()
	_saliendo_intencionalmente = false
	_actualizar_process()
