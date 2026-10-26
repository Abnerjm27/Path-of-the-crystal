extends CollisionShape2D

func _on_area_2d_body_entered(body: Node2D) -> void:
	# Corregido: era "player", el grupo correcto es "personajes"
	if not body.is_in_group("personajes"):
		return
	# En red solo el host gestiona colisiones
	if ControladorGlobal.es_partida_en_red and not NetworkDiscovery.soy_host():
		return
	queue_free()
