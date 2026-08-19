extends TouchScreenButton

@export var opacidad_normal: float = 0.65
@export var opacidad_presionado: float = 0.4
@export var factor_escala_presionado: float = 0.92

var _escala_normal: Vector2
var _tween: Tween

func _ready() -> void:
	_escala_normal = scale
	modulate.a = opacidad_normal   # NUEVO: aplica la transparencia inicial al arrancar

func _process(_delta: float) -> void:
	if is_pressed() and modulate.a > opacidad_presionado + 0.01:
		_animar_pulsado()
	elif not is_pressed() and modulate.a < opacidad_normal - 0.01:
		_animar_soltado()

func _animar_pulsado() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", opacidad_presionado, 0.08)
	_tween.tween_property(self, "scale", _escala_normal * factor_escala_presionado, 0.08).set_trans(Tween.TRANS_SINE)

func _animar_soltado() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", opacidad_normal, 0.12)
	_tween.tween_property(self, "scale", _escala_normal, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
