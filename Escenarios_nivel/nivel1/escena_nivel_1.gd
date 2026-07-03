class_name EscenaNivel1
extends Node2D

@export var niveles: Array[PackedScene]
@export var controlador_partida: ControladorPartida

var _nivel_actual: int = 1
var _nivel_instanciado: Node

@onready var menu_pausa = $menupausa


func _ready() -> void:
	menu_pausa.reiniciar.connect(_on_reiniciar_menu)
	menu_pausa.salir.connect(_on_salir_menu)
	
	if ControladorGlobal.nivel > 1:
		cargar_nivel()
	else:
		_crear_nivel(_nivel_actual)


func _crear_nivel(numero_nivel: int) -> void:
	# Validación para evitar el error de índice fuera de rango
	if niveles.is_empty():
		push_error("El array 'niveles' está vacío. Asigna escenas en el Inspector.")
		return
	
	if numero_nivel < 1 or numero_nivel > niveles.size():
		push_warning("No existe el nivel %d. Solo hay %d niveles definidos." % [numero_nivel, niveles.size()])
		return
	
	_nivel_instanciado = niveles[numero_nivel - 1].instantiate()
	add_child(_nivel_instanciado)
	
	var hijos := _nivel_instanciado.get_children()
	for i in hijos.size():
		if hijos[i].is_in_group("personajes"):
			hijos[i].personaje_muerto.connect(reiniciar_nivel)
			break
	
	ControladorGlobal.nivel = numero_nivel
	controlador_partida.guardar_partida()


func _eliminar_nivel() -> void:
	if is_instance_valid(_nivel_instanciado):
		_nivel_instanciado.queue_free()


func reiniciar_nivel() -> void:
	_eliminar_nivel()
	_crear_nivel.call_deferred(_nivel_actual)


func siguiente_nivel() -> void:
	if _nivel_actual >= niveles.size():
		print("¡Juego completado! No hay más niveles.")
		# Aquí podrías cambiar de escena a una pantalla de "victoria"
		# get_tree().change_scene_to_file("res://escenas/final/pantalla_final.tscn")
		return
	
	_nivel_actual += 1
	_eliminar_nivel()
	_crear_nivel.call_deferred(_nivel_actual)


func cargar_nivel() -> void:
	_nivel_actual = ControladorGlobal.nivel
	
	# Validación extra por si el nivel guardado ya no existe en el array
	if _nivel_actual > niveles.size():
		push_warning("El nivel guardado (%d) no existe. Cargando último nivel disponible." % _nivel_actual)
		_nivel_actual = niveles.size()
	
	_crear_nivel.call_deferred(_nivel_actual)


func _on_reiniciar_menu() -> void:
	get_tree().paused = false
	menu_pausa.visible = false
	reiniciar_nivel()


func _on_salir_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://escenas/menuprincipal/menu_principal.tscn")
