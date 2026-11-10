# Encargo para Claude Fable 5.2: cartas y reliquias, y nuevo ritmo

Trabajas solo en «La Última Puerta» (Godot 4.7.2, GDScript), en la rama `prototype/first-siege`. El usuario habla español: commits, textos del juego y documentación en español. Decide con criterio propio y deja escrito por qué en ROADMAP.md; no hace falta preguntar.

## Lo que ha dicho el usuario después de jugar
- «Empieza a estar bien».
- Los enemigos se le echan encima muy pronto, y todo se ve un poco grande.
- Quiere las opciones del árbol (ramas, nodos) **solo al final de la partida**, no entre oleadas.
- Quiere **quitar las compras dentro de la partida**. En su lugar, elegir **cartas** tras cada oleada, al estilo Slay the Spire, con **reliquias**.
- Quiere **al menos 100 reliquias**, para que cada partida sea distinta y apetezca volver.
- La música procedural no le gusta. La va a hacer con Suno; tú solo preparas el juego para reproducir pistas.

## Lee primero
`CLAUDE.md`, `ROADMAP.md` (secciones «Árbol 2», «Rejugabilidad» y «Noche 2»), `data/balance.json` (`economy`, `draft`, `augurs`, `contracts`), `data/waves.json`, y en `scripts/sim.gd` la economía (`buy`, `can_buy`, `level_up`, `level_cost`, `souls`), el draft (`make_draft`, `_draft_ok`, `draft_pick`, `boons`, `_fx_totals`, `active_sets`), las reliquias de ruta (`give_relic`, `relic`) y el árbol (`can_skill`). En `scripts/main.gd`, los botones del panel inferior (`_buttons`, `_do_button`) y `_draw_draft`.

## 1. Ritmo y tamaño (primero, es lo más rápido)
- Más aire antes del choque: que los humanos tarden más en llegar a tus bestias. Valora mover `arena.spawn_x` (hoy 1240) o la zona de vanguardia (`zones`), retrasar el primer grupo de cada oleada (`delay`), separar más los grupos y bajar un poco la velocidad de los comunes. Mide el tiempo hasta el primer contacto antes y después con `tools/debug_run.tscn`: que haya unos segundos para mirar y lanzar la primera Brasa.
- Todo un poco más pequeño en la arena: una escala global de unidades en la vista (por ejemplo 0,8; mejor una constante en `main.gd`/`art.gd` que tocar cada `SPRITE_H`), con sombras, barras de vida, etiquetas y efectos ajustados. Las colisiones y alcances de `sim.gd` no cambian. Comprueba con capturas que nada se corta, que las etiquetas no se pisan y que las unidades siguen legibles.

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

### Bestias que se desbloquean en el árbol
- Al empezar solo están Tizón (Sabueso de Escoria) y, como mucho, otra bestia básica. **Las demás no salen en las cartas hasta que se desbloquean en el árbol de habilidades**: Ojo de Latón, Alacrán, Sapo, Manta, Gárgola, Enjambre, Garfio (y las que vengan).
- Cada desbloqueo es un nodo del árbol (por ejemplo, un nodo «Pacto con el Alacrán» en la rama Bestias o Jauría), con coste de esencia y requisitos razonables, de modo que el jugador elija qué bestias quiere añadir a su repertorio. Las del pack 2 pueden seguir colgando de las ramas que ya se ganan con los asedios.
- Las cartas de bestia solo ofrecen las desbloqueadas; las cartas de mejora, solo las de bestias que tienes. Muestra en el árbol qué bestia abre cada nodo (con su sprite) y en el bestiario cuáles faltan por abrir.
- Cuida la primera partida: con pocas bestias el bot torpe debe seguir entre el 40 y el 60%. Si baja, compénsalo con cartas de hechizo y de Puerta, no regalando bestias.
- Migra a quien ya tenga esencia gastada: las bestias que ya ha visto pueden quedar abiertas, o se le devuelve esencia; decide y explícalo.

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
- No se compra nada durante la partida; tras cada oleada se eligen cartas; las bestias nuevas se abren en el árbol y no están desde el principio; hay 100 reliquias o más funcionando y visibles; el árbol solo se toca al final.
- Los enemigos tardan más en llegar y todo se ve algo más pequeño, sin solapes.
- El juego reproduce las pistas de Suno si están, y la música de ahora si no.
- Medidas con el bot dentro de las cifras, suite en verde, documentación y web al día.
