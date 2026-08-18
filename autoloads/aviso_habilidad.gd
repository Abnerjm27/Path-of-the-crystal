extends CanvasLayer
# Autoload: AvisoHabilidad
# Banner estilo "nueva habilidad desbloqueada" (tipo Plants vs Zombies).
const NOMBRES := {
	"doble_salto": "¡Doble salto desbloqueado!",
	"dash": "¡Dash desbloqueado!",
	"vuelo": "¡Vuelo desbloqueado!",
}
# AJUSTA esta ruta a donde guardes los PNG
const TEXTURAS := {
	"doble_salto": preload("res://iconos/icono_doble_salto.png"),
	"dash": preload("res://iconos/icono_dash.png"),
	"vuelo": preload("res://iconos/icono_vuelo.png"),
}
var _panel: PanelContainer
var _label: Label
var _icono: TextureRect
var _mostrando := false
var _cola: Array = []
func _ready() -> void:
	layer = 100
	# NUEVO: contenedor que ocupa toda la pantalla y centra automáticamente
	# a su hijo, sin importar el tamaño que tenga (texto/ícono variable)
	var contenedor_centro := CenterContainer.new()
	contenedor_centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	contenedor_centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(contenedor_centro)
	_panel = PanelContainer.new()
	_panel.visible = false
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.1, 0.1, 0.15, 0.92)
	estilo.corner_radius_top_left = 16
	estilo.corner_radius_top_right = 16
	estilo.corner_radius_bottom_left = 16
	estilo.corner_radius_bottom_right = 16
	estilo.content_margin_left = 24
	estilo.content_margin_right = 24
	estilo.content_margin_top = 16
	estilo.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", estilo)
	contenedor_centro.add_child(_panel)   # NUEVO: se agrega al contenedor centrador, no directo al CanvasLayer
	var caja := VBoxContainer.new()
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 8)
	_panel.add_child(caja)
	var contenedor_icono := CenterContainer.new()
	contenedor_icono.custom_minimum_size = Vector2(100, 100)
	caja.add_child(contenedor_icono)
	_icono = TextureRect.new()
	_icono.custom_minimum_size = Vector2(80, 80)
	_icono.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	contenedor_icono.add_child(_icono)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 30)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(_label)
	ControladorGlobal.habilidad_desbloqueada.connect(mostrar_desbloqueo)
func mostrar_desbloqueo(id_habilidad: String) -> void:
	_cola.append(id_habilidad)
	if not _mostrando:
		_procesar_cola()
func _procesar_cola() -> void:
	if _cola.is_empty():
		_mostrando = false
		return
	_mostrando = true
	var id_habilidad: String = _cola.pop_front()
	_label.text = NOMBRES.get(id_habilidad, "¡Nueva habilidad desbloqueada!")
	_icono.texture = TEXTURAS.get(id_habilidad)
	_panel.visible = true
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(_panel, "scale", Vector2(1.1, 1.1), 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_panel, "modulate:a", 1.0, 0.2)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.15)
	tween.tween_interval(1.5)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.3)
	tween.finished.connect(_al_terminar_uno)
func _al_terminar_uno() -> void:
	_panel.visible = false
	_procesar_cola()
