extends CanvasLayer

# Indicador visual de ping. Pensado para agregarse como AUTOLOAD (no como
# parte de cada nivel), así aparece en cualquier escena en red sin tener
# que tocar los 20 niveles uno por uno.
#
# CÓMO AGREGARLO COMO AUTOLOAD:
# 1. Guardar este script en, por ejemplo, res://autoload/IndicadorPing.gd
# 2. En una escena nueva (Scene > New Scene), crear un nodo raíz CanvasLayer,
#    ponerle este script, y guardarla como res://autoload/IndicadorPing.tscn
# 3. Project Settings > Autoload > agregar esa escena (no solo el script,
#    la ESCENA, para que el Label se cree solo).
#    Si preferís no crear el Label a mano en el editor, este script lo
#    arma por código en _ready(), así que alcanza con el CanvasLayer vacío.

var _label: Label
var _timer_actualizacion: Timer

func _ready() -> void:
	layer = 100  # por encima de casi todo

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	_label.position = Vector2(12, 12)
	add_child(_label)

	_timer_actualizacion = Timer.new()
	_timer_actualizacion.wait_time = 0.5
	_timer_actualizacion.autostart = true
	_timer_actualizacion.timeout.connect(_actualizar)
	add_child(_timer_actualizacion)

	_actualizar()

func _actualizar() -> void:
	if not ControladorGlobal.es_partida_en_red:
		_label.visible = false
		return

	var ping_ms := NetworkDiscovery.obtener_ping_ms()
	if ping_ms < 0.0:
		_label.visible = false
		return

	_label.visible = true
	_label.text = "Ping: %d ms" % int(round(ping_ms))

	# Color según qué tan buena está la conexión, para ver de un vistazo
	# si vale la pena sospechar de la red antes de sospechar del código.
	if ping_ms < 60.0:
		_label.modulate = Color(0.4, 1.0, 0.4)   # verde: red muy bien
	elif ping_ms < 150.0:
		_label.modulate = Color(1.0, 0.9, 0.3)   # amarillo: aceptable
	else:
		_label.modulate = Color(1.0, 0.4, 0.4)   # rojo: sospechar de la red
