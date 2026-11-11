# Encargo para Claude Fable 5.2: árbol al final con las almas, personajes y ritmo

Trabajas solo en «La Última Puerta» (Godot 4.7.2, GDScript), en la rama `prototype/first-siege`. El usuario habla español: commits, textos del juego y documentación en español. Decide con criterio propio y deja escrito por qué en ROADMAP.md; no hace falta preguntar.

El encargo es acotado. **La economía dentro de la partida no cambia**: las almas, comprar Sabueso y Ojo, subir de nivel, el draft tras cada oleada, los dones, los augurios y los encargos se quedan como están. Una versión anterior de este encargo (`cartas_reliquias_fable_5_2.md`) pedía cartas, 100 reliquias y un árbol en red: el usuario lo ha descartado, no lo hagas.

## Lee primero
`CLAUDE.md`, `ROADMAP.md` (secciones «Árbol 2» y «Rejugabilidad»), y en `scripts/sim.gd` `can_skill`, `buy_skill`, `skill_cost`, `currency`, `_gain_essence`, `_wave_cleared`, `run_save`/`run_load`; en `scripts/main.gd` `_load_meta`/`_save_meta`, `save_run`/`load_run`/`clear_run`, el botón del árbol en `_buttons` y el dibujo del árbol; en `scripts/menu.gd` el menú principal y la selección de asedio.

## 1. El árbol se sube al final de la partida, con las almas que te queden
- Lo que quiere el usuario: **cuando terminas una partida, ganes o te maten, usas las almas que tengas para subir el árbol.** Entre oleadas no se compra nada del árbol.
- Hoy el árbol se paga con **esencia** (que se gana por oleada y al ganar) y se puede comprar en preparación. Cámbialo así:
  - Al acabar la partida (victoria o derrota), las almas que te quedan **se convierten en esencia** (o el árbol pasa a pagarse directamente con ese saldo; elige lo más claro para el jugador y explícalo). La pantalla final lo muestra («Te quedan 85 almas → 85 de esencia para el árbol»), y desde ahí se abre el árbol para gastarlo.
  - Decide qué pasa con la esencia que hoy se gana por oleada y por victoria (`balance.json` → `meta`): se puede quitar, o mantener como un extra pequeño. Lo importante es que el jugador entienda que **guardar almas en vez de gastarlas en la partida es una decisión**: más bestias y niveles ahora, o más árbol después.
  - Lo ya ahorrado en `meta.json` (esencia) se conserva.
- `can_skill` deja de valer en preparación: el árbol solo se compra en la pantalla de victoria o derrota y desde el menú, entre partidas. Entre oleadas se puede abrir para mirar, sin comprar, con un aviso en el propio árbol («Las mejoras se compran al terminar la partida, con las almas que te queden»).
- Reasignar puntos (`respec`) sigue solo entre partidas: compruébalo.
- Ajusta el tutorial, los consejos de una sola vez, el texto del panel inferior en preparación y «Cómo se juega».
- Recalibra los costes del árbol y la inflación (`meta.inflation`) para la nueva moneda: que subir el árbol siga llevando muchas partidas, sin que la primera deje el árbol vacío.
- El bot (`tests/bot.gd`) tiene que tomar esta decisión: gastar almas en la partida o guardarlas. Dale una regla mediana (por ejemplo, guardar parte de las almas en las últimas oleadas), o las medidas no dirán nada.

## 2. Personajes con nombre
- Al jugar por primera vez (y desde el menú) se crea un **personaje**: tu demonio, con el nombre que escriba el jugador (con uno por defecto si lo deja vacío). Se pueden tener varios (por ejemplo hasta 3 ranuras) y se elige uno al empezar.
- Cada personaje guarda lo suyo: esencia o saldo del árbol, árbol (`habilidades` y `pagado`), asedios ganados e Ira, récords de La Grieta y del reto semanal, logros y estadísticas, historial, bestiario y la partida a medias (`user://partida.txt` de hoy). Las opciones (volumen, temblor, vídeo de inicio) son generales.
- Archivos por personaje, por ejemplo `user://personajes/<id>/meta.json`, `partida.txt` y `bestiario.json`, más un `user://personajes.json` con la lista y el último usado. Al abrir el juego, «Continuar» lleva al último personaje y a su partida a medias si la tiene.
- **Migración:** si existen los archivos de ahora (`user://meta.json`, `user://partida.txt`, `user://bestiario.json`), conviértelos en el primer personaje sin perder nada.
- Menú: pantalla de personajes con ranuras (nombre, saldo, asedios ganados, récord de la Grieta, última partida): crear, elegir y borrar con confirmación. El nombre se ve en la cabecera de la partida y en la pantalla final. Nada se solapa ni se sale (comprueba con `tools/shots.tscn` y añade una captura `personajes`).
- En la web también se guarda en `user://` (IndexedDB): comprueba en Chromium sin cabeza que crear un personaje, jugar una oleada y recargar la página lo conserva.

## 3. Ritmo: humanos más lentos y con más vida
- Los enemigos se le echan encima muy pronto. El usuario quiere que **vayan más lentos y tengan más vida**. **El tamaño de las unidades está bien: no lo cambies.**
- Baja la velocidad y sube la vida en `balance.json` → `enemies` (sobre todo los comunes) y mide el tiempo hasta el primer contacto con `tools/debug_run.tscn`: que haya unos segundos para mirar y lanzar la primera Brasa.
- Revisa con el bot el resto de números que dependan de esto (daño, oleadas, élites, La Grieta) y cambia lo que haga falta. Apunta en ROADMAP.md qué cambiaste y por qué.

## Equilibrio
- Mide antes y después con `tools/balance.tscn`: primera partida del bot torpe entre el 40 y el 60%, y la carrera `BAL_CLIMB=1` sin muro, con medias parecidas entre estilos de compra (`BAL_STYLE`).

## Restricciones
- `sim.gd` no dibuja ni sabe nada de la vista; los personajes y los archivos son de la vista (`main.gd`/`menu.gd`). Las pruebas son deterministas y no tocan `user://` (meta `sin_persistencia`).
- No añadas el addon godot_ai ni sus ajustes en `project.godot`.

## Forma de trabajar
- Commits pequeños en español y push a `prototype/first-siege`, con la suite en verde y sin ninguna línea `SCRIPT ERROR`. Pruebas nuevas: no se compra en preparación y sí al final; las almas que sobran pasan al árbol; crear, elegir y borrar personajes; cada personaje guarda lo suyo; migración de los archivos viejos.
- Sección «Árbol al final y personajes» en ROADMAP.md con el plan y las medidas.
- Mantén al día CLAUDE.md, README.md y «Cómo se juega». Al final, republica la web con `tools/publish_web.sh` y actualiza la descripción del PR #1.

## Cuándo está terminado
- El árbol solo se compra al terminar una partida (o desde el menú), con las almas que te quedaron, y guardar almas es una decisión con sentido.
- Hay personajes con nombre, cada uno con su progreso y su partida a medias, y los datos de antes se han migrado al primero.
- Los humanos van más lentos y con más vida, el tamaño sigue igual, y las medidas del bot están dentro de las cifras.
- Suite en verde, documentación y web al día.
