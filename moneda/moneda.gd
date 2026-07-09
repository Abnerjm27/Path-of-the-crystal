class_name Moneda
extends Node2D

const TEXTO_FLOTANTE = preload("res://escenas/texto_flotante.tscn")  

@export var area_2d: Area2D
@export var reproductor: AudioStreamPlayer2D
var contenedor_monedas: ContenedorMonedas

func _ready() -> void:
	area_2d.body_entered.connect(_recogida)
	_iniciar_animacion()

func _recogida(_body):
	contenedor_monedas.moneda_recogida()
	reproductor.reparent(get_parent())
	reproductor.play()
	
	var texto = TEXTO_FLOTANTE.instantiate()
	texto.global_position = global_position
	get_parent().add_child(texto)
	
	queue_free()

func _iniciar_animacion():
	var tween: Tween = create_tween()
	tween.set_loops(0)
	tween.tween_property(self, "position:y", position.y - 5, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:y", position.y + 5, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
