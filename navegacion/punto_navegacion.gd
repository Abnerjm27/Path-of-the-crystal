@tool
class_name PuntoNavegacion
extends Marker2D

## Un punto de navegación que los enemigos (como el Boss) utilizarán para moverse.
## Arrastra este nodo al nivel en lugares clave (bordes de plataformas, suelo, lugares donde saltar).

func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("puntos_navegacion")
		
		# Ocultamos el marcador en el juego final, pero lo dejamos visible en el editor.
		visible = false

func _draw() -> void:
	if Engine.is_editor_hint():
		# Dibuja un círculo visual en el editor para que el creador de niveles lo vea fácilmente
		draw_circle(Vector2.ZERO, 10.0, Color(0.2, 0.8, 0.2, 0.7))
		draw_arc(Vector2.ZERO, 10.0, 0, TAU, 16, Color.WHITE, 2.0)
