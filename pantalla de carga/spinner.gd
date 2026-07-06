extends Control

@export var color_spinner: Color = Color(1, 1, 1)  # blanco por defecto, cámbialo a tu gusto
@export var grosor: float = 6.0
@export var radio: float = 24.0
@export var velocidad: float = 2.0  # vueltas por segundo aprox.

func _ready():
	pivot_offset = size / 2
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "rotation_degrees", 360.0, velocidad).as_relative()

func _draw():
	var centro = size / 2
	var angulo_inicio = 0.0
	var angulo_fin = 4.7  # aprox 270°, deja un "hueco" de 90° para el efecto de giro
	draw_arc(centro, radio, angulo_inicio, angulo_fin, 64, color_spinner, grosor, true)
