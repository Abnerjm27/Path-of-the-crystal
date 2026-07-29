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
- 🤝 **Modo cooperativo local** (2 jugadores, misma pantalla) con cámara dinámica y progreso independiente del modo un jugador

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

## 🤝 Modo Cooperativo

El juego incluye un modo cooperativo local de **2 jugadores en la misma pantalla**, activable desde el botón "Cooperativo" en la pantalla de selección de personaje.

### Cómo se asignan los controles

| Situación | Jugador 1 | Jugador 2 |
|---|---|---|
| PC, sin mandos conectados | Teclado (flechas/espacio/D) | Teclado (w A S D) |
| PC, 1 mando conectado | Teclado | Mando |
| PC, 2 mandos conectados | Mando #1 | Mando #2 |
| Móvil | Mando obligatorio | Mando obligatorio |

En móvil, el cooperativo **exige 2 mandos conectados** (Bluetooth o USB) — no se puede activar sin ellos, ya que la pantalla táctil no se puede repartir entre 2 personas. Los controles táctiles en pantalla se ocultan automáticamente mientras el cooperativo está activo (o si el Jugador 1 juega con mando en modo un jugador).

### Reglas del modo cooperativo

- Cada jugador elige su propio personaje por separado en la pantalla de selección.
- Si cualquiera de los dos muere, el nivel se reinicia para ambos.
- Los cristales recogidos van a un total compartido, sin importar quién los recoja.
- El nivel se completa en cuanto se junten todos los cristales entre los dos.
- El jefe final persigue siempre al jugador que esté más cerca en ese momento.
- La cámara sigue el punto medio entre los dos jugadores, alejando el zoom dinámicamente si se separan.
- **El progreso de niveles desbloqueados es independiente del modo un jugador** — el cooperativo siempre empieza desde el nivel 1 y avanza por su cuenta, sin mezclarse con lo avanzado en solitario.

---

## 🎯 Controles

| Acción | PC — Jugador 1 | PC — Jugador 2 (cooperativo) | Móvil |
|---|---|---|---|
| Mover | Flechas (izquierda/derecha) | W / D / A/ S| Controles táctiles en pantalla |
| Saltar | Barra espaciadora / Flecha arriba | I | Botón en pantalla |
| Dash | Tecla D | K | Botón en pantalla |
| Pausa | Tecla Esc| — | Botón en pantalla |

En móvil (y en PC si hay mandos conectados), los controles se toman directamente del mando — ver la sección de **Modo Cooperativo** para el detalle de cómo se asignan.

---

## 📜 Licencia

Este proyecto incluye tanto una licencia **MIT** como una **GPL-3.0** (ver [`LICENCE`](./LICENCE) y [`LICENSE`](./LICENSE)). Revisa ambos archivos para conocer los términos aplicables a cada parte del proyecto (por ejemplo, addons de terceros como *Virtual Joystick DX* pueden tener su propia licencia).

---

## 👤 Autor

* Desarrollado por [**Abnerjm27**](https://github.com/Abnerjm27):Desarrollador Principal.
* **Miguel Colmenares**: 
  * Promotor de la idea inicial del proyecto.
  * Co-desarrollador.
  * Apoyo y selección en la banda sonora / música del juego.
  * Apoyo moral y psicológico durante el desarrollo.
---

## 🙌 Créditos

- Herramienta de diseño de niveles: **Tiled Map Editor**
- Assets gráficos y de sonido: [**CraftPix**](https://craftpix.net/), [**itch.io**](https://itch.io/) y [**Pinterest**](https://www.pinterest.com/) (referencias e imágenes para fondos)
- Generación de imágenes: **Gemini** (Google AI)
- Apoyo en programación y depuración de código: **Claude** (Anthropic)
- Testing y reporte de bugs: *Daniel Cetina*
