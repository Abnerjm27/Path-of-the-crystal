extends Node

@onready var player: AudioStreamPlayer = AudioStreamPlayer.new()
@export var volumen_normal_db: float = 0.0      # el volumen normal al que vuelve después del fundido
@export var duracion_fundido: float = 0.6        # segundos que dura cada bajada/subida de volumen
const VOLUMEN_SILENCIO_DB = -40.0                # "silencio" práctico (evitamos -INF, da problemas al interpolar)

var _tween: Tween

func _ready():
	add_child(player)
	player.bus = "Musica"
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue sonando aunque el juego esté en pausa
	player.volume_db = volumen_normal_db

func reproducir(cancion: AudioStream, forzar_reinicio: bool = false):
	if player.stream == cancion and not forzar_reinicio:
		return  # ya está sonando esta misma canción, no interrumpimos nada
	
	if _tween:
		_tween.kill()
	
	if player.playing:
		# Ya hay una canción sonando: la bajamos suave, cambiamos, y subimos la nueva
		_tween = create_tween()
		_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # el fundido sigue aunque el juego esté pausado
		_tween.tween_property(player, "volume_db", VOLUMEN_SILENCIO_DB, duracion_fundido)
		_tween.tween_callback(func():
			player.stream = cancion
			player.volume_db = VOLUMEN_SILENCIO_DB
			player.play()
		)
		_tween.tween_property(player, "volume_db", volumen_normal_db, duracion_fundido)
	else:
		# No había nada sonando: entra directo con un fundido de entrada nada más
		player.stream = cancion
		player.volume_db = VOLUMEN_SILENCIO_DB
		player.play()
		_tween = create_tween()
		_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tween.tween_property(player, "volume_db", volumen_normal_db, duracion_fundido)

func detener():
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(player, "volume_db", VOLUMEN_SILENCIO_DB, duracion_fundido)
	_tween.tween_callback(player.stop)

func pausar():
	player.stream_paused = true

func reanudar():
	player.stream_paused = false
