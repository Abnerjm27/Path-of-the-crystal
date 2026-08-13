extends TextureRect

func _ready() -> void:
	if OS.has_feature("mobile"):
		visible = false
