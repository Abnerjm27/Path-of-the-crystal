extends Node

# ─────────────────────────────────────────────────────────────
#  SEÑALES
# ─────────────────────────────────────────────────────────────
signal muertes_actualizado
signal monedas_globales_actualizadas
signal habilidad_desbloqueada(id_habilidad: String)

# ─────────────────────────────────────────────────────────────
#  CONSTANTES
# ─────────────────────────────────────────────────────────────
const RUTA_CONFIG := "user://configuracion.cfg"

const NIVEL_DESBLOQUEO_DOBLE_SALTO := 3
const NIVEL_DESBLOQUEO_DASH := 7
const NIVEL_DESBLOQUEO_VUELO := 19

# ─────────────────────────────────────────────────────────────
#  ESTADO GENERAL
# ─────────────────────────────────────────────────────────────
var intro_ya_vista: bool = false
var es_partida_en_red := false
var muertes: int = 0
var nivel: int = 1
var nivel_cooperativo: int = 1
var monedas_totales: int = 0
var personajes_desbloqueados: Array[bool] = [true, false, false, false, false]
var racha_niveles: int = 0
var ha_usado_otro_personaje: bool = false
var tiempo_total_juego: float = 0.0

# ─────────────────────────────────────────────────────────────
#  AUDIO
# ─────────────────────────────────────────────────────────────
var volumen_musica: int = 100
var volumen_efectos: int = 100

# ─────────────────────────────────────────────────────────────
#  SELECCIÓN DE PERSONAJE
# ─────────────────────────────────────────────────────────────
var personaje_seleccionado := 0
var personaje_seleccionado_jugador2 := 0

# ─────────────────────────────────────────────────────────────
#  COOPERATIVO LOCAL
# ─────────────────────────────────────────────────────────────
var modo_cooperativo_activo: bool = false
var esquema_jugador1: String = "teclado"
var indice_mando_jugador1: int = 0
var esquema_jugador2: String = "teclado"
var indice_mando_jugador2: int = 0

# ─────────────────────────────────────────────────────────────
#  MULTIJUGADOR EN RED
# ─────────────────────────────────────────────────────────────
var mi_id_jugador_red := 1
var _nivel_cooperativo_red: int = -1


# ═════════════════════════════════════════════════════════════
#  CICLO DE VIDA
# ═════════════════════════════════════════════════════════════
func _ready() -> void:
	cargar_configuracion()
	NetworkDiscovery.nivel_cooperativo_host_recibido.connect(aplicar_nivel_cooperativo_red)
	NetworkDiscovery.actualizar_nivel_cooperativo(nivel_cooperativo)


# ═════════════════════════════════════════════════════════════
#  ROL EN RED
# ═════════════════════════════════════════════════════════════
## Determina si este peer es host (1) o cliente (2) y lo asigna a
## mi_id_jugador_red. Se llama desde NetworkDiscovery al crear servidor,
## al conectar como cliente y al cerrar la conexión.
func actualizar_rol_jugador_red() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		mi_id_jugador_red = 1
	elif multiplayer.is_server():
		mi_id_jugador_red = 1
	else:
		mi_id_jugador_red = 2
# ═════════════════════════════════════════════════════════════
#  INPUT MAP PARA MANDOS
# ═════════════════════════════════════════════════════════════
func configurar_input_map_mando(prefijo: String, indice_dispositivo: int) -> void:
	var mapa := {
		"%s_izquierda" % prefijo: [
			_crear_evento_eje(JOY_AXIS_LEFT_X, -1.0, indice_dispositivo),
			_crear_evento_boton(JOY_BUTTON_DPAD_LEFT, indice_dispositivo),
		],
		"%s_derecha" % prefijo: [
			_crear_evento_eje(JOY_AXIS_LEFT_X, 1.0, indice_dispositivo),
			_crear_evento_boton(JOY_BUTTON_DPAD_RIGHT, indice_dispositivo),
		],
		"%s_saltar" % prefijo: [_crear_evento_boton(JOY_BUTTON_A, indice_dispositivo)],
		"%s_dash" % prefijo: [_crear_evento_boton(JOY_BUTTON_B, indice_dispositivo)],
		"%s_volar" % prefijo: [_crear_evento_boton(JOY_BUTTON_Y, indice_dispositivo)],
	}
	for nombre_accion in mapa:
		if not InputMap.has_action(nombre_accion):
			InputMap.add_action(nombre_accion, 0.2)
		InputMap.action_erase_events(nombre_accion)
		for evento in mapa[nombre_accion]:
			InputMap.action_add_event(nombre_accion, evento)


func _crear_evento_boton(boton: int, dispositivo: int) -> InputEventJoypadButton:
	var evento := InputEventJoypadButton.new()
	evento.device = dispositivo
	evento.button_index = boton
	return evento


func _crear_evento_eje(eje: int, valor: float, dispositivo: int) -> InputEventJoypadMotion:
	var evento := InputEventJoypadMotion.new()
	evento.device = dispositivo
	evento.axis = eje
	evento.axis_value = valor
	return evento


# ═════════════════════════════════════════════════════════════
#  PROGRESO
# ═════════════════════════════════════════════════════════════
func sumar_muerte() -> void:
	muertes += 1
	muertes_actualizado.emit()
	guardar_progreso()


func sumar_monedas(cantidad: int) -> void:
	monedas_totales += cantidad
	monedas_globales_actualizadas.emit()
	guardar_progreso()
	ControladorLogros.revisar_logros()


func comprar_personaje(indice: int, costo: int) -> bool:
	if personajes_desbloqueados[indice]:
		return false
	if monedas_totales < costo:
		return false

	monedas_totales -= costo
	personajes_desbloqueados[indice] = true
	monedas_globales_actualizadas.emit()
	guardar_progreso()
	ControladorLogros.revisar_logros()
	return true


func actualizar_nivel(numero_nivel: int) -> void:
	if modo_cooperativo_activo:
		if numero_nivel > nivel_cooperativo:
			var nivel_anterior := nivel_cooperativo
			nivel_cooperativo = numero_nivel
			guardar_progreso()
			_revisar_desbloqueo_habilidades(nivel_anterior, nivel_cooperativo)
			NetworkDiscovery.actualizar_nivel_cooperativo(nivel_cooperativo)
	else:
		if numero_nivel > nivel:
			var nivel_anterior := nivel
			nivel = numero_nivel
			guardar_progreso()
			_revisar_desbloqueo_habilidades(nivel_anterior, nivel)

	ControladorLogros.revisar_logros()


func sumar_racha() -> void:
	racha_niveles += 1
	guardar_progreso()
	ControladorLogros.revisar_logros()


func resetear_racha() -> void:
	racha_niveles = 0


func marcar_personaje_usado(indice: int) -> void:
	if indice != 0:
		ha_usado_otro_personaje = true
		guardar_progreso()


func acumular_tiempo(delta: float) -> void:
	tiempo_total_juego += delta


# ═════════════════════════════════════════════════════════════
#  HABILIDADES DESBLOQUEABLES
# ═════════════════════════════════════════════════════════════
func doble_salto_desbloqueado() -> bool:
	return _nivel_referencia_habilidades() > NIVEL_DESBLOQUEO_DOBLE_SALTO


func dash_desbloqueado() -> bool:
	return _nivel_referencia_habilidades() > NIVEL_DESBLOQUEO_DASH


func vuelo_desbloqueado() -> bool:
	return _nivel_referencia_habilidades() > NIVEL_DESBLOQUEO_VUELO


func _revisar_desbloqueo_habilidades(nivel_anterior: int, nivel_nuevo: int) -> void:
	if nivel_anterior <= NIVEL_DESBLOQUEO_DOBLE_SALTO and nivel_nuevo > NIVEL_DESBLOQUEO_DOBLE_SALTO:
		habilidad_desbloqueada.emit("doble_salto")
	if nivel_anterior <= NIVEL_DESBLOQUEO_DASH and nivel_nuevo > NIVEL_DESBLOQUEO_DASH:
		habilidad_desbloqueada.emit("dash")
	if nivel_anterior <= NIVEL_DESBLOQUEO_VUELO and nivel_nuevo > NIVEL_DESBLOQUEO_VUELO:
		habilidad_desbloqueada.emit("vuelo")


func _nivel_referencia_habilidades() -> int:
	if es_partida_en_red:
		if NetworkDiscovery.soy_host():
			return nivel_cooperativo
		elif _nivel_cooperativo_red >= 0:
			return _nivel_cooperativo_red
		return nivel_cooperativo
	return nivel_cooperativo if modo_cooperativo_activo else nivel


func aplicar_nivel_cooperativo_red(nivel_host: int) -> void:
	if NetworkDiscovery.soy_host():
		_nivel_cooperativo_red = nivel_host
		return

	var nivel_anterior := _nivel_cooperativo_red
	_nivel_cooperativo_red = nivel_host

	if nivel_anterior >= 0:
		_revisar_desbloqueo_habilidades(nivel_anterior, nivel_host)


# ═════════════════════════════════════════════════════════════
#  PERSISTENCIA
# ═════════════════════════════════════════════════════════════
func guardar_progreso() -> void:
	var config := ConfigFile.new()
	config.load(RUTA_CONFIG)
	config.set_value("progreso", "nivel", nivel)
	config.set_value("progreso", "nivel_cooperativo", nivel_cooperativo)
	config.set_value("progreso", "muertes", muertes)
	config.set_value("progreso", "monedas_totales", monedas_totales)
	config.set_value("progreso", "personajes_desbloqueados", personajes_desbloqueados)
	config.set_value("progreso", "ha_usado_otro_personaje", ha_usado_otro_personaje)
	config.set_value("progreso", "tiempo_total_juego", tiempo_total_juego)
	config.save(RUTA_CONFIG)


func cargar_configuracion() -> void:
	var config := ConfigFile.new()
	var error := config.load(RUTA_CONFIG)
	if error == OK:
		volumen_musica = config.get_value("audio", "volumen_musica", 100)
		volumen_efectos = config.get_value("audio", "volumen_efectos", 100)
		nivel = config.get_value("progreso", "nivel", 1)
		nivel_cooperativo = config.get_value("progreso", "nivel_cooperativo", 1)
		muertes = config.get_value("progreso", "muertes", 0)
		monedas_totales = config.get_value("progreso", "monedas_totales", 0)
		ha_usado_otro_personaje = config.get_value("progreso", "ha_usado_otro_personaje", false)
		tiempo_total_juego = config.get_value("progreso", "tiempo_total_juego", 0.0)

		var array_cargado: Array = config.get_value("progreso", "personajes_desbloqueados", [true, false, false, false, false])
		personajes_desbloqueados.assign(array_cargado)

	aplicar_volumen_guardado()


func resetear_progreso() -> void:
	nivel = 1
	nivel_cooperativo = 1
	muertes = 0
	monedas_totales = 0
	tiempo_total_juego = 0.0
	racha_niveles = 0
	personajes_desbloqueados = [true, false, false, false, false]
	guardar_progreso()

	ControladorLogros.desbloqueados.clear()
	ControladorLogros.guardar_logros()


# ═════════════════════════════════════════════════════════════
#  AUDIO / CONFIGURACIÓN
# ═════════════════════════════════════════════════════════════
func _cambiar_musica(valor: int) -> void:
	volumen_musica = valor
	var bus := AudioServer.get_bus_index("Musica")
	if valor == 0:
		AudioServer.set_bus_volume_db(bus, -80)
	else:
		AudioServer.set_bus_volume_db(bus, linear_to_db(valor / 100.0))
	guardar_configuracion()


func _cambiar_efectos(valor: int) -> void:
	volumen_efectos = valor
	var bus := AudioServer.get_bus_index("Efectos")
	if valor == 0:
		AudioServer.set_bus_volume_db(bus, -80)
	else:
		AudioServer.set_bus_volume_db(bus, linear_to_db(valor / 100.0))
	guardar_configuracion()


func aplicar_volumen_guardado() -> void:
	_cambiar_musica(volumen_musica)
	_cambiar_efectos(volumen_efectos)


func guardar_configuracion() -> void:
	var config := ConfigFile.new()
	config.load(RUTA_CONFIG)
	config.set_value("audio", "volumen_musica", volumen_musica)
	config.set_value("audio", "volumen_efectos", volumen_efectos)
	config.save(RUTA_CONFIG)


# ═════════════════════════════════════════════════════════════
#  MULTIJUGADOR EN RED
# ═════════════════════════════════════════════════════════════
func salir_de_partida_en_red() -> void:
	es_partida_en_red = false
	modo_cooperativo_activo = false
	personaje_seleccionado_jugador2 = 0
	_nivel_cooperativo_red = -1
	actualizar_rol_jugador_red()
