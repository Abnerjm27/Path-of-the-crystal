
extends Node

@onready var player: AudioStreamPlayer = AudioStreamPlayer.new()

func _ready():
	add_child(player)
	player.bus = "Musica"
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue sonando aunque el juego esté en pausa

func reproducir(cancion: AudioStream, forzar_reinicio: bool = false):
	if player.stream != cancion or forzar_reinicio:
		player.stream = cancion
		player.play()

func detener():
	player.stop()

func pausar():
	player.stream_paused = true

func reanudar():
	player.stream_paused = false
