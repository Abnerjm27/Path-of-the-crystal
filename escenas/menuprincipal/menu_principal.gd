extends Control
@export var musica_de_esta_escena: AudioStream
@onready var menu_opciones = $MenuOpciones

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ControladorMusica.reproducir(musica_de_esta_escena)
func _on_boton_opciones_pressed():
	menu_opciones.visible = true
func _on_menu_opciones_volver():
	menu_opciones.visible = false
