class_name RedPersonaje
extends RefCounted

## Sincronización de posición SIN predicción ni reconciliación.
## El dueño simula y transmite su posición real; el otro peer solo
## interpola entre dos muestras que YA llegaron, con retardo ADAPTATIVO.
## Nunca se extrapola: si no hay datos nuevos, el muñeco se queda quieto.

const FRECUENCIA_ENVIO := 30.0            # paquetes por segundo (era 20)
const MUESTRAS_MAXIMAS := 30              # más buffer para 30 Hz
const MS_PARA_CONSIDERAR_QUIETO := 250.0  # sin datos -> forzar "idle" (era 350)
## Distancia mínima para enviar posición aunque no haya cambio visual
const UMBRAL_POSICION_PX := 0.5

var _personaje: CharacterBody2D
var _es_mio := false
var _es_red := false

var _acumulador_envio := 0.0
var _ultima_anim_enviada := ""
var _ultimo_flip_enviado := false
var _ultima_pos_enviada := Vector2.ZERO

var _muestras: Array[Dictionary] = []

var _ultima_pos := Vector2.ZERO
var _ultima_anim := "idle"
var _ultimo_flip := false


func inicializar(personaje: CharacterBody2D) -> void:
	_personaje = personaje
	_es_red = ControladorGlobal.es_partida_en_red
	# jugador_id 0 = host (mi_id_jugador_red 1), jugador_id 1 = cliente (2)
	_es_mio = true if not _es_red else (personaje.jugador_id == ControladorGlobal.mi_id_jugador_red - 1)
	_ultima_pos = personaje.global_position


func es_red() -> bool:
	return _es_red

func es_mio() -> bool:
	return _es_mio

func es_remoto() -> bool:
	return _es_red and not _es_mio


# ═════════════ DUEÑO: transmitir ═════════════
func transmitir(delta: float, animacion: String, flip_h: bool) -> void:
	if not _es_red or not _es_mio:
		return

	_acumulador_envio += delta
	var cambio_visual := animacion != _ultima_anim_enviada or flip_h != _ultimo_flip_enviado
	var pos_actual := _personaje.global_position
	var cambio_pos := pos_actual.distance_squared_to(_ultima_pos_enviada) > UMBRAL_POSICION_PX * UMBRAL_POSICION_PX
	if _acumulador_envio < 1.0 / FRECUENCIA_ENVIO and not cambio_visual and not cambio_pos:
		return

	_acumulador_envio = 0.0
	_ultima_anim_enviada = animacion
	_ultimo_flip_enviado = flip_h
	_ultima_pos_enviada = pos_actual

	NetworkDiscovery.enviar_posicion(pos_actual, animacion, flip_h)


# ═════════════ REMOTO: recibir ═════════════
func recibir_posicion(t_red: float, pos: Vector2, animacion: String, flip_h: bool) -> void:
	if not es_remoto():
		return

	# Paquete viejo o duplicado: fuera
	if not _muestras.is_empty() and t_red <= _muestras[-1]["t"]:
		return

	_muestras.append({"t": t_red, "pos": pos, "anim": animacion, "flip": flip_h})
	while _muestras.size() > MUESTRAS_MAXIMAS:
		_muestras.pop_front()


func calcular_posicion_render() -> Dictionary:
	if _muestras.is_empty():
		return _resultado(_ultima_pos, _ultima_anim, _ultimo_flip)

	# Usamos el retardo ADAPTATIVO del sistema de red (60-260 ms según el jitter real)
	# en vez del fijo de 200 ms. Esto reduce el lag visual en conexiones buenas.
	var objetivo: float = NetworkDiscovery.tiempo_red_ms() - NetworkDiscovery.retardo_interpolacion_ms()

	# Descartamos muestras viejas, dejando _muestras[0] como la última
	# anterior (o igual) al instante que queremos renderizar.
	while _muestras.size() >= 3 and _muestras[1]["t"] <= objetivo:
		_muestras.pop_front()

	var a: Dictionary = _muestras[0]

	# Aún no tenemos historia suficiente: nos plantamos en la primera muestra.
	if _muestras.size() == 1 or objetivo <= a["t"]:
		return _resultado(a["pos"], a["anim"], a["flip"])

	var b: Dictionary = _muestras[1]

	# El instante a renderizar ya pasó la última muestra: NO extrapolamos,
	# nos quedamos en la última posición conocida.
	if objetivo >= b["t"]:
		var anim: String = b["anim"]
		if objetivo - b["t"] > MS_PARA_CONSIDERAR_QUIETO and anim == "correr":
			anim = "idle"   # sin datos nuevos, mejor quieto que corriendo en el sitio
		return _resultado(b["pos"], anim, b["flip"])

	var span: float = b["t"] - a["t"]
	var f: float = 0.0 if span <= 0.0 else clampf((objetivo - a["t"]) / span, 0.0, 1.0)
	var pos: Vector2 = (a["pos"] as Vector2).lerp(b["pos"] as Vector2, f)
	return _resultado(pos, b["anim"], b["flip"])


func limpiar() -> void:
	_muestras.clear()


func _resultado(pos: Vector2, anim: String, flip: bool) -> Dictionary:
	_ultima_pos = pos
	_ultima_anim = anim
	_ultimo_flip = flip
	return {"pos": pos, "anim": anim, "flip": flip}
