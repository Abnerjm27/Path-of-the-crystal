class_name ContenedorMonedas
extends Node
signal monedas_actualizadas(recogidas: int, total: int)
var total_monedas: int
var _monedas_recogidas: int

# NUEVO: snapshot fijo de las monedas, tomado una sola vez en _ready().
# NO usar get_children() en ningún otro lado del script: la lista de hijos
# de este nodo cambia con el tiempo (se le reparentan AudioStreamPlayer2D
# y se le añaden texto_flotante al recoger monedas), así que un índice
# calculado sobre get_children() más adelante ya no corresponde a la
# misma moneda que cuando se generó el índice.
var _monedas: Array[Moneda] = []
var _indices_recogidos: Array[int] = []

func _ready() -> void:
	for hijo in get_children():
		if hijo is Moneda:
			_monedas.append(hijo)

	total_monedas = _monedas.size()

	for i in _monedas.size():
		_monedas[i].contenedor_monedas = self
		_monedas[i].indice_moneda = i

	monedas_actualizadas.emit(_monedas_recogidas, total_monedas)

	if ControladorGlobal.es_partida_en_red:
		NetworkDiscovery.moneda_remota_recogida.connect(_on_moneda_remota_recogida)

# indice: posición fija de la moneda en el snapshot _monedas.
# es_remota: true si esta llamada viene de un aviso RPC del otro peer
#            (en ese caso no hay que sumar monedas globales otra vez ni reenviar el RPC).
func moneda_recogida(indice: int, es_remota := false) -> void:
	if indice in _indices_recogidos:
		return
	_indices_recogidos.append(indice)
	_monedas_recogidas += 1

	if not es_remota:
		ControladorGlobal.sumar_monedas(1)
		if ControladorGlobal.es_partida_en_red:
			NetworkDiscovery.enviar_moneda_recogida(indice)

	monedas_actualizadas.emit(_monedas_recogidas, total_monedas)

	if _monedas_recogidas == total_monedas:
		get_parent().get_parent().mostrar_pantalla_final(_monedas_recogidas, total_monedas)

func _on_moneda_remota_recogida(indice: int) -> void:
	if indice < 0 or indice >= _monedas.size():
		return
	var moneda := _monedas[indice]
	if is_instance_valid(moneda):
		moneda.recoger_a_distancia()
