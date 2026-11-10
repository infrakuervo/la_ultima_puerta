# Encargo para Claude Fable 5.2: cartas y reliquias, y nuevo ritmo

Trabajas solo en «La Última Puerta» (Godot 4.7.2, GDScript), en la rama `prototype/first-siege`. El usuario habla español: commits, textos del juego y documentación en español. Decide con criterio propio y deja escrito por qué en ROADMAP.md; no hace falta preguntar.

## Lo que ha dicho el usuario después de jugar
- «Empieza a estar bien».
- Los enemigos se le echan encima muy pronto. Prefiere que vayan más lentos y con más vida; el tamaño está bien.
- Quiere las opciones del árbol (ramas, nodos) **solo al final de la partida**, no entre oleadas.
- Quiere **quitar las compras dentro de la partida**. En su lugar, elegir **cartas** tras cada oleada, al estilo Slay the Spire, con **reliquias**.
- Quiere **al menos 100 reliquias**, para que cada partida sea distinta y apetezca volver.
- La música procedural no le gusta. La va a hacer con Suno; tú solo preparas el juego para reproducir pistas.

## Lee primero
`CLAUDE.md`, `ROADMAP.md` (secciones «Árbol 2», «Rejugabilidad» y «Noche 2»), `data/balance.json` (`economy`, `draft`, `augurs`, `contracts`), `data/waves.json`, y en `scripts/sim.gd` la economía (`buy`, `can_buy`, `level_up`, `level_cost`, `souls`), el draft (`make_draft`, `_draft_ok`, `draft_pick`, `boons`, `_fx_totals`, `active_sets`), las reliquias de ruta (`give_relic`, `relic`) y el árbol (`can_skill`). En `scripts/main.gd`, los botones del panel inferior (`_buttons`, `_do_button`) y `_draw_draft`.

## 1. Ritmo (primero, es lo más rápido)
- El usuario quiere que los humanos **vayan más lentos y tengan más vida**, para que no se le echen encima tan pronto sin que la partida se vuelva fácil. **El tamaño de las unidades está bien: no lo cambies.**
- Empieza por ahí (velocidad más baja y vida más alta en `balance.json` → `enemies`, sobre todo los comunes) y mide el tiempo hasta el primer contacto con `tools/debug_run.tscn`: que haya unos segundos para mirar y lanzar la primera Brasa.
- El resto de estadísticas (daño, recompensas, élites, oleadas) revísalas tú con el bot y cambia lo que haga falta para que la curva cuadre con el sistema nuevo de cartas. Apunta en ROADMAP.md qué cambiaste y por qué.

## 2. Fuera la tienda: cartas tras cada oleada
- Desaparecen de la partida las almas como moneda y los botones de comprar Sabueso/Ojo y Subir nivel. Las almas pueden quedar como puntuación o desaparecer; decide y explícalo.
- Tras cada oleada eliges **1 de 3 cartas** (y a veces puedes saltar a cambio de algo pequeño). Tipos de carta, como mínimo:
  - **Bestia:** se une a la manada (las que hoy están en el draft, más Sabueso y Ojo).
  - **Mejora de bestia:** sube de nivel a una bestia concreta, o a todas las de un tipo.
  - **Hechizo:** mejora Brasa o Rayo (radio, cadena, recarga, efectos nuevos).
  - **Don:** los que ya existen (con sus resonancias por familia).
  - **Curación de la Puerta** y otras utilidades.
- Rareza (común, rara, épica) con probabilidades que suben en oleadas avanzadas y con la Ira, como ya hace el draft.
- Las cartas de nivel dejan el nivel máximo como está y respetan `eco.max_level` del árbol.

### Empezar solo con el demonio y abrir las bestias en el árbol
- **La primera partida es solo del demonio:** Brasa, Rayo y cartas del demonio y de la Puerta, sin ninguna bestia, ni siquiera Tizón. Tiene que poder perderse y dejar esencia, pero no ser un muro; ajusta esa primera partida aparte para que el bot torpe aguante varias oleadas y gane esencia suficiente para el primer desbloqueo.
- **Tizón (el Sabueso) es el primer desbloqueo:** con la esencia de una partida aprox. se compra en el árbol, y desde entonces aparece en cada partida con su nombre y su historia (cicatrices, mutación de ruta). Después se abren las demás bestias (Ojo de Latón, Alacrán, Sapo, Manta, Gárgola, Enjambre, Garfio y las que vengan), cada una con su nodo. Hasta abrirlas no salen en las cartas.
- **El árbol pasa a ser una red al estilo Path of Exile:** un tablero grande de nodos conectados que parte del demonio en el centro, con caminos hacia regiones (fuego/Brasa, rayo, Puerta, cada bestia, dones y resonancias). Se compra un nodo solo si toca a uno ya comprado. Mezcla nodos pequeños (+%), nodos notables (más fuertes, en los cruces) y las piedras angulares que ya existen, y pon en la red los nodos de desbloqueo de bestias, de modo que abrir el Horno o el Alacrán implique ir hacia su región. Así dos jugadores hacen recorridos distintos.
  - La vista necesita un tablero que se pueda arrastrar y acercar (rueda), con el camino resaltado, el detalle del nodo al pasar el ratón y lo comprado bien visible. Comprueba con capturas que no hay solapes ni texto cortado.
  - Reaprovecha los nodos y efectos del Árbol 2 (piedras angulares, caminos excluyentes, nodos de dones, ramas que se ganan con los asedios, reasignar con coste) dentro de la red; migra los rangos guardados con `load_tree` como hasta ahora.
- Las cartas de bestia solo ofrecen las desbloqueadas; las de mejora, solo las de bestias que tienes. En el bestiario, las que faltan por abrir.
- Equilibrio por etapas, no solo la primera partida: mide la carrera completa (`BAL_CLIMB=1`) desde cero, con el bot comprando por la red. Que desbloquear bestias se note, pero que ninguna tramo sea un muro ni dé el 100% durante muchas partidas.
- Migra a quien ya tenga esencia gastada: lo que ya tenía queda abierto en la red o se le devuelve la esencia; decide y explícalo.

### Referencia: el sistema de cartas de Monster Train 2
Al usuario le gusta cómo funcionan las cartas en Monster Train 2. Estúdialo (lo que sepas del juego y del primero) y adáptalo a un juego en tiempo real como este; no lo copies. Ideas que encajan:
- **Un mazo que crece durante la partida.** Las cartas que eliges tras cada oleada entran en tu mazo, en vez de aplicarse al momento. En combate tienes una mano de cartas y una energía que se recarga con el tiempo (el equivalente al ascua). Juegas una carta para invocar una bestia en un punto, lanzar un hechizo o mejorar algo. La Brasa y el Rayo pueden quedarse como poderes fijos del demonio o pasar a ser cartas: decide qué se juega mejor.
- **Mejorar cartas**, no solo conseguir nuevas: piedras o forjas entre oleadas que suben una carta (más daño, menos coste, un efecto extra).
- **Dos clanes por partida**: al empezar eliges dos familias de cartas (por ejemplo Fuego y Manada), y el draft sale de ellas. Encaja con las familias de dones y las resonancias que ya existen.
- **El demonio como campeón**, con mejoras propias que eliges a lo largo de la partida (equivalente a la mejora del campeón).
- **Paradas entre oleadas** en las que eliges qué hacer: mercader de cartas, forja de mejoras, reliquia, curar la Puerta… Así una partida tiene decisiones de camino, no solo de cartas.
- Las reliquias de la sección siguiente son el equivalente de sus artefactos.
Si el mazo en combate en tiempo real no funciona bien con el bot o con el ritmo, quédate con la elección de cartas entre oleadas (el apartado 2), pero aprovecha las mejoras, los clanes y las paradas. Explica lo que elijas y por qué en ROADMAP.md.

## 3. Reliquias (100 o más)
- Una reliquia es un objeto pasivo para toda la partida, con icono, nombre, rareza y texto corto. Datos en un archivo nuevo, `data/reliquias.json`, con efectos por datos (`fx` como el árbol) y, para las que cambian reglas, una clave `special.*` que `sim.gd` lea, como las piedras angulares.
- Cómo se consiguen: al vencer élites y héroes (elegir 1 de 3), en oleadas de cofre, como premio de encargos y augurios, y la del heraldo de cada ruta (las dos que ya existen pasan a ser reliquias de este sistema).
- Mezcla de tipos, para que haya builds y no solo números:
  - simples (+vida de la Puerta, +daño de Brasa);
  - condicionales («la primera Brasa de cada oleada cae dos veces», «cada 10 bajas, un Rayo gratis al más fuerte»);
  - de bestia y de sinergia (potencian una familia o una resonancia, o cambian una bestia: «el Horno inhala también a los élites»);
  - malditas o de doble filo («+50% de daño, pero la Puerta empieza al 60%»);
  - de economía de cartas («+1 carta para elegir», «puedes repetir una elección por oleada»);
  - de jefe, más fuertes, solo tras héroes y jefes.
- Pon como mucho el 40% de simples. Escríbelas en tandas (por ejemplo 25 de cada vez), con pruebas para las que tocan reglas. Ninguna puede romper la simulación (comprueba con partidas del bot que ninguna da el 100% de victorias por sí sola).
- Vista: fila de iconos de reliquias en el HUD (nombre y texto al pasar el ratón), pantalla de elegir reliquia, y una sección de reliquias en el bestiario o en el menú (vistas, no vistas). Algunas reliquias se abren con logros, como los dones.

## 4. El árbol, solo al final de la partida
- `can_skill` ya no vale en preparación: el árbol se abre en la pantalla de victoria/derrota y desde el menú. Entre oleadas se puede mirar, pero no comprar.
- El tutorial, los consejos y «Cómo se juega» se actualizan para el nuevo flujo.

## 5. Música de Suno
- El usuario traerá pistas (MP3 u OGG) a `art/musica/`: menú, preparación, combate, combate de jefe, victoria, derrota. Haz un reproductor con fundido entre pistas según la fase y la intensidad (la que hoy calcula `_music_target`), con el bus `Musica` y su volumen en Opciones. Si falta una pista, se queda la música procedural de ahora. Que el sitio de cada pista esté apuntado en un LEEME.

## Equilibrio
- El objetivo sigue igual: primera partida del bot torpe entre el 40 y el 60%, y la carrera `BAL_CLIMB=1` sin muro, con medias parecidas entre estilos. Enseña al bot a elegir cartas y reliquias con criterio mediano (`tests/bot.gd`), o las medidas no dirán nada.
- Mide también que dos partidas seguidas se parecen poco (`tools/variedad.gd`): con 100 reliquias deberían repetirse muy pocas.

## Restricciones
- `sim.gd` no dibuja ni sabe nada de la vista. Las pruebas son deterministas: las banderas de variedad están apagadas en `tests/suite.gd`.
- La partida guardada entre oleadas (`user://partida.txt`) y `user://meta.json` cambian de forma: migra lo viejo o descártalo con aviso, sin errores.
- No añadas el addon godot_ai ni sus ajustes en `project.godot`.

## Forma de trabajar
- Commits pequeños en español y push a `prototype/first-siege` con la suite en verde y sin ninguna línea `SCRIPT ERROR`. Pruebas nuevas para cada sistema.
- Sección «Cartas y reliquias» en ROADMAP.md con el plan, marcada sobre la marcha, con las medidas de antes y después.
- Mantén al día CLAUDE.md, README.md y el menú «Cómo se juega». Revisa las capturas tú mismo (`tools/shots.tscn`).
- Al final: republica la web con `tools/publish_web.sh` y actualiza la descripción del PR #1.

## Cuándo está terminado
- No se compra nada durante la partida; tras cada oleada se eligen cartas; la primera partida es solo del demonio, Tizón y las demás bestias se abren en un árbol en red al estilo Path of Exile; hay 100 reliquias o más funcionando y visibles; el árbol solo se toca al final.
- Los enemigos van más lentos y con más vida, y tardan más en llegar; el tamaño sigue igual.
- El juego reproduce las pistas de Suno si están, y la música de ahora si no.
- Medidas con el bot dentro de las cifras, suite en verde, documentación y web al día.
