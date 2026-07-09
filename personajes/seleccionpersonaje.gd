extends Control

@export var apariencias: Array[SpriteFrames]
@export var menu: PackedScene
@export var costos_personajes: Array[int] = [0, 50, 100, 150, 200]
@onready var preview = $AnimatedSprite2D
@onready var nombre = $Nombre
@onready var label_monedas = $LabelMonedas
@onready var label_mensaje = $LabelMensaje
@export var musica_de_esta_escena: AudioStream
const RUTA_SELECCION_PERSONAJE ="res://escenas/menuprincipal/menu_principal.tscn"
@onready var fondo_oscuro = $FondoOscuro
@onready var panel_confirmacion = $PanelConfirmacion
@onready var label_pregunta = $PanelConfirmacion/LabelPregunta
@onready var boton_confirmar = $PanelConfirmacion/BotonConfirmar
@onready var boton_cancelar = $PanelConfirmacion/BotonCancelar

var personaje := 0
var _indice_pendiente_compra := -1
var nombres_personajes := ["Asesino", "Salvaje", "Vikingo", "Valkyrie", "Vidente"]

@onready var botones_personaje = [
	$HBoxContainer/personaje1, $HBoxContainer/personaje2, $HBoxContainer/personaje3,
	$HBoxContainer/personaje4, $HBoxContainer/personaje5
]

func _ready():
	ResourceLoader.load_threaded_request(RUTA_SELECCION_PERSONAJE)
	ControladorMusica.reproducir(musica_de_esta_escena)
	label_mensaje.visible = false
	fondo_oscuro.visible = false
	panel_confirmacion.visible = false
	boton_confirmar.pressed.connect(_on_confirmar_compra)
	boton_cancelar.pressed.connect(_on_cancelar_compra)
	_actualizar_botones_bloqueo()
	_actualizar_label_monedas()
	seleccionar_personaje(0)

func _actualizar_label_monedas():
	label_monedas.text = "Monedas: %d" % ControladorGlobal.monedas_totales

func _actualizar_botones_bloqueo():
	for i in botones_personaje.size():
		var boton = botones_personaje[i]
		var desbloqueado = ControladorGlobal.personajes_desbloqueados[i]
		var icono_candado = boton.get_node("IconoCandado")
		var label_costo = boton.get_node("LabelCosto")
		
		boton.modulate = Color(1, 1, 1, 1) if desbloqueado else Color(0.5, 0.5, 0.5, 1)
		icono_candado.visible = not desbloqueado
		label_costo.visible = not desbloqueado
		if not desbloqueado:
			label_costo.text = str(costos_personajes[i])

func seleccionar_personaje(indice: int):
	personaje = indice
	preview.sprite_frames = apariencias[indice]
	preview.play("idle")
	nombre.text = nombres_personajes[indice]

func _mostrar_mensaje(texto: String):
	label_mensaje.text = texto
	label_mensaje.visible = true
	await get_tree().create_timer(2.0).timeout
	label_mensaje.visible = false

func _intentar_seleccionar_o_comprar(indice: int):
	if ControladorGlobal.personajes_desbloqueados[indice]:
		seleccionar_personaje(indice)
		return
	
	var costo = costos_personajes[indice]
	if ControladorGlobal.monedas_totales >= costo:
		_pedir_confirmacion(indice, costo)
	else:
		var faltan = costo - ControladorGlobal.monedas_totales
		_mostrar_mensaje("Necesitas %d monedas más" % faltan)

func _pedir_confirmacion(indice: int, costo: int):
	_indice_pendiente_compra = indice
	label_pregunta.text = "¿Comprar %s por %d monedas?" % [nombres_personajes[indice], costo]
	fondo_oscuro.visible = true
	panel_confirmacion.visible = true

func _on_confirmar_compra():
	fondo_oscuro.visible = false
	panel_confirmacion.visible = false
	if _indice_pendiente_compra == -1:
		return
	
	var indice = _indice_pendiente_compra
	var costo = costos_personajes[indice]
	var comprado = ControladorGlobal.comprar_personaje(indice, costo)
	if comprado:
		_actualizar_botones_bloqueo()
		_actualizar_label_monedas()
		seleccionar_personaje(indice)
		_mostrar_mensaje("¡%s desbloqueado!" % nombres_personajes[indice])
	
	_indice_pendiente_compra = -1

func _on_cancelar_compra():
	fondo_oscuro.visible = false
	panel_confirmacion.visible = false
	_indice_pendiente_compra = -1

func _on_personaje_1_pressed():
	_intentar_seleccionar_o_comprar(0)

func _on_personaje_2_pressed():
	_intentar_seleccionar_o_comprar(1)

func _on_personaje_3_pressed():
	_intentar_seleccionar_o_comprar(2)

func _on_personaje_4_pressed() -> void:
	_intentar_seleccionar_o_comprar(3)

func _on_personaje_5_pressed() -> void:
	_intentar_seleccionar_o_comprar(4)

func _on_comenzar_pressed():
	if not ControladorGlobal.personajes_desbloqueados[personaje]:
		return
	ControladorGlobal.personaje_seleccionado = personaje
	get_tree().change_scene_to_packed(menu)
