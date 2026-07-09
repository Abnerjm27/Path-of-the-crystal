class_name ContenedorMonedas
extends Node

signal monedas_actualizadas(recogidas: int, total: int)

var total_monedas: int
var _monedas_recogidas: int

func _ready() -> void:
	var monedas := get_children()
	total_monedas = monedas.size()
	
	for moneda in monedas:
		moneda.contenedor_monedas = self
	
	monedas_actualizadas.emit(_monedas_recogidas, total_monedas)

func moneda_recogida():
	_monedas_recogidas += 1
	ControladorGlobal.sumar_monedas(1)  # <- nuevo: suma 1 moneda al total global
	monedas_actualizadas.emit(_monedas_recogidas, total_monedas)
	
	if _monedas_recogidas == total_monedas:
		get_parent().get_parent().mostrar_pantalla_final(_monedas_recogidas, total_monedas)
