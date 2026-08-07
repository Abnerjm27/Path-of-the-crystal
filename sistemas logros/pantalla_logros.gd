extends Control

const ITEM_LOGRO = preload("res://sistemas logros/ItemLogro.tscn")
const RUTA_MENU_PRINCIPAL = "res://escenas/menuprincipal/menu_principal.tscn"

@onready var contenedor = $ScrollContainer/VBoxContainer
@onready var boton_volver = $BotonVolver

func _ready():
	boton_volver.pressed.connect(_on_volver_pressed)
	_llenar_lista()
	_configurar_navegacion_mando()
	ResourceLoader.load_threaded_request(RUTA_MENU_PRINCIPAL)

func _llenar_lista():
	for hijo in contenedor.get_children():
		hijo.queue_free()
	
	for id in ControladorLogros.logros.keys():
		var datos = ControladorLogros.logros[id]
		var item = ITEM_LOGRO.instantiate()
		contenedor.add_child(item)
		
		# Asegurar que el item sea enfocable con mando
		item.focus_mode = Control.FOCUS_ALL
		
		item.get_node("LabelNombre").text = datos["nombre"]
		item.get_node("LabelDescripcion").text = datos["descripcion"]
		item.get_node("LabelRecompensa").text = "+%d Cristales" % datos["recompensa"]
		
		var desbloqueado = ControladorLogros.esta_desbloqueado(id)
		item.get_node("IconoEstado").texture = (
			preload("res://texturas botones/check_.png") if desbloqueado 
			else preload("res://texturas botones/icono_candado.png")
		)
		item.modulate = Color(1,1,1,1) if desbloqueado else Color(0.6,0.6,0.6,1)
	
	# Espaciador final para evitar que el último ítem quede cortado
	var espaciador = Control.new()
	espaciador.custom_minimum_size = Vector2(0, 150)
	contenedor.add_child(espaciador)

func _configurar_navegacion_mando():
	var elementos_enfocables = []
	
	# Agregar botón volver
	boton_volver.focus_mode = Control.FOCUS_ALL
	elementos_enfocables.append(boton_volver)
	
	# Agregar todos los ítems de la lista
	for hijo in contenedor.get_children():
		if hijo.focus_mode != Control.FOCUS_NONE:
			elementos_enfocables.append(hijo)
			
	# Conectar animaciones y efectos visuales de foco
	NavegacionMando.conectar_efecto_foco(elementos_enfocables)
	
	# Enfocar el primer elemento de la lista o el botón volver por defecto
	if contenedor.get_child_count() > 1:
		NavegacionMando.enfocar_con_seguridad(contenedor.get_child(0))
	else:
		NavegacionMando.enfocar_con_seguridad(boton_volver)

func _on_volver_pressed():
	var estado = ResourceLoader.load_threaded_get_status(RUTA_MENU_PRINCIPAL)
	if estado == ResourceLoader.THREAD_LOAD_LOADED:
		var escena = ResourceLoader.load_threaded_get(RUTA_MENU_PRINCIPAL)
		get_tree().change_scene_to_packed(escena)
	else:
		ControladorCarga.ir_a_escena(RUTA_MENU_PRINCIPAL)
