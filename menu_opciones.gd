extends Control

signal volver

@onready var slider_musica = $PanelOpciones/BoxContainer/Musica
@onready var slider_efectos = $PanelOpciones/BoxContainer/Efectos
@onready var boton_volver = $PanelOpciones/BotonVolver
@onready var boton_resetear = $PanelOpciones/BotonResetear

@onready var panel_confirmacion_reset = $PanelConfirmacionReset
@onready var boton_confirmar_reset = $PanelConfirmacionReset/BotonConfirmarReset
@onready var boton_cancelar_reset = $PanelConfirmacionReset/BotonCancelarReset

func _ready():
	slider_musica.value = ControladorGlobal.volumen_musica
	slider_efectos.value = ControladorGlobal.volumen_efectos
	slider_musica.value_changed.connect(ControladorGlobal._cambiar_musica)
	slider_efectos.value_changed.connect(ControladorGlobal._cambiar_efectos)
	
	boton_resetear.pressed.connect(_on_boton_resetear_pressed)
	boton_confirmar_reset.pressed.connect(_on_confirmar_reset)
	boton_cancelar_reset.pressed.connect(_on_cancelar_reset)
	panel_confirmacion_reset.visible = false

func _on_boton_volver_pressed():
	volver.emit()
	visible = false

func _on_boton_resetear_pressed():
	panel_confirmacion_reset.visible = true

func _on_confirmar_reset():
	ControladorGlobal.resetear_progreso()
	panel_confirmacion_reset.visible = false
	slider_musica.value = ControladorGlobal.volumen_musica
	slider_efectos.value = ControladorGlobal.volumen_efectos

func _on_cancelar_reset():
	panel_confirmacion_reset.visible = false
