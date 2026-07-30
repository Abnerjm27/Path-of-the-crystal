class_name Menupausa
extends CanvasLayer
signal continuar
signal reiniciar
signal salir
@onready var slider_musica = $PanelOpciones/BoxContainer/Musica
@onready var slider_efectos = $PanelOpciones/BoxContainer/Efectos
@onready var boton_reiniciar = $HBoxContainer/reiniciar
@onready var boton_continuar = $HBoxContainer/continuar
@onready var boton_menu = $salir
@onready var boton_salir_juego = $salirdeljuego

func _ready():
	slider_musica.value_changed.connect(ControladorGlobal._cambiar_musica)
	slider_efectos.value_changed.connect(ControladorGlobal._cambiar_efectos)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	slider_musica.value = ControladorGlobal.volumen_musica
	slider_efectos.value = ControladorGlobal.volumen_efectos
	_configurar_navegacion_mando()
	visibility_changed.connect(_on_visibility_changed)

func _on_continuar_pressed():
	continuar.emit()
func _on_reiniciar_pressed():
	reiniciar.emit()
func _on_salir_pressed():
	salir.emit()

func _configurar_navegacion_mando():
	var controles = [slider_musica, slider_efectos, boton_reiniciar, boton_continuar, boton_menu, boton_salir_juego]
	NavegacionMando.conectar_efecto_foco(controles)

	slider_musica.focus_neighbor_bottom = slider_efectos.get_path()
	slider_efectos.focus_neighbor_top = slider_musica.get_path()
	slider_efectos.focus_neighbor_bottom = boton_reiniciar.get_path()


	boton_reiniciar.focus_neighbor_top = slider_efectos.get_path()
	boton_reiniciar.focus_neighbor_right = boton_continuar.get_path()
	boton_reiniciar.focus_neighbor_bottom = boton_menu.get_path()

	boton_continuar.focus_neighbor_top = slider_efectos.get_path()
	boton_continuar.focus_neighbor_left = boton_reiniciar.get_path()
	boton_continuar.focus_neighbor_bottom = boton_salir_juego.get_path()

	boton_menu.focus_neighbor_top = boton_reiniciar.get_path()
	boton_menu.focus_neighbor_right = boton_salir_juego.get_path()

	boton_salir_juego.focus_neighbor_top = boton_continuar.get_path()
	boton_salir_juego.focus_neighbor_left = boton_menu.get_path()

func _on_visibility_changed():
	if visible:

		NavegacionMando.enfocar_con_seguridad(boton_continuar)
