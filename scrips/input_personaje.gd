class_name InputPersonaje
extends RefCounted

var izquierda: bool = false
var derecha: bool = false
var saltar: bool = false
var dash: bool = false
var volar_pressed: bool = false
var volar_just: bool = false


func _to_string() -> String:
	return "Input[izq=%s der=%s saltar=%s dash=%s volar=%s volar_just=%s]" % [
		izquierda, derecha, saltar, dash, volar_pressed, volar_just
	]
