extends Node2D
var jefe_scene = preload("res://animaciones/JefeFinal.tscn")

func _ready() -> void:
	var jefe = jefe_scene.instantiate()
	add_child(jefe)
	# Conectar DESPUÉS de add_child:
	jefe.jefe_muerto.connect(_on_jefe_muerto)
	jefe.jefe_danado.connect(_on_jefe_danado)
func _on_jefe_muerto() -> void:
	print("¡Jefe derrotado!")
	# cargar siguiente escena, mostrar victoria, etc.

func _on_jefe_danado(vida_restante: int) -> void:
	# Actualizar barra de vida del jefe en tu UI
	$BarraVidaJefe.value = vida_restante
