class_name Menupausa
extends CanvasLayer

signal continuar
signal reiniciar
signal salir

@onready var slider_musica = $PanelOpciones/BoxContainer/Musica
@onready var slider_efectos = $PanelOpciones/BoxContainer/Efectos

func _ready():
	slider_musica.value_changed.connect(ControladorGlobal._cambiar_musica)
	slider_efectos.value_changed.connect(ControladorGlobal._cambiar_efectos)
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
