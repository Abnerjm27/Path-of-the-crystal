extends Node
var intro_ya_vista: bool = false
signal muertes_actualizado
signal monedas_globales_actualizadas
var es_partida_en_red := false
var muertes: int
var nivel: int = 1
var nivel_cooperativo: int = 1   # NUEVO: progreso del cooperativo, separado del de un jugador
var volumen_musica = 100
var volumen_efectos = 100
var personaje_seleccionado := 0
var personaje_seleccionado_jugador2 := 0  # NUEVO: ranura del Jugador 2 en modo cooperativo
var monedas_totales: int = 0
var personajes_desbloqueados: Array[bool] = [true, false, false, false, false]
var racha_niveles: int = 0
var ha_usado_otro_personaje: bool = false
var tiempo_total_juego: float = 0.0
const RUTA_CONFIG = "user://configuracion.cfg"
var _nivel_cooperativo_red: int = -1  # -1 = todavía no llegó la sincronización del host
# ── NUEVO: Cooperativo (se activa desde el botón en seleccionpersonaje) ──
var modo_cooperativo_activo: bool = false
var esquema_jugador1: String = "teclado"   # "teclado" o "mando"
var indice_mando_jugador1: int = 0
var esquema_jugador2: String = "teclado"   # "teclado" o "mando"
var indice_mando_jugador2: int = 0
var mi_id_jugador_red := 1

func configurar_input_map_mando(prefijo: String, indice_dispositivo: int):
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

func _ready():
	cargar_configuracion()
	NetworkDiscovery.nivel_cooperativo_host_recibido.connect(aplicar_nivel_cooperativo_red)


func sumar_muerte():
	muertes += 1
	muertes_actualizado.emit()
	guardar_progreso()

func sumar_monedas(cantidad: int):
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
func actualizar_nivel(numero_nivel: int):
	if modo_cooperativo_activo:
		if numero_nivel > nivel_cooperativo:
			var nivel_anterior = nivel_cooperativo
			nivel_cooperativo = numero_nivel
			guardar_progreso()
			_revisar_desbloqueo_habilidades(nivel_anterior, nivel_cooperativo)
			# NUEVO: si somos el host de una partida en red, avisamos al cliente
			# cada vez que subimos de nivel, no solo al conectar
			if es_partida_en_red and NetworkDiscovery.soy_host():
				NetworkDiscovery.enviar_nivel_cooperativo_actualizado(nivel_cooperativo)
	else:
		if numero_nivel > nivel:
			var nivel_anterior = nivel
			nivel = numero_nivel
			guardar_progreso()
			_revisar_desbloqueo_habilidades(nivel_anterior, nivel)
	ControladorLogros.revisar_logros()
func _revisar_desbloqueo_habilidades(nivel_anterior: int, nivel_nuevo: int) -> void:
	if nivel_anterior <= NIVEL_DESBLOQUEO_DOBLE_SALTO and nivel_nuevo > NIVEL_DESBLOQUEO_DOBLE_SALTO:
		habilidad_desbloqueada.emit("doble_salto")
	if nivel_anterior <= NIVEL_DESBLOQUEO_DASH and nivel_nuevo > NIVEL_DESBLOQUEO_DASH:
		habilidad_desbloqueada.emit("dash")
func guardar_progreso():
	var config = ConfigFile.new()
	config.load(RUTA_CONFIG)
	config.set_value("progreso", "nivel", nivel)
	config.set_value("progreso", "nivel_cooperativo", nivel_cooperativo)
	config.set_value("progreso", "muertes", muertes)
	config.set_value("progreso", "monedas_totales", monedas_totales)
	config.set_value("progreso", "personajes_desbloqueados", personajes_desbloqueados)
	config.set_value("progreso", "ha_usado_otro_personaje", ha_usado_otro_personaje)
	config.set_value("progreso", "tiempo_total_juego", tiempo_total_juego)
	config.save(RUTA_CONFIG)
func _cambiar_musica(valor):
	volumen_musica = valor
	var bus = AudioServer.get_bus_index("Musica")
	if valor == 0:
		AudioServer.set_bus_volume_db(bus, -80)
	else:
		AudioServer.set_bus_volume_db(bus, linear_to_db(valor / 100.0))
	guardar_configuracion()

func _cambiar_efectos(valor):
	volumen_efectos = valor
	var bus = AudioServer.get_bus_index("Efectos")
	if valor == 0:
		AudioServer.set_bus_volume_db(bus, -80)
	else:
		AudioServer.set_bus_volume_db(bus, linear_to_db(valor / 100.0))
	guardar_configuracion()

func aplicar_volumen_guardado():
	_cambiar_musica(volumen_musica)
	_cambiar_efectos(volumen_efectos)

func guardar_configuracion():
	var config = ConfigFile.new()
	config.load(RUTA_CONFIG)
	config.set_value("audio", "volumen_musica", volumen_musica)
	config.set_value("audio", "volumen_efectos", volumen_efectos)
	config.save(RUTA_CONFIG)

func cargar_configuracion():
	var config = ConfigFile.new()
	var error = config.load(RUTA_CONFIG)
	if error == OK:
		volumen_musica = config.get_value("audio", "volumen_musica", 100)
		volumen_efectos = config.get_value("audio", "volumen_efectos", 100)
		nivel = config.get_value("progreso", "nivel", 1)
		nivel_cooperativo = config.get_value("progreso", "nivel_cooperativo", 1)
		muertes = config.get_value("progreso", "muertes", 0)
		monedas_totales = config.get_value("progreso", "monedas_totales", 0)
		ha_usado_otro_personaje = config.get_value("progreso", "ha_usado_otro_personaje", false)
		tiempo_total_juego = config.get_value("progreso", "tiempo_total_juego", 0.0)
		
		var array_cargado = config.get_value("progreso", "personajes_desbloqueados", [true, false, false, false, false])
		personajes_desbloqueados.assign(array_cargado)
	aplicar_volumen_guardado()
func resetear_progreso():
	nivel = 1
	nivel_cooperativo = 1
	muertes = 0
	monedas_totales = 0
	tiempo_total_juego = 0.0          # <- agregar
	racha_niveles = 0 
	personajes_desbloqueados = [true, false, false, false, false]
	guardar_progreso()
	
	ControladorLogros.desbloqueados.clear()
	ControladorLogros.guardar_logros()
func sumar_racha():
	racha_niveles += 1
	guardar_progreso()
	ControladorLogros.revisar_logros()

func resetear_racha():
	racha_niveles = 0

func marcar_personaje_usado(indice: int):
	if indice != 0:
		ha_usado_otro_personaje = true
		guardar_progreso()
func salir_de_partida_en_red() -> void:
	es_partida_en_red = false
	modo_cooperativo_activo = false
	mi_id_jugador_red = 1
	personaje_seleccionado_jugador2 = 0
	_nivel_cooperativo_red = -1   # NUEVO
func acumular_tiempo(delta: float):
	tiempo_total_juego += delta
# NUEVO: progresión de habilidades
signal habilidad_desbloqueada(id_habilidad: String)
const NIVEL_DESBLOQUEO_DOBLE_SALTO := 3
const NIVEL_DESBLOQUEO_DASH := 7
func doble_salto_desbloqueado() -> bool:
	return _nivel_referencia_habilidades() > NIVEL_DESBLOQUEO_DOBLE_SALTO

func dash_desbloqueado() -> bool:
	return _nivel_referencia_habilidades() > NIVEL_DESBLOQUEO_DASH

# NUEVO: en red, TODOS usan el nivel_cooperativo del HOST como criterio
# (no el propio de cada peer), para que las habilidades no queden asimétricas.
# El progreso guardado localmente de cada jugador (nivel_cooperativo) no se
# toca — esto solo afecta qué habilidades están activas mientras dura la partida.
func _nivel_referencia_habilidades() -> int:
	if es_partida_en_red:
		if NetworkDiscovery.soy_host():
			return nivel_cooperativo
		elif _nivel_cooperativo_red >= 0:
			return _nivel_cooperativo_red
		else:
			return nivel_cooperativo  # respaldo mientras llega el RPC del host
	return nivel_cooperativo if modo_cooperativo_activo else nivel
func aplicar_nivel_cooperativo_red(nivel_host: int) -> void:
	if NetworkDiscovery.soy_host():
		_nivel_cooperativo_red = nivel_host
		return
	# NUEVO: si esto llega DESPUÉS de la sincronización inicial (es decir,
	# el host subió de nivel mientras jugábamos juntos), revisamos si el
	# cliente también acaba de cruzar el umbral, para que le salga su
	# propio banner de "habilidad desbloqueada" en el momento correcto
	var nivel_anterior := _nivel_cooperativo_red
	_nivel_cooperativo_red = nivel_host
	if nivel_anterior >= 0:
		_revisar_desbloqueo_habilidades(nivel_anterior, nivel_host)
