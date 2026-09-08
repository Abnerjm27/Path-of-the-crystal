class_name ContenedorMonedas
extends Node

signal monedas_actualizadas(recogidas: int, total: int)

var total_monedas: int = 0
var _monedas_recogidas: int = 0

# Snapshot fijo de monedas tomado en _ready()
var _monedas: Array[Moneda] = []
var _indices_recogidos: Array[int] = []


func _ready() -> void:
	# Filtrar únicamente los nodos que son de clase Moneda
	for hijo in get_children():
		if hijo is Moneda:
			_monedas.append(hijo as Moneda)

	total_monedas = _monedas.size()

	# Asignar índice único y referencia del contenedor a cada moneda
	for i in range(_monedas.size()):
		var moneda := _monedas[i]
		if is_instance_valid(moneda):
			moneda.contenedor_monedas = self
			moneda.indice_moneda = i

	monedas_actualizadas.emit(_monedas_recogidas, total_monedas)

	if ControladorGlobal.es_partida_en_red:
		if not NetworkDiscovery.moneda_remota_recogida.is_connected(_on_moneda_remota_recogida):
			NetworkDiscovery.moneda_remota_recogida.connect(_on_moneda_remota_recogida)


func _exit_tree() -> void:
	if ControladorGlobal.es_partida_en_red:
		if NetworkDiscovery.moneda_remota_recogida.is_connected(_on_moneda_remota_recogida):
			NetworkDiscovery.moneda_remota_recogida.disconnect(_on_moneda_remota_recogida)


# indice: posición fija de la moneda en el snapshot _monedas.
# es_remota: true si la llamada proviene de un paquete RPC del otro peer
func moneda_recogida(indice: int, es_remota: bool = false) -> void:
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
		_notificar_pantalla_final()


func _on_moneda_remota_recogida(indice: int) -> void:
	if indice < 0 or indice >= _monedas.size():
		return

	var moneda := _monedas[indice]
	if is_instance_valid(moneda):
		moneda.recoger_a_distancia()


# Busca de forma segura la función para finalizar el nivel en los ancestros
func _notificar_pantalla_final() -> void:
	var nodo_actual: Node = get_parent()
	while is_instance_valid(nodo_actual):
		if nodo_actual.has_method("mostrar_pantalla_final"):
			nodo_actual.call("mostrar_pantalla_final", _monedas_recogidas, total_monedas)
			return
		nodo_actual = nodo_actual.get_parent()
