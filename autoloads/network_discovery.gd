extends Node

# --- Configuración ---
const PUERTO_DESCUBRIMIENTO := 8910  # puerto solo para "anunciar" partidas
const PUERTO_JUEGO := 7777           # puerto real del ENetMultiplayerPeer
const INTERVALO_BROADCAST := 1.0     # cada cuánto anuncia el host (segundos)
const IDENTIFICADOR := "PATH_CRYSTAL" # para filtrar paquetes de otros juegos en la red

# --- Señales que la UI escucha ---
signal partida_encontrada(ip: String, nombre_partida: String)
signal conexion_exitosa
signal conexion_fallida
signal jugador_remoto_conectado(id: int)          # útil para que el host reaccione a que se unió alguien
signal jugador_listo(id: int, indice_personaje: int) # se emite en cuanto CUALQUIER peer (local o remoto) elige
signal nivel_debe_iniciar(selecciones: Dictionary)   # {id_peer: indice_personaje}, arranca el nivel
signal posicion_remota_recibida(id_emisor: int, pos: Vector2, vel: Vector2, animacion: String, flip_h: bool)
var _socket_broadcast: PacketPeerUDP
var _socket_escucha: PacketPeerUDP
var _timer_broadcast: Timer
var _es_host := false
var _nombre_partida := ""
var _partidas_ya_vistas := {} # ip -> true, para no repetir señales
var _selecciones_personaje := {} # id_peer -> indice_personaje
signal muerte_remota_recibida(id_emisor: int)
signal evento_animacion_recibido(evento: String)  # dash / doble_salto puntuales

func _ready() -> void:
	_timer_broadcast = Timer.new()
	_timer_broadcast.wait_time = INTERVALO_BROADCAST
	_timer_broadcast.timeout.connect(_enviar_broadcast)
	add_child(_timer_broadcast)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_disconnected(id: int) -> void:
	_selecciones_personaje.erase(id)
	if not _saliendo_intencionalmente and not _abandonando_multijugador:
		conexion_perdida.emit(id)

# Si eres el cliente y el host cierra la partida (o se cae),
# esto es lo que te avisa (peer_disconnected no siempre cubre este caso)
func _on_server_disconnected() -> void:
	if not _saliendo_intencionalmente:
		conexion_perdida.emit(0)

# ---------- HOST ----------
func iniciar_partida(nombre_partida: String) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PUERTO_JUEGO, 2) # 2 jugadores max
	if error != OK:
		push_error("No se pudo crear el servidor: %s" % error)
		return false

	multiplayer.multiplayer_peer = peer
	_es_host = true
	_nombre_partida = nombre_partida

	_socket_broadcast = PacketPeerUDP.new()
	_socket_broadcast.set_broadcast_enabled(true)
	_socket_broadcast.set_dest_address("255.255.255.255", PUERTO_DESCUBRIMIENTO)
	_timer_broadcast.start()

	return true

func enviar_posicion(pos: Vector2, vel: Vector2, animacion: String, flip_h: bool) -> void:
	rpc("rpc_posicion", pos, vel, animacion, flip_h)

@rpc("any_peer", "unreliable_ordered")
func rpc_posicion(pos: Vector2, vel: Vector2, animacion: String, flip_h: bool) -> void:
	var id_emisor := multiplayer.get_remote_sender_id()
	posicion_remota_recibida.emit(id_emisor, pos, vel, animacion, flip_h)

# Eventos puntuales de animación (dash, doble salto) — reliable porque
# se disparan una sola vez, no como parte del stream continuo de posición.
func enviar_evento_animacion(evento: String) -> void:
	rpc("rpc_evento_animacion", evento)

@rpc("any_peer", "reliable")
func rpc_evento_animacion(evento: String) -> void:
	evento_animacion_recibido.emit(evento)

func _enviar_broadcast() -> void:
	if not _es_host:
		return
	var mensaje := "%s|%s|%d" % [IDENTIFICADOR, _nombre_partida, PUERTO_JUEGO]
	_socket_broadcast.put_packet(mensaje.to_utf8_buffer())
func detener_host() -> void:
	_es_host = false
	_timer_broadcast.stop()
	if _socket_broadcast:
		_socket_broadcast.close()
		_socket_broadcast = null   # NUEVO: evita referencia colgante
# ---------- CLIENTE (busca partidas) ----------
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

func _process(_delta: float) -> void:
	# --- Búsqueda de partidas por UDP (ya existía) ---
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


# Calcula la posición exacta (en segundos) que le corresponde a un animador
# determinista para un instante dado, según su epoch/duración/modo de loop.
# Reutilizada tanto por _physics_process (para el seek() visual) como por
# el host al responder un pedido de sincronización (para no depender del
# valor cacheado de current_animation_position, que solo se refresca una
# vez por tick de física y puede quedar desfasado hasta ~16ms).
func _posicion_actual_animador(datos_anim: Dictionary, ahora_ms: float) -> float:
	if datos_anim.duracion <= 0.0:
		return 0.0
	var transcurrido: float = (ahora_ms - datos_anim.epoch_ms) / 1000.0
	if datos_anim.modo_loop == Animation.LOOP_PINGPONG:
		# Ping-pong: la animación va de 0 a duración y VUELVE a 0,
		# en vez de saltar de golpe al inicio. Un ciclo completo
		# dura el doble del clip (ida + vuelta).
		var ciclo: float = datos_anim.duracion * 2.0
		var t: float = fmod(transcurrido, ciclo)
		if t < 0.0:
			t += ciclo
		if t <= datos_anim.duracion:
			return t          # yendo de 0 -> duración
		else:
			return ciclo - t  # volviendo de duración -> 0
	else:
		var posicion: float = fmod(transcurrido, datos_anim.duracion)
		if posicion < 0.0:
			posicion += datos_anim.duracion
		return posicion

func _physics_process(_delta: float) -> void:
	# --- Reproducción determinista de animadores sincronizados ---
	# IMPORTANTE: esto va en _physics_process, NO en _process. Las
	# plataformas son AnimatableBody2D: su posición "real" para la
	# simulación física solo se actualiza en el tick de física. Si el
	# seek() corre en _process (idle), el cuerpo físico nunca se entera
	# del cambio y queda visualmente clavado, aunque el AnimationPlayer
	# internamente sí tenga la posición correcta.
	#
	# Corre igual en host y en cliente: ambos calculan la posición como
	# función pura del reloj del sistema, nadie avanza "solo" por delta.
	if not _animadores_deterministas.is_empty():
		var ahora := Time.get_ticks_msec()
		for animador in _animadores_deterministas.keys():
			if not is_instance_valid(animador):
				_animadores_deterministas.erase(animador)
				continue
			var datos_anim = _animadores_deterministas[animador]
			var posicion := _posicion_actual_animador(datos_anim, ahora)
			animador.seek(posicion, true)

# ---------- CLIENTE (se conecta a una partida elegida) ----------
func conectarse_a(ip: String) -> void:
	dejar_de_buscar()

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ip, PUERTO_JUEGO)
	if error != OK:
		conexion_fallida.emit()
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func(): conexion_exitosa.emit())
	multiplayer.connection_failed.connect(func(): conexion_fallida.emit())

# ---------- ciclo de vida de conexión ----------
func _on_peer_connected(id: int) -> void:
	print("Se conectó el jugador con id: ", id)
	jugador_remoto_conectado.emit(id)

func soy_host() -> bool:
	return multiplayer.is_server()

func mi_id() -> int:
	return multiplayer.get_unique_id()

# Ping actual con el otro jugador, en milisegundos. Devuelve -1.0 si no hay
# conexión activa. ENet ya mide esto internamente (es parte del protocolo,
# no hace falta un sistema de ping propio con RPCs).
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
	# Llamar antes de volver a jugar otra partida (menú → nueva selección)
	_selecciones_personaje.clear()
	_abandonando_multijugador = false

# ---------- sincronización de selección de personaje ----------
# Cualquier peer llama a esto localmente cuando confirma su personaje.
func enviar_mi_personaje(indice_personaje: int) -> void:
	rpc("rpc_notificar_personaje", indice_personaje)

@rpc("any_peer", "call_local", "reliable")
func rpc_notificar_personaje(indice_personaje: int) -> void:
	var id_emisor := multiplayer.get_remote_sender_id()
	if id_emisor == 0:
		# call_local: la ejecución local no tiene "remitente remoto", es uno mismo
		id_emisor = multiplayer.get_unique_id()

	_selecciones_personaje[id_emisor] = indice_personaje
	jugador_listo.emit(id_emisor, indice_personaje)

	# Solo el host decide cuándo ya están listos los dos y arranca el nivel
	if multiplayer.is_server() and _selecciones_personaje.size() >= 2:
		rpc("rpc_iniciar_nivel", _selecciones_personaje)

@rpc("authority", "call_local", "reliable")
func rpc_iniciar_nivel(selecciones: Dictionary) -> void:
	nivel_debe_iniciar.emit(selecciones)

signal moneda_remota_recogida(indice: int)

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
		# call_local: la ejecución local no tiene "remitente remoto", es uno mismo
		id_emisor = multiplayer.get_unique_id()
	muerte_remota_recibida.emit(id_emisor)

signal siguiente_nivel_recibido

func enviar_siguiente_nivel() -> void:
	rpc("rpc_siguiente_nivel")

@rpc("any_peer", "call_local", "reliable")
func rpc_siguiente_nivel() -> void:
	siguiente_nivel_recibido.emit()

signal reiniciar_nivel_recibido
signal salir_recibido
signal conexion_perdida(id: int)   # el otro jugador se desconectó sin avisar
signal saltar_cinematica_recibido
var _saliendo_intencionalmente := false   # distingue salida ordenada de caída de red
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

# Cierre ordenado de la conexión de red (llamar SIEMPRE que se
# abandone una partida en red, tanto por salida voluntaria como por
# desconexión detectada del otro jugador)
func cerrar_conexion() -> void:
	if multiplayer.multiplayer_peer == null:
		return  # ya se cerró, no hacer nada más
	_saliendo_intencionalmente = true
	var peer_anterior := multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = null   # desvincula primero de la MultiplayerAPI
	peer_anterior.close()                 # ahora sí cerramos el peer ya desvinculado
	detener_host()
	reiniciar_estado_partida()
	limpiar_animadores_deterministas()    # no arrastrar animadores de la partida anterior
	_saliendo_intencionalmente = false

signal nivel_elegido_recibido(ruta: String)
signal abandonar_multijugador_recibido
var _abandonando_multijugador := false

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

# --- pausa sincronizada entre ambos jugadores ---
signal pausa_recibida(pausado: bool)

func enviar_pausa(pausado: bool) -> void:
	rpc("rpc_pausa", pausado)

@rpc("any_peer", "call_local", "reliable")
func rpc_pausa(pausado: bool) -> void:
	pausa_recibida.emit(pausado)

# --- aviso explícito antes de cerrar la aplicación (salir del juego) ---
func enviar_salir_del_juego() -> void:
	_saliendo_intencionalmente = true
	rpc("rpc_salir_del_juego")

@rpc("any_peer", "reliable")
func rpc_salir_del_juego() -> void:
	var id_emisor := multiplayer.get_remote_sender_id()
	conexion_perdida.emit(id_emisor)

# ==========================================================================
# SINCRONIZACIÓN DETERMINISTA DE ANIMADORES EN LOOP (plataformas, enemigos)
# ==========================================================================
# Ni el host ni el cliente dejan que su AnimationPlayer avance solo por su
# propio _process (eso generaba drift si un dispositivo va un poco más
# lento que el otro). Cada peer calcula la posición como una función pura
# del reloj del sistema (Time.get_ticks_msec()) — sin importar cuántos
# fotogramas procesó cada lado, ambos calculan la misma posición para el
# mismo instante real.
#
# IMPORTANTE: la identificación de cada animador entre host y cliente se
# hace por ÍNDICE dentro del grupo, NO por NodePath. Godot le va cambiando
# el nombre a la instancia raíz del nivel cada vez que se recrea (tutorial,
# tutorial2, tutorial3...), lo cual rompía las rutas guardadas. El índice
# es estable porque ambos peers instancian la MISMA escena y llaman
# add_to_group() desde _ready() en el mismo orden de árbol.
const GRUPO_ANIMADORES_SINCRONIZABLES := "animadores_sincronizables"

# animador (AnimationPlayer) -> { epoch_ms: float, duracion: float, modo_loop: int }
# "epoch_ms" es el instante (reloj de ESTE proceso) en que la animación
# habría estado en posición 0.
var _animadores_deterministas: Dictionary = {}
var _generacion_sincronizacion := 0   # descarta respuestas viejas/obsoletas
var _tiempos_envio_generacion: Dictionary = {}  # generacion -> Time.get_ticks_msec() al pedir, para medir el round-trip

# El host arranca su propio sistema determinista al crear el nivel,
# usando su propia posición actual como punto de partida (no necesita
# pedírsela a nadie, ya que él es la fuente de verdad).
func inicializar_animadores_host() -> void:
	var ahora := Time.get_ticks_msec()
	var lista := get_tree().get_nodes_in_group(GRUPO_ANIMADORES_SINCRONIZABLES)
	print("[SYNC-HOST] inicializar_animadores_host(): ", lista.size(), " nodos en el grupo")
	for i in lista.size():
		var animador = lista[i]
		if not (animador is AnimationPlayer):
			print("[SYNC-HOST] índice ", i, " (", animador, ") no es AnimationPlayer, se salta")
			continue
		if animador.current_animation == "":
			print("[SYNC-HOST] índice ", i, " (", animador.get_parent().name, ") tiene current_animation vacío, se salta")
			continue
		var anim: Animation = animador.get_animation(animador.current_animation)
		if anim == null:
			print("[SYNC-HOST] índice ", i, " (", animador.get_parent().name, ") no encontró la animación '", animador.current_animation, "', se salta")
			continue
		var posicion_inicial: float = animador.current_animation_position
		animador.seek(posicion_inicial, true)
		animador.speed_scale = 0.0
		_animadores_deterministas[animador] = {
			"epoch_ms": ahora - posicion_inicial * 1000.0,
			"duracion": anim.length,
			"modo_loop": anim.loop_mode,
		}
		print("[SYNC-HOST] índice ", i, " (", animador.get_parent().name, ") registrado OK. animación=", animador.current_animation, " posicion=", posicion_inicial, " loop_mode=", anim.loop_mode)

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
		var animador = lista[i]
		if not (animador is AnimationPlayer):
			continue
		if animador.current_animation == "":
			print("[SYNC-HOST] al responder pedido: índice ", i, " (", animador.get_parent().name, ") tiene current_animation vacío, no se envía")
			continue
		var posicion_exacta: float
		var modo_loop: int
		if _animadores_deterministas.has(animador):
			var datos_anim = _animadores_deterministas[animador]
			posicion_exacta = _posicion_actual_animador(datos_anim, ahora)
			modo_loop = datos_anim.modo_loop
		else:
			# CARRERA: el nivel se recreó (típicamente por una muerte) y
			# el pedido del cliente llegó ANTES de que
			# inicializar_animadores_host() terminara de registrar este
			# animador en particular. Si lo salteábamos acá, este animador
			# desaparecía en silencio del paquete de respuesta y el
			# cliente (que ya le había hecho stop() esperando el dato)
			# se quedaba congelado para siempre — sin ningún reintento,
			# porque el cliente nunca se entera de que faltó.
			# Como en este caso el AnimationPlayer del host TODAVÍA está
			# corriendo normal (nadie lo tocó todavía), usamos su posición
			# en vivo como respaldo — sigue siendo un valor válido para
			# "ahora mismo".
			var anim: Animation = animador.get_animation(animador.current_animation)
			if anim == null:
				continue
			posicion_exacta = animador.current_animation_position
			modo_loop = anim.loop_mode
			print("[SYNC-HOST] índice ", i, " (", animador.get_parent().name, ") todavía no estaba en _animadores_deterministas, usando posición en vivo como respaldo")
		datos.append({
			"indice": i,
			"animacion": animador.current_animation,
			"posicion": posicion_exacta,
			"modo_loop": modo_loop,
		})
	print("[SYNC-HOST] enviando sincronización a peer ", id_emisor, " (generación ", generacion, "): ", datos.size(), " animadores")
	rpc_id(id_emisor, "_rpc_recibir_sincronizacion_nivel", datos, generacion)

@rpc("authority", "reliable")
func _rpc_recibir_sincronizacion_nivel(datos: Array, generacion: int) -> void:
	if generacion != _generacion_sincronizacion:
		print("[SYNC-CLIENTE] respuesta obsoleta (generación ", generacion, ", esperaba ", _generacion_sincronizacion, "), descartada")
		return

	# Compensación de latencia: entre que pedimos la posición y nos llega
	# la respuesta, pasó el viaje de ida y vuelta del RPC (round-trip). La
	# posición que nos manda el host ya quedó "vieja" para cuando la
	# aplicamos. Estimamos cuánto avanzó de más usando la mitad del
	# round-trip (aproximación estándar del tiempo de ida, asumiendo que
	# ida y vuelta tardan más o menos lo mismo).
	var ahora_ms := Time.get_ticks_msec()
	var tiempo_envio: float = _tiempos_envio_generacion.get(generacion, ahora_ms)
	_tiempos_envio_generacion.erase(generacion)
	var round_trip_ms: float = ahora_ms - tiempo_envio
	var latencia_estimada_ms: float = round_trip_ms / 2.0
	print("[SYNC-CLIENTE] recibida sincronización: ", datos.size(), " animadores (round-trip: ", round_trip_ms, "ms, compensando ", latencia_estimada_ms, "ms)")

	var lista := get_tree().get_nodes_in_group(GRUPO_ANIMADORES_SINCRONIZABLES)
	var hubo_fallas := false
	for entrada in datos:
		var i: int = entrada["indice"]
		if i < 0 or i >= lista.size():
			print("[SYNC-CLIENTE] índice ", i, " fuera de rango (mi grupo tiene ", lista.size(), " nodos)")
			hubo_fallas = true
			continue
		var nodo = lista[i]
		if not (nodo is AnimationPlayer):
			print("[SYNC-CLIENTE] índice ", i, " no es AnimationPlayer de mi lado")
			hubo_fallas = true
			continue
		var nombre_animacion: String = entrada["animacion"]
		var posicion: float = entrada["posicion"]
		var modo_loop: int = entrada["modo_loop"]
		var anim: Animation = nodo.get_animation(nombre_animacion)
		if anim == null:
			print("[SYNC-CLIENTE] índice ", i, " (", nodo.get_parent().name, ") no encontró la animación '", nombre_animacion, "'")
			continue
		# El "epoch" se corre hacia atrás por la latencia estimada, así el
		# cálculo posterior en _physics_process ya arranca compensado.
		var epoch_ms: float = ahora_ms - posicion * 1000.0 - latencia_estimada_ms
		nodo.play(nombre_animacion)
		nodo.speed_scale = 0.0   # deja de avanzar solo; lo maneja _physics_process de este script
		_animadores_deterministas[nodo] = {
			"epoch_ms": epoch_ms,
			"duracion": anim.length,
			"modo_loop": modo_loop,
		}
		print("[SYNC-CLIENTE] índice ", i, " (", nodo.get_parent().name, ") registrado OK")

	if hubo_fallas:
		# El host contestó mientras todavía estaba recreando su propio
		# nivel, o mi propio grupo local todavía no terminaba de poblarse.
		# Reintentamos un momento después, ya con todo asentado.
		print("[SYNC-CLIENTE] hubo fallas, reintentando en 0.2s...")
		await get_tree().create_timer(0.2).timeout
		solicitar_sincronizacion_nivel()

func limpiar_animadores_deterministas() -> void:
	# Restaura speed_scale por si algún nodo sobrevive fuera de este sistema
	for animador in _animadores_deterministas.keys():
		if is_instance_valid(animador):
			animador.speed_scale = 1.0
	_animadores_deterministas.clear()
const GRUPO_TRAMPAS_CAIDA_SINCRONIZABLES := "trampas_caida_sincronizables"
signal trampa_caida_recibida(indice: int)

func enviar_trampa_caida(indice: int) -> void:
	rpc("rpc_trampa_caida", indice)

@rpc("any_peer", "call_local", "reliable")
func rpc_trampa_caida(indice: int) -> void:
	trampa_caida_recibida.emit(indice)
# ==========================================================================
# SINCRONIZACIÓN DE ENEMIGOS CON IA (jefes, etc.)
# ==========================================================================
# Mismo criterio que los animadores deterministas: identificación por
# ÍNDICE dentro del grupo, no por NodePath, porque el nombre del nivel
# instanciado cambia cada vez que se recrea.
const GRUPO_ENEMIGOS_SINCRONIZABLES := "enemigos_sincronizables"

signal enemigo_posicion_recibida(indice: int, pos: Vector2, flip_h: bool, animacion: String)
signal enemigo_golpeado_recibido(indice: int, vida_restante: int)
signal enemigo_muerto_recibido(indice: int)

func enviar_posicion_enemigo(indice: int, pos: Vector2, flip_h: bool, animacion: String) -> void:
	rpc("rpc_posicion_enemigo", indice, pos, flip_h, animacion)

@rpc("authority", "unreliable_ordered")
func rpc_posicion_enemigo(indice: int, pos: Vector2, flip_h: bool, animacion: String) -> void:
	enemigo_posicion_recibida.emit(indice, pos, flip_h, animacion)

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
