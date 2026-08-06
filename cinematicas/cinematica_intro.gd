extends CinematicaBase

@onready var personaje: Node2D = $personaje
@onready var jefe: Node2D = $JefeCinematica
@onready var punto_caverna: Marker2D = $PuntoCaverna
@onready var punto_acercamiento: Marker2D = $PuntoAcercamiento
@onready var audio_risa: AudioStreamPlayer = $AudioRisa
@onready var audio_voz: AudioStreamPlayer = $AudioVoz
@onready var musica_ambiente: AudioStreamPlayer = $MusicaAmbiente
@onready var musica_tension: AudioStreamPlayer = $MusicaTension
@onready var audio_cuerno_tension: AudioStreamPlayer = $AudioCuernoTension

const VOLUMEN_AMBIENTE_DB = -5.0
const VOLUMEN_TENSION_DB = -3.0
const VOLUMEN_SILENCIO_DB = -40.0

const VOZ_NARRADOR_1 = preload("res://audio/voces/narrador_leyendas.ogg")
const VOZ_NARRADOR_2 = preload("res://audio/voces/narrador_algo_se_mueve.ogg")
const VOZ_GUARDIAN_1 = preload("res://audio/voces/guardian_quien_osa.ogg")
const VOZ_PERSONAJE_1 = preload("res://audio/voces/personaje_solo_busco.ogg")
const VOZ_GUARDIAN_2 = preload("res://audio/voces/guardian_todos_dicen_lo_mismo.ogg")
const VOZ_GUARDIAN_3 = preload("res://audio/voces/guardian_moriras.ogg")
const VOZ_PERSONAJE_2 = preload("res://audio/voces/personaje_no_hay_marcha_atras.ogg")
const VOZ_GUARDIAN_4 = preload("res://audio/voces/guardian_nadie_profana.ogg")
const VOZ_GUARDIAN_5 = preload("res://audio/voces/guardian_oscuridad_te_ensene.ogg")


func _preparar() -> void:
	camara.global_position = personaje.global_position
	camara.zoom = Vector2(1.0, 1.0)

	personaje.set_physics_process(false)
	personaje.set_process(false)
	if personaje is CharacterBody2D:
		personaje.velocity = Vector2.ZERO
		personaje.collision_layer = 0
		personaje.collision_mask = 0
	if personaje.area_2d:
		personaje.area_2d.monitoring = false
		personaje.area_2d.monitorable = false
	ControladorMusica.atenuar(-100.0, 1.0)

	musica_ambiente.volume_db = VOLUMEN_SILENCIO_DB
	musica_tension.volume_db = VOLUMEN_SILENCIO_DB
	musica_ambiente.play()

	var tween_entrada := create_tween()
	tween_entrada.tween_property(musica_ambiente, "volume_db", VOLUMEN_AMBIENTE_DB, 1.0)

func _iniciar_tension_ambiente(duracion: float = 0.8) -> void:
	musica_tension.play()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(musica_ambiente, "volume_db", VOLUMEN_SILENCIO_DB, duracion)
	tween.tween_property(musica_tension, "volume_db", VOLUMEN_TENSION_DB, duracion)

func _golpe_cuerno_tension() -> void:
	if audio_cuerno_tension:
		audio_cuerno_tension.play()

func _mostrar_texto_con_voz(texto: String, voz: AudioStream, duracion_extra: float = 0.4) -> void:
	if _saltada:
		return
	var duracion := duracion_extra
	if voz:
		audio_voz.stream = voz
		audio_voz.play()
		duracion = voz.get_length() + duracion_extra
	await _mostrar_texto(texto, duracion)

func _reproducir() -> void:
	await _mostrar_texto_con_voz("Las leyendas hablan de cristales que laten con la luz de los primeros tiempos... y de algo que las protege desde las sombras.", VOZ_NARRADOR_1)
	await _mostrar_texto_con_voz("Algo se mueve entre las sombras de la caverna.", VOZ_NARRADOR_2)
	await _mover_camara(punto_acercamiento.global_position, Vector2(1.8, 1.8), 1.5)

	var jefe_sprite: AnimatedSprite2D = null
	if jefe.has_node("AnimatedSprite2D"):
		jefe_sprite = jefe.get_node("AnimatedSprite2D")

	var personaje_sprite: AnimatedSprite2D = null
	if personaje.has_node("AnimatedSprite2D"):
		personaje_sprite = personaje.get_node("AnimatedSprite2D")

	await _mostrar_texto_con_voz("Guardián: ¿Quién osa profanar este lugar sagrado? Ningún mortal ha puesto un pie aquí en mil generaciones... y tú crees que serás la excepción.", VOZ_GUARDIAN_1)
	await _mostrar_texto_con_voz("Tú: Solo busco el cristal. No quiero pelear contigo, guardián. Solo necesito pasar.", VOZ_PERSONAJE_1)
	await _mostrar_texto_con_voz("Guardián: Todos dicen lo mismo antes de intentarlo. Y todos terminan igual: rotos, en el fondo de este abismo, alimentando el silencio de esta caverna.", VOZ_GUARDIAN_2)
	await _mostrar_texto_con_voz("Guardián: Entonces morirás sin haberlo intentado siquiera.", VOZ_GUARDIAN_3)

	await _mostrar_texto_con_voz("No hay marcha atrás.", VOZ_PERSONAJE_2)

	if jefe_sprite:
		jefe_sprite.flip_h = jefe.global_position.x > personaje.global_position.x
		jefe_sprite.play("correr")
	if personaje_sprite:
		personaje_sprite.flip_h = personaje.global_position.x > jefe.global_position.x
		personaje_sprite.play("correr")

	var punto_encuentro_jefe := jefe.global_position.lerp(personaje.global_position, 0.4)
	var punto_encuentro_personaje := jefe.global_position.lerp(personaje.global_position, 0.6)
	await _mover_dos_personajes(jefe, punto_encuentro_jefe, personaje, punto_encuentro_personaje, 0.7)

	if jefe_sprite:
		jefe_sprite.stop()
	if personaje_sprite:
		personaje_sprite.stop()

	# El colchón de tensión (tambores) entra apenas se encuentran
	_iniciar_tension_ambiente(0.6)

	# El cuerno suena justo en el grito — el golpe de impacto
	_golpe_cuerno_tension()

	await _mostrar_texto_con_voz("¡Nadie profana estas cavernas... y vive para contarlo!", VOZ_GUARDIAN_4)

	if jefe_sprite:
		jefe_sprite.flip_h = jefe.global_position.x > personaje.global_position.x
		jefe_sprite.play("cargar")

	if audio_risa:
		audio_risa.play()

	await _esperar(0.4)

	await _lanzar_personaje(personaje, punto_caverna.global_position, 1.0)

	if jefe_sprite:
		jefe_sprite.stop()

	await _mostrar_texto_con_voz("¡Que la oscuridad te enseñe lo que la razón no pudo!", VOZ_GUARDIAN_5)


func _terminar() -> void:
	var tween_salida := create_tween().set_parallel(true)
	tween_salida.tween_property(musica_ambiente, "volume_db", VOLUMEN_SILENCIO_DB, 0.8)
	tween_salida.tween_property(musica_tension, "volume_db", VOLUMEN_SILENCIO_DB, 0.8)
	ControladorMusica.restaurar(1.0)
	super._terminar()

func _mover_dos_personajes(nodo_a: Node2D, destino_a: Vector2, nodo_b: Node2D, destino_b: Vector2, duracion: float) -> void:
	if _saltada:
		return
	var tween := create_tween().set_parallel(true)
	_tween_actual = tween
	tween.tween_property(nodo_a, "global_position", destino_a, duracion).set_trans(Tween.TRANS_SINE)
	tween.tween_property(nodo_b, "global_position", destino_b, duracion).set_trans(Tween.TRANS_SINE)
	await tween.finished

func _lanzar_personaje(personaje: Node2D, destino: Vector2, duracion: float) -> void:
	if _saltada:
		return
	var origen := personaje.global_position
	var punto_medio := origen.lerp(destino, 0.5)
	punto_medio.y -= 60.0

	var tween := create_tween().set_parallel(true)
	_tween_actual = tween
	tween.tween_method(
		func(t: float):
			var p1 := origen.lerp(punto_medio, t)
			var p2 := punto_medio.lerp(destino, t)
			personaje.global_position = p1.lerp(p2, t),
		0.0, 1.0, duracion
	).set_trans(Tween.TRANS_SINE)
	tween.tween_property(personaje, "rotation_degrees", 720.0, duracion).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	personaje.rotation_degrees = 0.0
