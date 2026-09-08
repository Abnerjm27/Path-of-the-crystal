class_name Moneda
extends Node2D

const TEXTO_FLOTANTE = preload("res://escenas/texto_flotante.tscn")

@export var area_2d: Area2D
@export var reproductor: AudioStreamPlayer2D

var contenedor_monedas: ContenedorMonedas
var indice_moneda: int = -1   # Lo asigna el contenedor en su _ready()
var _ya_recogida: bool = false
var _posicion_inicial_y: float = 0.0


func _ready() -> void:
	_posicion_inicial_y = position.y
	if is_instance_valid(area_2d):
		area_2d.body_entered.connect(_recogida)
	_iniciar_animacion()


func _recogida(body: Node2D) -> void:
	if _ya_recogida:
		return

	# En red, solo el personaje controlado localmente por ESTE peer recoge la moneda
	if body is Personaje:
		var personaje := body as Personaje
		if ControladorGlobal.es_partida_en_red and not personaje.es_mio_localmente():
			return

	_ejecutar_recogida(true)


func _ejecutar_recogida(avisar_red: bool) -> void:
	if _ya_recogida:
		return
	_ya_recogida = true

	# Deshabilitar área inmediatamente para prevenir activaciones repetidas
	if is_instance_valid(area_2d):
		area_2d.set_deferred("monitoring", false)
		area_2d.set_deferred("monitorable", false)

	# Notificar al contenedor de monedas local/red
	if is_instance_valid(contenedor_monedas):
		contenedor_monedas.moneda_recogida(indice_moneda, not avisar_red)

	# Reproducción de sonido independiente
	if is_instance_valid(reproductor):
		var parent := get_parent()
		if is_instance_valid(parent):
			reproductor.reparent(parent)
			reproductor.play()
			reproductor.finished.connect(reproductor.queue_free)

	# Instanciar el texto flotante informativo
	if TEXTO_FLOTANTE:
		var texto := TEXTO_FLOTANTE.instantiate() as Node2D
		if texto:
			texto.global_position = global_position
			var parent := get_parent()
			if is_instance_valid(parent):
				parent.add_child(texto)

	queue_free()


# Llamado desde el contenedor cuando el OTRO peer recoge esta moneda
func recoger_a_distancia() -> void:
	_ejecutar_recogida(false)


func _iniciar_animacion() -> void:
	var tween := create_tween()
	tween.set_loops() # Loop infinito
	tween.tween_property(self, "position:y", _posicion_inicial_y - 5.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:y", _posicion_inicial_y + 5.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
