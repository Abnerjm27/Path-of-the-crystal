class_name ContadorMuertes
extends Control
@export var label:Label
@export var label1: Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ControladorGlobal.muertes_actualizado.connect(_actualizar_texto)
	_actualizar_texto()
	
func _actualizar_texto():
	label.text =str(ControladorGlobal.muertes)
	
	if ControladorGlobal.muertes >= 100 and ControladorGlobal.muertes <= 200 :
			label1.text=" llevas mas muertes que minutos jugados en la partida "
	elif ControladorGlobal.muertes > 200 and ControladorGlobal.muertes <= 300 :
			label1.text=" si morir diera dinero,ya serias millonario "
	elif  ControladorGlobal.muertes > 300 :
				label1.text="viendo como juegas,la palabra malo te queda chica "
