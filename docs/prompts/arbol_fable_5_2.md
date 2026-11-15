# Encargo para Claude Fable 5.2: rediseñar el árbol de habilidades

Trabajas solo en «La Última Puerta» (Godot 4.7.2, GDScript), en la rama `prototype/first-siege`. El usuario habla español: commits, textos del juego y documentación en español. Decide con criterio propio y deja escrito por qué en ROADMAP.md; no hace falta preguntar.

## Lee primero
`CLAUDE.md`, `ROADMAP.md` (secciones «Noche 2» y «Rejugabilidad»), `data/skills.json`, y en `scripts/sim.gd` las funciones del árbol (`skill_cost`, `skill_state`, `can_skill`, `buy_skill`, `_fx_totals`, `fmul`/`fadd`, `_stats`) y las de los dones (`boon_families`, `active_sets`, `_draft_weight`). En `scripts/main.gd`, el dibujo del árbol (`_build_tree_pos`, `_node_rect`, `_draw_tree`, `_draw_skill_tip`).

## El problema
El árbol tiene 69 nodos en 8 ramas, y casi todos son «+X% de algo» (efectos `fx` con `mul`/`add`). Sube los números, pero no cambia cómo se juega: dos jugadores con la misma esencia acaban con árboles casi iguales, y comprar un rango rara vez es una decisión interesante. El resto del juego ya tiene variedad (augurios, dones, resonancias, encargos, terreno, tres asedios y La Grieta). El árbol es la pieza que se ha quedado atrás.

## Objetivo
Que el árbol sea una fuente de builds y de decisiones, no solo de porcentajes, sin romper la curva de dificultad. Estas son las cinco ideas del usuario. Puedes ajustarlas o mejorarlas si encuentras algo mejor, explicándolo:

1. **Piedras angulares.** Pocos nodos caros (uno o dos por rama) que cambian una regla, con su contrapartida. Ejemplos del usuario: «la Brasa deja el suelo ardiendo pero tarda el doble», «el Rayo rebota sin fin pero solo contra quemados», «Tizón no cae nunca, pero las demás bestias tienen la mitad de vida». Necesitarán código en `sim.gd`, no solo datos: hazlo con banderas o claves `special.*` que la simulación lea, como las que ya existen.
2. **Caminos excluyentes.** Al final de cada rama se elige entre dos nodos, y comprar uno bloquea el otro. El estado nuevo tiene que verse en el árbol (bloqueado por elección, no por falta de esencia).
3. **Que el árbol hable con los dones.** Nodos que potencian una resonancia (Infierno, Tempestad, Jauría, Avaricia, Bastión), que la activan con un solo don de la familia o que hacen salir más dones de una familia en el draft.
4. **Reasignar puntos con coste.** Recuperar la esencia gastada pagando una parte (por ejemplo, devolver el 70-80%), entre partidas o desde el menú. Ojo con la inflación de costes (`meta.inflation`): lo devuelto debe cuadrar con lo pagado. Guárdalo en `user://meta.json` como el resto.
5. **Ramas que se ganan.** Una rama para las bestias del pack 2 (Gárgola, Enjambre, Garfio) que se abre al ganar el segundo asedio (el Alba), y otra de la Inquisición al ganar el tercero. Antes de abrirse deben verse bloqueadas, con el requisito escrito. Así el árbol también crece con el progreso, no solo con la esencia.

## Restricciones
- `sim.gd` no dibuja ni sabe nada de la vista. Lo nuevo se apoya en datos (`data/skills.json`, `data/balance.json`) siempre que se pueda.
- Las pruebas son deterministas: las banderas de variedad están apagadas en `tests/suite.gd`. No las enciendas ahí sin fijar la semilla.
- **La interfaz del árbol ya está llena** (8 columnas en 1280×720). Con dos ramas más hay que rediseñar la vista (pestañas, desplazamiento, ramas plegables o lo que funcione mejor) y comprobarla con capturas. Nada se puede solapar ni salirse de su caja.
- El árbol del jugador ya existe en `user://meta.json`. Si cambias o quitas ids, migra los rangos guardados: devuelve la esencia de lo que desaparezca y no rompas una partida a medias (`user://partida.txt`).
- No añadas el addon godot_ai ni sus ajustes en `project.godot`.

## Equilibrio
Mide antes y después con el bot torpe, `tools/balance.tscn`:
- Primera partida: debe quedar entre el 40 y el 60% (hoy está en torno al 50%).
- Carrera: `BAL_CLIMB=1 godot --headless --path . res://tools/balance.tscn -- 0 8 20` recorre los tres asedios subiendo Ira. Hoy da ~58% de media sin muro. Debe seguir así: ni victorias del 100% durante muchas partidas seguidas, ni caídas al 0%.
- El bot compra con `buy_meta` en `tests/bot.gd`. Enséñale a elegir piedras angulares y caminos excluyentes de forma razonable, o las medidas no dirán nada. Puedes dar al bot dos estilos distintos y comparar.
- Comprueba también que dos carreras con estilos de compra distintos acaban con árboles distintos y con tasas parecidas. Ese es el objetivo de verdad.

## Entorno (sesión en la nube nueva)
Si `godot` no está en el PATH, móntalo:
```bash
mkdir -p /opt/godot && cd /opt/godot && curl -sSL -o g.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip && unzip -o -q g.zip && ln -sf /opt/godot/Godot_v4.7.2-stable_linux.x86_64 /usr/local/bin/godot
```
```bash
apt-get install -y xvfb
```
Después, desde la raíz del repo: `godot --headless --editor --import --path .` (una vez) y `godot --headless --path . res://tests/run_scene.tscn`, que debe terminar en `FIN_SUITE fallos=0` sin ninguna línea `SCRIPT ERROR` (un error de script corta una prueba sin contar como fallo: búscalo siempre). Capturas con `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . res://tools/shots.tscn -- <carpeta> arbol`. Revisa las capturas tú mismo.

Para publicar la versión web hacen falta las plantillas `web_nothreads_*` de 4.7.2 (ver la nota de entorno en ROADMAP.md). Si no consigues montarlas, deja la web para el final y dilo.

## Forma de trabajar
- Commits pequeños en español y push a `prototype/first-siege`, siempre con la suite en verde. Pruebas nuevas para cada mecánica: piedras angulares, exclusión, reasignación (la esencia cuadra), ramas que se ganan y migración de datos viejos.
- Añade a ROADMAP.md una sección «Árbol 2» con el plan, ve marcándolo y apunta las medidas de antes y después.
- Mantén al día CLAUDE.md (arquitectura del árbol), README.md (qué hay) y el texto de «Cómo se juega» del menú.
- Al final: republica la web con `tools/publish_web.sh`, actualiza la descripción del PR #1 y deja en ROADMAP.md un resumen y lo que harías después.

## Cuándo está terminado
- Hay piedras angulares, caminos excluyentes, nodos ligados a los dones, reasignación con coste y las dos ramas que se ganan, todo funcionando en el juego y visible en el árbol sin solapes.
- Las medidas con el bot cumplen las cifras de arriba y están escritas en ROADMAP.md.
- La suite está en verde, y la documentación y la web están al día.
