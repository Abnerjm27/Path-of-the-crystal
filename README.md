# Path of the Crystal

**Las profundidades esconden los Cristales Ancestrales.**

Como soldado de una unidad de élite, tu misión es recuperarlos mientras enfrentas peligrosas criaturas y superas desafiantes cavernas. Recolecta todos los cristales para avanzar, derrota a tus enemigos y demuestra que tienes lo necesario para completar la misión.

---

## 🎮 Sobre el juego

**Path of the Crystal** es un platformer 2D desarrollado en **Godot 4**, disponible tanto para **PC** como para **dispositivos móviles**. A lo largo de 20 niveles, el jugador debe recolectar cristales, esquivar y derrotar enemigos, y enfrentarse a un jefe final para completar la misión.

### Características principales

- 🗺️ **20 niveles** con escenarios y desafíos únicos
- 💎 Sistema de recolección de **cristales**
- 🧍 **Selección de personajes** con tienda para desbloquearlos usando cristales
- 🏃 Mecánica de **dash** con estela (*ghost trail*) distinta para cada personaje
- 👹 **Jefe final** con sistema de fases y knockback
- 🏆 Sistema de **logros** (`ControladorLogros`)
- 💾 **Guardado persistente** de progreso
- ⏳ Pantalla de carga con hilos (*threaded loading screen*)
- 🗺️ Minimapa en el nivel final mediante `SubViewport`
- 📱 Controles táctiles adaptados para móvil
- 🔒 Sistema de **desbloqueo progresivo de niveles**

---

## 🕹️ Plataformas

El juego está pensado para jugarse tanto en **PC** como en **móvil**:

- **PC:** control mediante teclado.
- **Móvil:** controles táctiles en pantalla.

---

## 🛠️ Tecnologías

- **Motor:** [Godot 4](https://godotengine.org/)
- **Lenguaje:** GDScript (100%)
- **Herramientas de nivel:** [Tiled](https://www.mapeditor.org/) (`TILED_files/`)

---

## 📂 Estructura del proyecto

```
Path-of-the-crystal/
├── Bee/                     # Recursos del enemigo "abeja"
├── enemigo/                 # Lógica y recursos de enemigos
├── jefe/                    # Jefe final (fases, knockback, IA)
├── personajes/              # Personajes jugables
├── moneda/                  # Sistema de monedas
├── contenedor monedas/      # Contenedores de monedas
├── contadormuertes/         # Contador de muertes
├── sistemas logros/         # Sistema de logros
├── pantalla de carga/       # Pantalla de carga con hilos
├── menuopciones/            # Menú de opciones
├── movil/                   # Recursos y controles para móvil
├── nivel*/, nivel N/        # Escenarios de cada nivel
├── nivel final/             # Nivel final con minimapa
├── nivel tutorial/          # Nivel tutorial
├── Escenarios_nivel/        # Escenas base de niveles
├── escenas/                 # Escenas generales del juego
├── plataformas/             # Plataformas y mecánicas de movimiento
├── fondos/ fondoprincipal/  # Fondos y parallax
├── animaciones/             # Animaciones de personajes/enemigos
├── musica/                  # Música y audio
├── PNG/ tiles_sets/         # Assets gráficos y tilesets
├── TILED_files/             # Archivos fuente de Tiled
├── texturas botones/        # Texturas de UI
├── resources/               # Recursos varios de Godot
├── scrips/                  # Scripts adicionales
├── project.godot            # Archivo de proyecto de Godot
└── export_presets.cfg       # Presets de exportación (PC/móvil)
```

---

## 🚀 Cómo ejecutar el proyecto

1. Instala [Godot 4](https://godotengine.org/download) (versión 4.3 o superior recomendada).
2. Clona este repositorio:
   ```bash
   git clone https://github.com/Abnerjm27/Path-of-the-crystal.git
   ```
3. Abre Godot y selecciona **Importar**, luego elige el archivo `project.godot` dentro de la carpeta del proyecto.
4. Presiona **Play (F5)** para ejecutar el juego.

### Exportar el juego

El proyecto ya incluye configuraciones de exportación (`export_presets.cfg`) para PC y móvil. Desde Godot, ve a **Proyecto → Exportar** y selecciona la plataforma deseada.

---

## 🎯 Controles

| Acción | PC | Móvil |
|---|---|---|
| Mover | Flechas (izquierda/derecha) | Controles táctiles en pantalla |
| Saltar | Barra espaciadora / Flecha arriba | Botón en pantalla |
| Dash | Tecla D | Botón en pantalla |
| Pausa | Tecla P | Botón en pantalla |

---

## 📜 Licencia

Este proyecto incluye tanto una licencia **MIT** como una **GPL-3.0** (ver [`LICENCE`](./LICENCE) y [`LICENSE`](./LICENSE)). Revisa ambos archivos para conocer los términos aplicables a cada parte del proyecto (por ejemplo, addons de terceros como *Virtual Joystick DX* pueden tener su propia licencia).

---

## 👤 Autor

Desarrollado por [**Abnerjm27**](https://github.com/Abnerjm27).

---

## 🙌 Créditos

- Herramienta de diseño de niveles: **Tiled Map Editor**
- Assets gráficos y de sonido: [**CraftPix**](https://craftpix.net/), [**itch.io**](https://itch.io/) y [**Pinterest**](https://www.pinterest.com/) (referencias e imágenes para fondos)
- Generación de imágenes: **Gemini** (Google AI)
- Apoyo en programación y depuración de código: **Claude** (Anthropic)
- Testing y reporte de bugs: *Daniel Cetina*
