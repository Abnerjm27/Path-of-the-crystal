class_name InterpoladorRed
extends RefCounted

const MUESTRAS_MAXIMAS := 24
const MS_PARA_CONSIDERAR_QUIETO := 350.0

var _muestras: Array[Dictionary] = []
var _ultimo := {"pos": Vector2.ZERO, "anim": "idle", "flip": false}


func vacio() -> bool:
	return _muestras.is_empty()


func agregar(t_red: float, pos: Vector2, animacion: String, flip: bool) -> void:
	if not _muestras.is_empty() and t_red <= _muestras[-1]["t"]:
		return # paquete viejo o duplicado: fuera
	_muestras.append({"t": t_red, "pos": pos, "anim": animacion, "flip": flip})
	while _muestras.size() > MUESTRAS_MAXIMAS:
		_muestras.pop_front()


func muestrear() -> Dictionary:
	if _muestras.is_empty():
		return _ultimo

	var objetivo: float = NetworkDiscovery.tiempo_red_ms() - NetworkDiscovery.retardo_interpolacion_ms()

	while _muestras.size() >= 3 and _muestras[1]["t"] <= objetivo:
		_muestras.pop_front()

	var a: Dictionary = _muestras[0]
	if _muestras.size() == 1 or objetivo <= a["t"]:
		return _guardar(a["pos"], a["anim"], a["flip"])

	var b: Dictionary = _muestras[1]
	if objetivo >= b["t"]:
		var anim: String = b["anim"]
		if objetivo - b["t"] > MS_PARA_CONSIDERAR_QUIETO and anim == "correr":
			anim = "idle"
		return _guardar(b["pos"], anim, b["flip"])

	var span: float = b["t"] - a["t"]
	var f: float = 0.0 if span <= 0.0 else clampf((objetivo - a["t"]) / span, 0.0, 1.0)
	return _guardar((a["pos"] as Vector2).lerp(b["pos"] as Vector2, f), b["anim"], b["flip"])


func _guardar(pos: Vector2, anim: String, flip: bool) -> Dictionary:
	_ultimo = {"pos": pos, "anim": anim, "flip": flip}
	return _ultimo
