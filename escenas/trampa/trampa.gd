class_name Abeja
extends RigidBody2D

@export var raycast: RayCast2D

var _indice_red: int = -1
var _ya_activada: bool = false


func _ready() -> void:
	if ControladorGlobal.es_partida_en_red:
		add_to_group(NetworkDiscovery.GRUPO_TRAMPAS_CAIDA_SINCRONIZABLES)
		
		var lista := get_tree().get_nodes_in_group(NetworkDiscovery.GRUPO_TRAMPAS_CAIDA_SINCRONIZABLES)
		_indice_red = lista.find(self)
		
		if not NetworkDiscovery.trampa_caida_recibida.is_connected(_on_trampa_caida_recibida):
			NetworkDiscovery.trampa_caida_recibida.connect(_on_trampa_caida_recibida)


func _physics_process(_delta: float) -> void:
	if _ya_activada:
		return

	# Usamos is_colliding() y validamos que el objeto detectado sea un personaje
	if raycast.is_colliding():
		var collider := raycast.get_collider() as Node2D
		if collider and collider.is_in_group("personajes"):
			_ya_activada = true
			if ControladorGlobal.es_partida_en_red:
				# Avisamos por red; la caída real se ejecuta simultáneamente en ambos peers
				NetworkDiscovery.enviar_trampa_caida(_indice_red)
			else:
				freeze = false


func _on_trampa_caida_recibida(indice: int) -> void:
	if indice == _indice_red:
		freeze = false
