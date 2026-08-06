extends CinematicaBase

@onready var panel_actual: TextureRect = $UI/PanelActual
@onready var audio_voz: AudioStreamPlayer = $AudioVoz
@onready var musica_ambiente: AudioStreamPlayer = $MusicaAmbiente     # NUEVO
@onready var musica_encuentro: AudioStreamPlayer = $MusicaEncuentro   # NUEVO

const VOLUMEN_AMBIENTE_DB = -10.0    # NUEVO: colchón suave de fondo
const VOLUMEN_ENCUENTRO_DB = -3.0    # NUEVO: la melodía del reencuentro, más presente
const VOLUMEN_SILENCIO_DB = -40.0    # NUEVO

const PANEL_A = preload("res://cinematicas/final/panel_a_cristal.png")
const PANEL_B = preload("res://cinematicas/final/panel_b_luz_tunel.png")
const PANEL_C = preload("res://cinematicas/final/panel_c_salida_cueva.png")
const PANEL_D = preload("res://cinematicas/final/panel_d_reconocimiento.png")
const PANEL_E = preload("res://cinematicas/final/panel_e_abrazo.png")
const PANEL_F = preload("res://cinematicas/final/panel_f_atardecer.png")

const VOZ_1 = preload("res://audio/voces/final/1.ogg")
const VOZ_2 = preload("res://audio/voces/final/2.ogg")
const VOZ_3 = preload("res://audio/voces/final/3.ogg")
const VOZ_4 = preload("res://audio/voces/final/4.ogg")
const VOZ_5 = preload("res://audio/voces/final/5.ogg")
const VOZ_6 = preload("res://audio/voces/final/6.ogg") # PENDIENTE: falta regrabar
const VOZ_7 = preload("res://audio/voces/final/7.ogg")
const VOZ_8 = preload("res://audio/voces/final/8.ogg")
const VOZ_9 = preload("res://audio/voces/final/9.ogg")

const VOZ_PAREJA_1 = preload("res://audio/voces/final/pareja_1.ogg")
const VOZ_PAREJA_2 = preload("res://audio/voces/final/pareja_2.ogg")
const VOZ_PAREJA_3 = preload("res://audio/voces/final/pareja_3.ogg")

func _preparar() -> void:
	panel_actual.texture = PANEL_A
	panel_actual.modulate.a = 1.0
	panel_actual.scale = Vector2(1.0, 1.0)
	panel_actual.pivot_offset = panel_actual.size / 2.0

	# NUEVO: baja la música global del juego y arranca el colchón ambiente propio
	ControladorMusica.atenuar(-100.0, 1.0)

	musica_ambiente.volume_db = VOLUMEN_SILENCIO_DB
	musica_encuentro.volume_db = VOLUMEN_SILENCIO_DB
	musica_ambiente.play()

	var tween_entrada := create_tween()
	tween_entrada.tween_property(musica_ambiente, "volume_db", VOLUMEN_AMBIENTE_DB, 1.0)

# NUEVO: crossfade del colchón ambiente hacia la melodía del reencuentro
func _iniciar_musica_encuentro(duracion: float = 1.2) -> void:
	musica_encuentro.play()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(musica_ambiente, "volume_db", VOLUMEN_SILENCIO_DB, duracion)
	tween.tween_property(musica_encuentro, "volume_db", VOLUMEN_ENCUENTRO_DB, duracion)

func _mostrar_texto_con_voz(texto: String, voz: AudioStream, duracion_extra: float = 0.4) -> void:
	if _saltada:
		return
	var duracion := duracion_extra
	if voz:
		audio_voz.stream = voz
		audio_voz.play()
		duracion = voz.get_length() + duracion_extra
	await _mostrar_texto(texto, duracion)

func _cambiar_panel(textura: Texture2D, duracion_zoom: float = 3.0) -> void:
	if _saltada:
		return
	var panel_nuevo := TextureRect.new()
	panel_nuevo.texture = textura
	panel_nuevo.expand_mode = panel_actual.expand_mode
	panel_nuevo.stretch_mode = panel_actual.stretch_mode
	panel_nuevo.anchor_right = 1.0
	panel_nuevo.anchor_bottom = 1.0
	panel_nuevo.modulate.a = 0.0
	panel_nuevo.scale = Vector2(1.0, 1.0)
	panel_actual.get_parent().add_child(panel_nuevo)
	panel_nuevo.pivot_offset = panel_nuevo.size / 2.0
	panel_actual.get_parent().move_child(panel_nuevo, panel_actual.get_index())

	var tween := create_tween().set_parallel(true)
	_tween_actual = tween
	tween.tween_property(panel_nuevo, "modulate:a", 1.0, 0.6)
	tween.tween_property(panel_actual, "modulate:a", 0.0, 0.6)
	tween.tween_property(panel_nuevo, "scale", Vector2(1.08, 1.08), duracion_zoom)
	await tween.finished

	panel_actual.queue_free()
	panel_actual = panel_nuevo

func _reproducir() -> void:
	# Panel A — el cristal
	await _mostrar_texto_con_voz("Lo logré. Después de todo... de cada caída, cada golpe, cada noche pensando que no iba a salir de aquí... lo logré.", VOZ_1)
	await _mostrar_texto_con_voz("Esto era lo único que nos separaba. Solo esto.", VOZ_2)

	# Panel B — la luz en el túnel
	await _cambiar_panel(PANEL_B)
	await _mostrar_texto_con_voz("Esa luz... ¿es real? Pensé que no volvería a verla.", VOZ_3)

	# Panel C — saliendo de la cueva
	await _cambiar_panel(PANEL_C)
	await _mostrar_texto_con_voz("Cada paso que doy pesa menos. Es como si este lugar, que casi se convierte en mi tumba... por fin me estuviera dejando ir.", VOZ_4)
	await _mostrar_texto_con_voz("Aguanta un poco más. Ya casi llego. Te lo prometí, y voy a cumplirlo.", VOZ_5)

	# Panel D — el reconocimiento (clímax, pausa larga)
	await _cambiar_panel(PANEL_D)
	_iniciar_musica_encuentro(1.2)   # NUEVO: entra la melodía del reencuentro justo aquí
	await _mostrar_texto_con_voz("...¿Eres tú? ¿De verdad eres tú? Dime que no estoy soñando esto también.", VOZ_6)
	# CAMBIO: se quitó el _mostrar_texto duplicado que repetía el mismo texto sin voz
	await _esperar(1.2)  # la pausa larga actuada antes del abrazo

	# Panel E — el abrazo
	await _mostrar_texto_con_voz("Volví. Te dije que iba a volver, y volví.", VOZ_7)
	await _cambiar_panel(PANEL_E)
	await _mostrar_texto_con_voz("Nunca dejé de esperarte. Ni un solo día. Ni una sola noche.", VOZ_PAREJA_1)
	await _mostrar_texto_con_voz("Se terminó de verdad, ¿no? No es otro sueño más de esos que tenía para poder dormir.", VOZ_PAREJA_2)
	await _mostrar_texto_con_voz("No. Este no. Este es real. Te lo juro.", VOZ_8)

	# Panel F — cierre, atardecer
	await _cambiar_panel(PANEL_F)
	await _mostrar_texto_con_voz("Cada cristal, cada caída, cada cicatriz que me llevo... todo valió la pena por este momento. Por ti.", VOZ_9)
	await _mostrar_texto_con_voz("Y yo no pienso volver a dejarte ir.", VOZ_PAREJA_3)

# NUEVO: apaga la música propia y le devuelve el volumen a la música global
# del juego antes de que la cinemática se destruya
func _terminar() -> void:
	var tween_salida := create_tween().set_parallel(true)
	tween_salida.tween_property(musica_ambiente, "volume_db", VOLUMEN_SILENCIO_DB, 1.0)
	tween_salida.tween_property(musica_encuentro, "volume_db", VOLUMEN_SILENCIO_DB, 1.0)
	ControladorMusica.restaurar(1.5)
	super._terminar()
