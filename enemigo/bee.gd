extends Node2D



func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("personajes"):
		queue_free()
	

func _on_area_2d_2_body_entered(body: Node2D) -> void:
	if body.is_in_group("personajes"):
		get_tree().reload_current_scene()
