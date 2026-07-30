class_name Moneda
extends Node2D
const TEXTO_FLOTANTE = preload("res://escenas/texto_flotante.tscn")  
@export var area_2d: Area2D
@export var reproductor: AudioStreamPlayer2D
var contenedor_monedas: ContenedorMonedas
var indice_moneda: int = -1   # NUEVO: lo asigna el contenedor en su _ready()
var _ya_recogida := false  

func _ready() -> void:
	area_2d.body_entered.connect(_recogida)
	_iniciar_animacion()

func _recogida(body):
	if _ya_recogida:
		return
	# NUEVO: en red, solo el dueño local de un personaje puede "recogerla de verdad"
	# (el muñeco remoto ya no colisiona gracias al fix de collision_layer, pero
	# esta comprobación es una seguridad extra si algún día cambia eso)
	if ControladorGlobal.es_partida_en_red and body.has_method("es_mio_localmente"):
		if not body.es_mio_localmente():
			return
	_ejecutar_recogida(true)

func _ejecutar_recogida(avisar_red: bool) -> void:
	if _ya_recogida:
		return
	_ya_recogida = true
	
	contenedor_monedas.moneda_recogida(indice_moneda, not avisar_red)
	
	reproductor.reparent(get_parent())
	reproductor.play()
	
	var texto = TEXTO_FLOTANTE.instantiate()
	texto.global_position = global_position
	get_parent().add_child(texto)
	
	queue_free()

# NUEVO: llamado desde el contenedor cuando el OTRO peer ya la recogió
func recoger_a_distancia() -> void:
	_ejecutar_recogida(false)

func _iniciar_animacion():
	var tween: Tween = create_tween()
	tween.set_loops(0)
	tween.tween_property(self, "position:y", position.y - 5, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:y", position.y + 5, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
