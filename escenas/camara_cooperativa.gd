extends Camera2D
class_name CamaraCooperativa

var jugador1: Node2D
var jugador2: Node2D

@export var zoom_base: Vector2 = Vector2(1, 1)          
@export var distancia_zoom_maximo: float = 1200.0         # distancia entre jugadores a la que ya se alcanza el alejamiento máximo
@export var alejamiento_maximo: float = 2.8              # cuánto se suma al zoom_base como máximo (más alto = se aleja más)
@export var velocidad_suavizado: float = 5.0

func _ready():
	position_smoothing_enabled = false

func configurar(j1: Node2D, j2: Node2D, zoom_del_nivel: Vector2):
	jugador1 = j1
	jugador2 = j2
	zoom_base = zoom_del_nivel
	zoom = zoom_base
	if jugador1 and jugador2:
		global_position = (jugador1.global_position + jugador2.global_position) / 2.0
	elif jugador1:
		global_position = jugador1.global_position

func _physics_process(delta):
	if jugador1 == null or not is_instance_valid(jugador1):
		return
	
	var objetivo_posicion: Vector2
	var objetivo_zoom: Vector2
	
	if jugador2 != null and is_instance_valid(jugador2):
		objetivo_posicion = (jugador1.global_position + jugador2.global_position) / 2.0
		
		var distancia = jugador1.global_position.distance_to(jugador2.global_position)
		var factor = clamp(distancia / distancia_zoom_maximo, 0.0, 1.0)
		# zoom más alto = cámara más alejada, por eso SUMAMOS al alejarse
		objetivo_zoom = zoom_base + Vector2(factor, factor) * alejamiento_maximo
	else:
		# el Jugador 2 murió o no existe: volvemos a seguir solo al Jugador 1
		objetivo_posicion = jugador1.global_position
		objetivo_zoom = zoom_base
	
	global_position = global_position.lerp(objetivo_posicion, velocidad_suavizado * delta)
	zoom = zoom.lerp(objetivo_zoom, velocidad_suavizado * delta)
