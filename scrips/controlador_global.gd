extends Node

signal muertes_actualizado

var muertes: int
var nivel: int
var volumen_musica = 100
var volumen_efectos = 100
var personaje_seleccionado := 0

const RUTA_CONFIG = "user://configuracion.cfg"

func _ready():
	cargar_configuracion()

func sumar_muerte():
	muertes += 1
	muertes_actualizado.emit()

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
	config.set_value("audio", "volumen_musica", volumen_musica)
	config.set_value("audio", "volumen_efectos", volumen_efectos)
	config.save(RUTA_CONFIG)

func cargar_configuracion():
	var config = ConfigFile.new()
	var error = config.load(RUTA_CONFIG)
	if error == OK:
		volumen_musica = config.get_value("audio", "volumen_musica", 100)
		volumen_efectos = config.get_value("audio", "volumen_efectos", 100)
	aplicar_volumen_guardado()
