extends Node2D


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("personajes"):
		queue_free()


func _on_area_2d_2_body_entered(body: Node2D) -> void:
	if not body.is_in_group("personajes"):
		return
	# En red solo el host aplica daño; el cliente nunca debe recargar la escena
	if ControladorGlobal.es_partida_en_red and not NetworkDiscovery.soy_host():
		return
	if body.has_method("morir"):
		body.morir()
