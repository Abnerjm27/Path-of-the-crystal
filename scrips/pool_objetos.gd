class_name PoolObjetos
extends RefCounted

var _escena: PackedScene
var _padre: Node
var _disponibles: Array[Node] = []
var _tamano_max: int

func _init(escena: PackedScene, padre: Node, _tamano_inicial: int = 0, tamano_max: int = 40) -> void:
	_escena = escena
	_padre = padre
	_tamano_max = tamano_max
	# IMPORTANTE: no pre-instanciamos aquí.
	# Si el pool se construye durante el _ready() de una escena, el padre todavía
	# está "busy setting up children" y add_child() falla con:
	#   "Parent node is busy setting up children"
	# En su lugar, el pool crece de forma perezosa cuando se llama a obtener().
	# Si quieres pre-calentar el pool, usa _pre_calentar_diferido() más abajo.


## Pre-calentamiento opcional que SÍ es seguro durante _ready().
## Se ejecuta diferido, cuando el árbol ya terminó de construirse.
func pre_calentar_diferido(cantidad: int) -> void:
	if cantidad <= 0:
		return
	call_deferred("_pre_calentar", cantidad)


func _pre_calentar(cantidad: int) -> void:
	if not is_instance_valid(_padre) or not _padre.is_inside_tree():
		return
	for i in cantidad:
		if _disponibles.size() >= _tamano_max:
			return
		var obj := _escena.instantiate()
		_preparar_inactivo(obj)
		_padre.add_child(obj)
		_disponibles.append(obj)


func _preparar_inactivo(obj: Node) -> void:
	obj.visible = false
	obj.set_process(false)
	obj.set_physics_process(false)
	if obj is Node2D:
		obj.modulate = Color(1, 1, 1, 1)


func obtener() -> Node:
	var obj: Node
	if _disponibles.size() > 0:
		obj = _disponibles.pop_back()
	else:
		# Creación perezosa: aquí ya estamos fuera de _ready() y el padre
		# puede aceptar hijos sin problemas.
		obj = _escena.instantiate()
		_padre.add_child(obj)
	obj.visible = true
	obj.set_process(true)
	obj.set_physics_process(true)
	return obj


func devolver(obj: Node) -> void:
	if not is_instance_valid(obj):
		return
	_preparar_inactivo(obj)
	if _disponibles.size() < _tamano_max:
		_disponibles.append(obj)
	else:
		obj.queue_free()
