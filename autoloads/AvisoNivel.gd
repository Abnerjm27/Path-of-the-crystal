extends CanvasLayer

var label: Label
var panel: PanelContainer

func _ready() -> void:
	layer = 100  # que quede por encima de todo

	panel = PanelContainer.new()
	panel.modulate.a = 0.0
	panel.visible = false

	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position.y = 40

	label = Label.new()
	label.add_theme_font_size_override("font_size", 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	panel.add_child(label)
	add_child(panel)

func mostrar_nivel(texto: String, duracion: float = 0.6) -> void:
	label.text = texto
	panel.modulate.a = 0.0
	panel.visible = true

	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	tween.tween_interval(duracion)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.finished.connect(_al_terminar)

func _al_terminar() -> void:
	panel.visible = false
