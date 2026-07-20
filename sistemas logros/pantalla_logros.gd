extends Control

const ITEM_LOGRO = preload("res://sistemas logros/ItemLogro.tscn")
const RUTA_MENU_PRINCIPAL = "res://escenas/menuprincipal/menu_principal.tscn"

@onready var contenedor = $ScrollContainer/VBoxContainer
@onready var boton_volver = $BotonVolver

func _ready():
	boton_volver.pressed.connect(_on_volver_pressed)
	_llenar_lista()
	ResourceLoader.load_threaded_request(RUTA_MENU_PRINCIPAL)
func _llenar_lista():
	for hijo in contenedor.get_children():
		hijo.queue_free()
	
	for id in ControladorLogros.logros.keys():
		var datos = ControladorLogros.logros[id]
		var item = ITEM_LOGRO.instantiate()
		contenedor.add_child(item)
		item.get_node("LabelNombre").text = datos["nombre"]
		item.get_node("LabelDescripcion").text = datos["descripcion"]
		item.get_node("LabelRecompensa").text = "+%d Cristales" % datos["recompensa"]
		
		var desbloqueado = ControladorLogros.esta_desbloqueado(id)
		item.get_node("IconoEstado").texture = (
			preload("res://texturas botones/check.png") if desbloqueado 
			else preload("res://texturas botones/icon candado.png")
		)
		item.modulate = Color(1,1,1,1) if desbloqueado else Color(0.6,0.6,0.6,1)
	
	# Espaciador final para evitar que el último ítem quede cortado
	var espaciador = Control.new()
	espaciador.custom_minimum_size = Vector2(0, 150)
	contenedor.add_child(espaciador)
func _on_volver_pressed():
	var estado = ResourceLoader.load_threaded_get_status(RUTA_MENU_PRINCIPAL)
	if estado == ResourceLoader.THREAD_LOAD_LOADED:
		var escena = ResourceLoader.load_threaded_get(RUTA_MENU_PRINCIPAL)
		get_tree().change_scene_to_packed(escena)
	else:
		ControladorCarga.ir_a_escena(RUTA_MENU_PRINCIPAL)
