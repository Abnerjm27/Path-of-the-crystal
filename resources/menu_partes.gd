extends Control

@export var controlador_partida: ControladorPartida
@export var musica_de_esta_escena: AudioStream
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ControladorMusica.reproducir(musica_de_esta_escena)
	controlador_partida.cargar_partida()
