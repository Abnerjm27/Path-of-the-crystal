extends Node

var ruta_escena_destino: String = ""

func ir_a_escena(ruta: String):
	ruta_escena_destino = ruta
	get_tree().change_scene_to_file("res://pantalla de carga/pantalla_carga.tscn")
