class_name EscenaNivel2
extends Node2D
@export var niveles:Array[PackedScene]
@export var controlador_partida: ControladorPartida
var _nivel_actual:int=1
var _nivel_instanciado:Node
@onready var menu_pausa = $menupausa
func _ready() -> void:
	menu_pausa.reiniciar.connect(_on_reiniciar_menu)
	menu_pausa.salir.connect(_on_salir_menu)
	if ControladorGlobal.nivel>1:
		cargar_nivel()
	else:
		_crear_nivel(_nivel_actual)

func _crear_nivel(numero_nivel:int):
	_nivel_instanciado= niveles[numero_nivel- 1].instantiate()
	add_child(_nivel_instanciado)
	
	var hijos:=_nivel_instanciado.get_children()
	
	for i in hijos.size():
		if hijos[i].is_in_group("personajes"):
			hijos[i].personaje_muerto.connect(reiniciar_nivel)
			break
			
	
	ControladorGlobal.nivel=numero_nivel
	controlador_partida.guardar_partida()


func _eliminar_nivel():
	_nivel_instanciado.queue_free()

func reiniciar_nivel():
	_eliminar_nivel()
	_crear_nivel.call_deferred(_nivel_actual)

func siguiente_nivel():
	_nivel_actual +=1
	_eliminar_nivel()
	_crear_nivel.call_deferred(_nivel_actual)


func cargar_nivel():
	_nivel_actual=ControladorGlobal.nivel
	_crear_nivel.call_deferred(_nivel_actual)
func _on_reiniciar_menu():
	get_tree().paused = false
	menu_pausa.visible = false
	reiniciar_nivel()

func _on_salir_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://escenas/menuprincipal/menu_principal.tscn")
