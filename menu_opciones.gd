extends Control

signal volver

@onready var slider_musica = $PanelOpciones/BoxContainer/Musica
@onready var slider_efectos = $PanelOpciones/BoxContainer/Efectos
@onready var boton_volver = $PanelOpciones/BotonVolver

func _ready():
	slider_musica.value = ControladorGlobal.volumen_musica
	slider_efectos.value = ControladorGlobal.volumen_efectos
	slider_musica.value_changed.connect(ControladorGlobal._cambiar_musica)
	slider_efectos.value_changed.connect(ControladorGlobal._cambiar_efectos)

func _on_boton_volver_pressed():
	volver.emit()
	visible = false
