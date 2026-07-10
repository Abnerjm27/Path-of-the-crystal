extends Node

signal muertes_actualizado
signal monedas_globales_actualizadas

var muertes: int
var nivel: int
var volumen_musica = 100
var volumen_efectos = 100
var personaje_seleccionado := 0
var monedas_totales: int = 0
var personajes_desbloqueados: Array[bool] = [true, false, false, false, false]
var racha_niveles: int = 0
var ha_usado_otro_personaje: bool = false
var tiempo_total_juego: float = 0.0
const RUTA_CONFIG = "user://configuracion.cfg"

func _ready():
	cargar_configuracion()

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
	if numero_nivel > nivel:
		nivel = numero_nivel
		guardar_progreso()
	ControladorLogros.revisar_logros()
func guardar_progreso():
	var config = ConfigFile.new()
	config.load(RUTA_CONFIG)
	config.set_value("progreso", "nivel", nivel)
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
		muertes = config.get_value("progreso", "muertes", 0)
		monedas_totales = config.get_value("progreso", "monedas_totales", 0)
		ha_usado_otro_personaje = config.get_value("progreso", "ha_usado_otro_personaje", false)
		tiempo_total_juego = config.get_value("progreso", "tiempo_total_juego", 0.0)
		
		var array_cargado = config.get_value("progreso", "personajes_desbloqueados", [true, false, false, false, false])
		personajes_desbloqueados.assign(array_cargado)
	aplicar_volumen_guardado()
func resetear_progreso():
	nivel = 1
	muertes = 0
	monedas_totales = 0
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

func acumular_tiempo(delta: float):
	tiempo_total_juego += delta
