class_name CinematicaBase
extends Node2D

signal cinematica_terminada

@onready var camara: Camera2D = $CamaraCinematica
@onready var barra_superior: ColorRect = $UI/BarraSuperior
@onready var barra_inferior: ColorRect = $UI/BarraInferior
@onready var cartela: Label = $UI/Cartela
@onready var boton_saltar: Button = $UI/BotonSaltar

var _saltada := false
var _tween_actual: Tween
func _ready() -> void:
	camara.make_current()

	# Forzamos los anclajes por código para no depender de que el preset
	# se haya configurado bien a mano en el editor — así la barra
	# inferior siempre crece desde el piso hacia arriba, y la superior
	# desde el techo hacia abajo, sin importar el estado previo.
	barra_superior.set_anchors_preset(Control.PRESET_TOP_WIDE)
	barra_superior.offset_top = 0.0
	barra_superior.offset_bottom = 0.0

	barra_inferior.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	barra_inferior.offset_top = 0.0
	barra_inferior.offset_bottom = 0.0

	cartela.modulate.a = 0.0
	boton_saltar.pressed.connect(_on_saltar_pressed)

	_preparar()
	await _animar_entrada_barras()
	await _reproducir()
	if not _saltada:
		await _terminar()
	barra_inferior.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	barra_inferior.size.y = 0.0
	barra_inferior.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	barra_inferior.grow_vertical = Control.GROW_DIRECTION_BEGIN   # NUEVO: crece hacia arriba, no hacia abajo
	barra_inferior.size.y = 0.0
	# --- DEBUG temporal ---
	print("Viewport size: ", get_viewport_rect().size)
	print("BarraSuperior anchor_top/bottom: ", barra_superior.anchor_top, " / ", barra_superior.anchor_bottom)
	print("BarraSuperior position/size: ", barra_superior.position, " / ", barra_superior.size)
	print("BarraInferior anchor_top/bottom: ", barra_inferior.anchor_top, " / ", barra_inferior.anchor_bottom)
	print("BarraInferior position/size: ", barra_inferior.position, " / ", barra_inferior.size)
# --- Sobrescribir en cada cinemática concreta ---
func _preparar() -> void:
	pass

func _reproducir() -> void:
	pass

# --- Herramientas disponibles para las cinemáticas hijas ---
func _mover_camara(destino: Vector2, zoom: Vector2, duracion: float) -> void:
	if _saltada:
		return
	var tween := create_tween().set_parallel(true)
	_tween_actual = tween
	tween.tween_property(camara, "global_position", destino, duracion).set_trans(Tween.TRANS_SINE)
	tween.tween_property(camara, "zoom", zoom, duracion).set_trans(Tween.TRANS_SINE)
	await tween.finished

func _mover_personaje(personaje: Node2D, destino: Vector2, duracion: float) -> void:
	if _saltada:
		return
	var tween := create_tween()
	_tween_actual = tween
	tween.tween_property(personaje, "global_position", destino, duracion).set_trans(Tween.TRANS_SINE)
	await tween.finished

func _mostrar_texto(texto: String, duracion: float) -> void:
	if _saltada:
		return
	cartela.text = texto
	var tween := create_tween()
	_tween_actual = tween
	tween.tween_property(cartela, "modulate:a", 1.0, 0.3)
	tween.tween_interval(duracion)
	tween.tween_property(cartela, "modulate:a", 0.0, 0.3)
	await tween.finished

func _esperar(segundos: float) -> void:
	if _saltada:
		return
	await get_tree().create_timer(segundos).timeout
func _animar_entrada_barras() -> void:
	var alto_barra := 90.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(barra_superior, "offset_bottom", alto_barra, 0.4)
	tween.tween_property(barra_inferior, "offset_top", -alto_barra, 0.4)
	await tween.finished

func _animar_salida_barras() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(barra_superior, "offset_bottom", 0.0, 0.4)
	tween.tween_property(barra_inferior, "offset_top", 0.0, 0.4)
	await tween.finished
# --- Saltar cinemática ---
func _on_saltar_pressed() -> void:
	if _saltada:
		return
	if ControladorGlobal.es_partida_en_red:
		NetworkDiscovery.enviar_saltar_cinematica()
	_ejecutar_salto()

func _ejecutar_salto() -> void:
	if _saltada:
		return
	_saltada = true
	if is_instance_valid(_tween_actual):
		_tween_actual.kill()
		_tween_actual.finished.emit()
	await _terminar()
func _terminar() -> void:
	if not is_inside_tree():
		return
	await _animar_salida_barras()
	cinematica_terminada.emit()
	queue_free()
