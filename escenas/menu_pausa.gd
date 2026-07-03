class_name Menupausa
extends CanvasLayer

signal continuar
signal reiniciar
signal salir
@onready var slider_musica = $PanelOpciones/BoxContainer/Musica
@onready var slider_efectos = $PanelOpciones/BoxContainer/Efectos

func _ready():
	slider_musica.value_changed.connect(_cambiar_musica)
	slider_efectos.value_changed.connect(_cambiar_efectos)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	slider_musica.value = ControladorGlobal.volumen_musica
	slider_efectos.value = ControladorGlobal.volumen_efectos

func _on_continuar_pressed():
	continuar.emit()

func _on_reiniciar_pressed():
	reiniciar.emit()

func _on_salir_pressed():
	salir.emit()
func _cambiar_musica(valor):

	var indice = AudioServer.get_bus_index("Musica")

	if valor == 0:
		AudioServer.set_bus_volume_db(indice, -80)
	else:
		AudioServer.set_bus_volume_db(indice, linear_to_db(valor / 100.0))
func _cambiar_efectos(valor):

	var indice = AudioServer.get_bus_index("Efectos")

	if valor == 0:
		AudioServer.set_bus_volume_db(indice, -80)
	else:
		AudioServer.set_bus_volume_db(indice, linear_to_db(valor / 100.0))
