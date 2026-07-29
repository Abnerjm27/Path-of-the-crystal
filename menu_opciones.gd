extends Control
signal volver
@onready var slider_musica = $PanelOpciones/BoxContainer/Musica
@onready var slider_efectos = $PanelOpciones/BoxContainer/Efectos
@onready var boton_volver = $PanelOpciones/BotonVolver
@onready var boton_resetear = $PanelOpciones/BotonResetear
@onready var panel_confirmacion_reset = $PanelConfirmacionReset
@onready var boton_confirmar_reset = $PanelConfirmacionReset/BotonConfirmarReset
@onready var boton_cancelar_reset = $PanelConfirmacionReset/BotonCancelarReset

# Controles del panel principal de opciones (fuera del panel de confirmación de reseteo)
var _controles_panel_opciones: Array

func _ready():
	slider_musica.value = ControladorGlobal.volumen_musica
	slider_efectos.value = ControladorGlobal.volumen_efectos
	slider_musica.value_changed.connect(ControladorGlobal._cambiar_musica)
	slider_efectos.value_changed.connect(ControladorGlobal._cambiar_efectos)
	boton_resetear.pressed.connect(_on_boton_resetear_pressed)
	boton_confirmar_reset.pressed.connect(_on_confirmar_reset)
	boton_cancelar_reset.pressed.connect(_on_cancelar_reset)
	panel_confirmacion_reset.visible = false
	_controles_panel_opciones = [slider_musica, slider_efectos, boton_volver, boton_resetear]
	NavegacionMando.conectar_efecto_foco(_controles_panel_opciones + [boton_confirmar_reset, boton_cancelar_reset])

# Llamada desde afuera (ej. menu_principal) al abrir este menú
func enfocar_primer_boton():
	NavegacionMando.enfocar_con_seguridad(boton_volver)

func _on_boton_volver_pressed():
	volver.emit()
	visible = false

func _on_boton_resetear_pressed():
	panel_confirmacion_reset.visible = true
	NavegacionMando.bloquear_controles(_controles_panel_opciones, true)
	NavegacionMando.enfocar_con_seguridad(boton_cancelar_reset)   # cancelar como opción segura por defecto

func _on_confirmar_reset():
	ControladorGlobal.resetear_progreso()
	panel_confirmacion_reset.visible = false
	slider_musica.value = ControladorGlobal.volumen_musica
	slider_efectos.value = ControladorGlobal.volumen_efectos
	NavegacionMando.bloquear_controles(_controles_panel_opciones, false)
	NavegacionMando.enfocar_con_seguridad(boton_resetear)

func _on_cancelar_reset():
	panel_confirmacion_reset.visible = false
	NavegacionMando.bloquear_controles(_controles_panel_opciones, false)
	NavegacionMando.enfocar_con_seguridad(boton_resetear)
