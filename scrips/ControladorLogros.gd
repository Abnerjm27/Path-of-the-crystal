extends Node

signal logro_desbloqueado(id: String, nombre: String, recompensa: int)

const RUTA_CONFIG = "user://configuracion.cfg"

var logros := {
	"primeros_pasos": {
		"nombre": "Primeros pasos",
		"descripcion": "Completa el nivel 1",
		"recompensa": 20,
		"condicion": func(): return ControladorGlobal.nivel >= 2
	},
	"veterano": {
		"nombre": "Veterano",
		"descripcion": "Alcanza el nivel 10",
		"recompensa": 50,
		"condicion": func(): return ControladorGlobal.nivel >= 10
	},
	"maestro": {
		"nombre": "Maestro",
		"descripcion": "Completa el juego",
		"recompensa": 100,
		"condicion": func(): return ControladorGlobal.nivel >= 20
	},
	"coleccionista": {
		"nombre": "Coleccionista",
		"descripcion": "Acumula 200 monedas en total",
		"recompensa": 30,
		"condicion": func(): return ControladorGlobal.monedas_totales >= 200
	},
	"casi_perfecto": {
		"nombre": "Casi perfecto",
		"descripcion": "Llega al nivel 10 con menos de 10 muertes",
		"recompensa": 40,
		"condicion": func(): return ControladorGlobal.nivel >= 10 and ControladorGlobal.muertes < 10
	},
	"coleccionista_heroes": {
		"nombre": "Coleccionista de héroes",
		"descripcion": "Desbloquea los 5 personajes",
		"recompensa": 50,
		"condicion": func(): return not ControladorGlobal.personajes_desbloqueados.has(false)
	},
	"sin_descanso": {
	"nombre": "Sin descanso",
	"descripcion": "Completa 5 niveles seguidos sin ir al menú",
	"recompensa": 40,
	"condicion": func(): return ControladorGlobal.racha_niveles >= 5
},
"fiel_a_mis_raices": {
	"nombre": "Fiel a mis raíces",
	"descripcion": "Completa el juego usando solo el personaje inicial",
	"recompensa": 60,
	"condicion": func(): return ControladorGlobal.nivel >= 21 and not ControladorGlobal.ha_usado_otro_personaje
},
"cuidadoso": {
	"nombre": "Cuidadoso",
	"descripcion": "Completa el juego con menos de 50 muertes",
	"recompensa": 50,
	"condicion": func(): return ControladorGlobal.nivel >= 21 and ControladorGlobal.muertes < 50
},
"no_hay_problema": {
	"nombre": "No hay problema",
	"descripcion": "Muere 50 veces en total",
	"recompensa": 20,
	"condicion": func(): return ControladorGlobal.muertes >= 50
},
"velocista_10": {
	"nombre": "Velocista I",
	"descripcion": "Llega al nivel 10 en menos de 10 minutos",
	"recompensa": 40,
	"condicion": func(): return ControladorGlobal.nivel >= 11 and ControladorGlobal.tiempo_total_juego <= 600.0
},
"velocista_15": {
	"nombre": "Velocista II",
	"descripcion": "Llega al nivel 15 en menos de 18 minutos",
	"recompensa": 50,
	"condicion": func(): return ControladorGlobal.nivel >= 16 and ControladorGlobal.tiempo_total_juego <= 1080.0
},
"velocista_final": {
	"nombre": "Velocista III",
	"descripcion": "Completa el juego en menos de 25 minutos",
	"recompensa": 80,
	"condicion": func(): return ControladorGlobal.nivel >= 19 and ControladorGlobal.tiempo_total_juego <= 1500.0
},

}

var desbloqueados: Array[String] = []

func _ready():
	cargar_logros()

func revisar_logros():
	for id in logros.keys():
		if id in desbloqueados:
			continue
		if logros[id]["condicion"].call():
			_desbloquear(id)

func _desbloquear(id: String):
	desbloqueados.append(id)
	var recompensa = logros[id]["recompensa"]
	ControladorGlobal.sumar_monedas(recompensa)
	logro_desbloqueado.emit(id, logros[id]["nombre"], recompensa)
	guardar_logros()

func esta_desbloqueado(id: String) -> bool:
	return id in desbloqueados

func guardar_logros():
	var config = ConfigFile.new()
	config.load(RUTA_CONFIG)
	config.set_value("logros", "desbloqueados", desbloqueados)
	config.save(RUTA_CONFIG)

func cargar_logros():
	var config = ConfigFile.new()
	var error = config.load(RUTA_CONFIG)
	if error == OK:
		var array_cargado = config.get_value("logros", "desbloqueados", [])
		desbloqueados.assign(array_cargado)
