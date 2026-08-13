extends AnimatableBody2D

@export var flip_h_manual: bool = false:
	set(valor):
		flip_h_manual = valor
		if animacion:
			animacion.flip_h = valor

@onready var animacion: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	animacion.flip_h = flip_h_manual
