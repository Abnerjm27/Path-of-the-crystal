extends Node

signal muertes_actualizado

var muertes: int
var nivel:int
var volumen_musica = 100
var volumen_efectos = 100
var personaje_seleccionado := 0
func sumar_muerte():
	muertes +=1
	muertes_actualizado.emit()
func _cambiar_musica(valor):
	var bus = AudioServer.get_bus_index("Musica")
	print(AudioServer.get_bus_index("Musica"))

	if valor == 0:
		AudioServer.set_bus_volume_db(bus, -80)
	else:
		AudioServer.set_bus_volume_db(bus, linear_to_db(valor / 100.0))
func _cambiar_efectos(valor):
	var bus = AudioServer.get_bus_index("Efectos")
	print(AudioServer.get_bus_index("Efectos"))

	if valor == 0:
		AudioServer.set_bus_volume_db(bus, -80)
	else:
		AudioServer.set_bus_volume_db(bus, linear_to_db(valor / 100.0))
