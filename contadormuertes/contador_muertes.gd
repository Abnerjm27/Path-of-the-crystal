class_name ContadorMuertes
extends Control
@export var label:Label
@export var label1: Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if ControladorGlobal.es_partida_en_red:
		# NUEVO: en red, mostramos el conteo CONJUNTO de muertes de este
		# nivel (el mismo que ya se sincroniza entre host y cliente en
		# EscenaNivel0.gd), no la estadística de por vida de
		# ControladorGlobal.muertes (esa es local a cada instalación y
		# nunca estuvo pensada para reflejar la partida compartida).
		var escena_nivel = get_tree().get_first_node_in_group("escena_nivel_actual")
		if escena_nivel:
			escena_nivel.muertes_nivel_actualizado.connect(_actualizar_texto_red)
		_actualizar_texto_red(0)
	else:
		ControladorGlobal.muertes_actualizado.connect(_actualizar_texto)
		_actualizar_texto()

func _actualizar_texto():
	label.text = str(ControladorGlobal.muertes)
	_actualizar_mensaje(ControladorGlobal.muertes)

func _actualizar_texto_red(cantidad: int):
	label.text = str(cantidad)
	_actualizar_mensaje(cantidad)

func _actualizar_mensaje(cantidad: int):
	if cantidad >= 100 and cantidad <= 200:
		label1.text = " llevas mas muertes que minutos jugados en la partida "
	elif cantidad > 200 and cantidad <= 300:
		label1.text = " si morir diera dinero,ya serias millonario "
	elif cantidad > 300:
		label1.text = "viendo como juegas,la palabra malo te queda chica "
