extends AnimatableBody2D

@export var flip_h_manual: bool = false:
	set(valor):
		flip_h_manual = valor
		# Comprobación de seguridad para evitar errores al editar desde el Inspector
		if is_instance_valid(animacion):
			animacion.flip_h = valor

@onready var animacion: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	if is_instance_valid(animacion):
		animacion.flip_h = flip_h_manual
