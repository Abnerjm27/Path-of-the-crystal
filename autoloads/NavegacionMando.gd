extends Node
# ── Autoload: NavegacionMando ──
const ESCALA_ENFOCADO := Vector2(1.12, 1.12)
const BRILLO_ENFOCADO := Color(1.4, 1.4, 1.4)  # >1 en RGB = más brillante
const BRILLO_NORMAL := Color(1, 1, 1)
const DURACION_TWEEN := 0.15


func conectar_efecto_foco(controles: Array) -> void:
	for control in controles:
		if not control is Control:
			continue
		control.add_to_group("botones_mando")
		if not control.focus_entered.is_connected(_on_enfocado):
			control.focus_entered.connect(_on_enfocado.bind(control))
		if not control.focus_exited.is_connected(_on_desenfocado):
			control.focus_exited.connect(_on_desenfocado.bind(control))

func _on_enfocado(control: Control) -> void:
	var tween = control.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(control, "scale", ESCALA_ENFOCADO, DURACION_TWEEN)
	tween.tween_property(control, "self_modulate", BRILLO_ENFOCADO, DURACION_TWEEN)

func _on_desenfocado(control: Control) -> void:
	var tween = control.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(control, "scale", Vector2.ONE, DURACION_TWEEN)
	tween.tween_property(control, "self_modulate", BRILLO_NORMAL, DURACION_TWEEN)


func bloquear_controles(controles: Array, bloquear: bool) -> void:
	for control in controles:
		if not control is Control:
			continue
		control.focus_mode = Control.FOCUS_NONE if bloquear else Control.FOCUS_ALL
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE if bloquear else Control.MOUSE_FILTER_STOP


func enfocar_con_seguridad(control: Control) -> void:
	if control == null:
		return
	if control.focus_mode == Control.FOCUS_NONE:
		control.focus_mode = Control.FOCUS_ALL
		control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.grab_focus()
