class_name Abeja
extends RigidBody2D

@export var raycast: RayCast2D

var _indice_red: int = -1
var _ya_activada := false

func _ready() -> void:
	if ControladorGlobal.es_partida_en_red:
		add_to_group(NetworkDiscovery.GRUPO_TRAMPAS_CAIDA_SINCRONIZABLES)
		# Mismo truco que con los animadores: identificamos esta abeja por
		# su posición dentro del grupo, no por nombre ni NodePath, porque
		# eso es estable entre host y cliente (misma escena, mismo orden).
		_indice_red = get_tree().get_nodes_in_group(NetworkDiscovery.GRUPO_TRAMPAS_CAIDA_SINCRONIZABLES).find(self)
		if not NetworkDiscovery.trampa_caida_recibida.is_connected(_on_trampa_caida_recibida):
			NetworkDiscovery.trampa_caida_recibida.connect(_on_trampa_caida_recibida)

func _physics_process(_delta: float) -> void:
	if _ya_activada:
		return

	if raycast.get_collider() != null:
		_ya_activada = true
		if ControladorGlobal.es_partida_en_red:
			# No nos descongelamos solos: avisamos por red, y la
			# descongelada real llega por _on_trampa_caida_recibida
			# (así cae en las DOS pantallas al mismo tiempo, aunque solo
			# el jugador de ESTA pantalla haya activado el raycast).
			NetworkDiscovery.enviar_trampa_caida(_indice_red)
		else:
			freeze = false

func _on_trampa_caida_recibida(indice: int) -> void:
	if indice == _indice_red:
		freeze = false
