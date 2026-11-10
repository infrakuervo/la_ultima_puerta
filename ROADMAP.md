# ROADMAP — trabajo autónomo

Memoria entre turnos. Al empezar cada turno: leer esto y seguir por el primer punto pendiente.
Tarea programada «La Última Puerta: seguir» (trig_01MLzV3vNtp2KM7sJUp7qaTV, cada hora, minuto 16) creada.

## Noche 2 (animaciones de Flow)
Tarea programada «La Última Puerta: seguir 2» (trig_01RebsH5yBQGN7zjmY9vLLuV, cada hora, minuto 59) creada.
Entorno rehecho igual que en el paso 0 (Godot 4.7.2 en `/opt/godot`, xvfb).

1. [x] Sistema de animación por fotogramas — `scripts/anim.gd` + `data/anim.json` (personaje → clip: fps, bucle/hold, start, impacto, mano, alto y pies). Carga perezosa con caché; sin carpeta o sin fotograma → sprite fijo. Pruebas en `test_anim`.
2. [x] Demonio — reposo en bucle; `rayo` (24 fps desde el fotograma 5) y `brasa` (22 fps desde el 8) al lanzar; `golpe` si golpean la Puerta y no está lanzando; `victoria` y `derrota` (se queda en el último) en las pantallas finales, donde ahora sale el demonio grande a la izquierda. El rayo y la bola salen de la mano (`hand` en el JSON) en el fotograma de impacto: los efectos visuales del rayo esperan ~0,08 s; la bola vuela el resto del retraso de la Brasa. Escala y pies medidos con PIL frente al sprite fijo (`tools/shots.tscn` → `demonio`).
3. [x] Tizón / Sabuesos — `carrera` al moverse (velocidad suavizada leída de la simulación) y `mordisco` en `bite`/`presa`; sin reposo usa el sprite fijo con respiración por código. Al volver a casa se da la vuelta.
4. [x] Horno — `reposo`, `carrera` y `mordisco` (en `bite` y `horno_spit`); el mordisco tiene su propio `height`/`anchor` en el JSON por el encuadre más abierto.
5. [x] Animación por código — `scripts/poses.gd`: respiración en reposo, trote al moverse, embestida al atacar (bestias por evento; enemigos cuando su enfriamiento salta) y retroceso con el destello de golpe; preparación (Presa, apuntar) agacha un poco. La sombra se dibuja aparte, plana, y el cuerpo gira/escala desde los pies con `draw_set_transform(arena_offset + ...)`. Arreglado el reinicio a cero de la transformación en los charcos de brea. Capturas: `tools/shots.tscn` → `animacion`.
6. [x] Intro en vídeo — `VideoStreamPlayer` en un `CanvasLayer` al abrir el juego, antes del menú; clic o tecla la salta (fundido al menú); tope de 12 s por si no avisa al terminar. Opción «Vídeo de inicio» (`intro` en `user://opciones.json`). No sale en las pruebas ni sin pantalla. Captura: `tools/shots.tscn` → `intro`.
7. [x] Peso y web — antes `index.pck` 5,5 MB; con los fotogramas en PNG sin pérdida 39 MB (+34). Con WebP con pérdida (calidad 0,8, `tools/anim_lossy.sh`, llamado desde `tools/publish_web.sh`) queda en 14 MB (+8,5, de ellos 3 del vídeo) sin diferencia visible; no hizo falta bajar fps ni hacer hojas. `index.wasm` 39 MB (10 MB con gzip), igual que antes. Republicada y probada en Chromium sin cabeza: intro, se salta con Esc, menú con el demonio animado, combate con el clip de la Brasa.
8. [ ] Rejugabilidad (ampliación del encargo: ver sección «Rejugabilidad»), incluye curva del árbol, música procedural con volúmenes aparte y logros/estadísticas.
9. [ ] Cierre: PR #1, resumen y lista de animaciones que faltan para Flow. La tarea programada solo se desactiva si ya no queda margen.

## Animaciones que faltan (para pedir a Google Flow)
Mismo método que hoy: fondo verde liso (o negro para efectos), cámara fija, personaje de perfil mirando a la derecha y sin desplazarse, 4-8 s. Se recortan a PNG en `art/anim/<pj>/<clip>/` y se añaden a `data/anim.json`.
1. **Efectos sobre fondo negro** (se suman con mezcla aditiva, sin recorte): explosión de la Brasa al caer (vista un poco desde arriba, 1-1,5 s); impacto del Rayo (destello y chispas azules, 0,5 s); llamas de suelo en bucle (para los charcos de fuego del Horno y la Brasa); chispazo en la mano del demonio (bucle corto).
2. **Tizón en reposo** (bucle de respiración, mismo encuadre que `carrera`/`mordisco`): ahora usa el sprite fijo con respiración por código.
3. **Embestida del Horno en verde** (el clip magenta no se pudo recortar); también **inhalar** (abre las fauces y aspira 1-1,5 s), que encaja con su aviso INHALA.
4. **Otras bestias** (reposo y ataque de cada una): Trueno (agacharse y salto), Ojo de Latón (flotar y disparo), Alacrán (pinza), Sapo (escupitajo), Manta (planeo). Las del pack 2 (Gárgola, Enjambre, Garfio) aún son siluetas por código: primero un sprite fijo de cada una.
5. **Enemigos**: caminar y atacar del campesino y del escudero (son los más numerosos); el héroe Verdugo (hachazo) y el Inquisidor (campana).
6. **Jefe Gran Maestre**: caminar, Juicio (levanta el brazo y cae la luz sobre un carril) y derrota.
7. Opcional: el demonio **recibiendo Juicio** o **animando a la Puerta** entre oleadas.

## Rejugabilidad (ampliación de la noche 2)
El usuario quiere «un procedural divertido que dé horas de juego sin cansar aunque sea repetitivo».
Plan: tras los puntos 1-7, jugar partidas de verdad (bot torpe, capturas, `tools/debug_run.tscn`), apuntar aquí qué se repite y qué aburre, y luego valorar: oleadas generadas con presupuesto, modificadores por oleada, sinergias y builds, draft con rareza, retos semanales con semilla, desbloqueos meta de contenido, ritmo (x3, menos tiempos muertos). Medir con el bot antes y después.

### Diagnóstico (partidas del bot, `tools/balance.tscn`, `tools/debug_run.tscn`)
- **Todas las partidas son la misma partida.** Las 6 oleadas del primer asedio (y las 8 del segundo) tienen siempre la misma composición; solo se sortean los frentes. Lo único que cambia de una partida a otra es el draft y la ruta (2 opciones fijas, con su héroe fijo).
- **La curva se rompe enseguida.** Antes: con 180 de esencia (una partida) el bot torpe gana el 100% del primer asedio a Ira 0 y no vuelve a perder. Subiendo la Ira tras cada victoria (`BAL_CLIMB=1`), gana el 88-100% y agota todo el contenido (asedio 2, Ira 5) en ~12 partidas: la esencia crece más rápido que el reto.
- **Pocas decisiones por oleada.** Entre oleadas: colocar (casi siempre igual), subir nivel y el draft (1 de 3, con recompensas planas). En combate, Brasa y Rayo. No hay riesgo/recompensa que elegir.
- **Tiempos muertos.** La fase de preparación no tiene prisa ni nada nuevo que mirar; velocidad máxima x2.
- **No hay final abierto.** Ganado el segundo asedio en Ira 5 no queda nada que perseguir.

### Hecho
- [x] **Curva del árbol** — inflación (`balance.json` → `meta.inflation` = 0,02): cada rango comprado encarece un 2% los demás. Carrera subiendo Ira (`BAL_CLIMB=1`, 8×14 partidas): asedio 1 con 62-100% de victorias en cada Ira (antes 88-100%), Ira 3 del asedio 2 queda como techo para el bot torpe. A Ira 0 sigue siendo fácil tras la primera victoria (es el «modo tranquilo»).
- [x] **Oleadas remezcladas** (`waves.json` → `remix` por asedio, `Sim.remix_enabled`): cada partida copia las oleadas y cambia la composición con el mismo presupuesto (recompensa). El grupo principal de cada oleada conserva su tipo (es el tema y la nota); los demás comunes cambian con prob. 0,45 y las élites por otra élite con 0,6; cantidades ±20%. La oleada 1 no cambia (tutorial). Con semilla fija sale igual (para retos).
- [x] **Augurios** (`balance.json` → `augurs`, `Sim.augurs_enabled`): antes de cada oleada desde la 2 se ofrecen dos riesgo/recompensa (Luna de sangre, Marea, Fervor, Campeón, Niebla, Diezmo, Lluvia de ceniza); se elige uno o ninguno (Calma) con tarjetas bajo la previsión. El bot coge uno al azar el 60% de las veces.
  Medida (bot torpe, 80 primeras partidas): 58% sin variedad → 49% con remezcla y augurios al azar. Dentro del objetivo; un jugador que elige con cabeza lo tendrá algo mejor.
- [x] **Draft con rareza y dones** — el pool tiene `rarity` (común/rara/épica: marco, halo y peso) y un tipo nuevo `boon`: efectos para el resto de la partida con los mismos `fx` que el árbol (se suman en `_fx_totals`). Nueve dones que empujan a builds: fuego (Pacto de fuego, Eco de la Fosa), rayo (Tormenta, Rayo de gracia), bestias (Ley de la manada, Sangre de la Fosa, Colmillos de hierro), almas (Usura) y Puerta (Muralla de huesos). Las épicas desde la oleada 2. Iconos de los dones activos arriba a la izquierda (nombre al pasar el ratón). Bot torpe: 46% en la primera partida.
- [x] **La Grieta (sin fin)** — tercer «asedio» (`waves.json` → `grieta.endless`), se abre al ganar el primero. Empieza con las 6 oleadas del primer asedio remezcladas (ruta y héroe incluidos) y luego genera oleadas: presupuesto en recompensa ×1,08 por oleada, +7% de vida por oleada, un tema (grupo principal) y relleno al azar, élites que crecen hasta 6, heraldo cada 5 y Gran Maestre cada 15. No hay victoria: se guarda el récord de oleadas (`user://meta.json` → `records.grieta`) y la Ira se abre con él (1 por cada 8 oleadas). Tarjetas de asedio a tres columnas.
  Ajuste (bot torpe, 12 partidas por medida, oleadas superadas): con vida +7% lineal el bot con árbol llegaba al tope de 30 min (26-28 oleadas) sin morir. Ahora vida ×1,075 y daño ×1,04 compuestos por oleada, presupuesto ×1,06 con tope 560 (rendimiento) y jefe con vida propia (`boss_hp`, sin crecimiento): sin árbol 3-9; con 1000 de esencia 14-27; con 2500, 14-24. El Gran Maestre de la oleada 15 frena a ~40% (es el hito; `boss_hp` bajado a 0,45 después de medir).
  Tope de 70 comunes por oleada generada (`max_count`): el exceso se convierte en vida del grupo. Oleada 11: 45 enemigos; 21 y siguientes: ~76 (con élites), con vida ×3, ×6, ×12.
- [x] **Reto semanal** — botón en la selección de asedio: semilla fija durante la semana (`unix/604800`), asedio (alterna primero/segundo si está abierto), Ira 1 y un augurio que dura toda la partida (`Sim.week_augur`). Reiniciar repite las mismas oleadas. Récord propio (`records["reto:<semana>"]`, oleadas superadas).
- [x] **Ritmo** — velocidad x1 → x2 → x3 (botón, F y opción).
- [x] **Logros y estadísticas** — `data/logros.json` (14) + `scripts/logros.gd` (condiciones por evento). Aviso arriba al conseguir uno, lista en el menú (Logros) con estadísticas (partidas, victorias, oleadas, bajas, mejor Brasa, récord de la Grieta) y los conseguidos en la partida en la pantalla final. **Progresión que abre contenido:** 5 logros abren dones del draft (`unlock` en el pool): Rayo de gracia, Furia del Abismo, Eco de la Fosa, Sangre de la Fosa y Presagio (nuevos Furia y Presagio). Se guarda en `user://meta.json` → `logros_data`. Después: «Abismo» abre el augurio Eclipse y «Ira encendida» abre Pacto de sangre (augurios de alto riesgo con `unlock`).
- [x] **Música procedural** — `scripts/music.gd`: síntesis en tiempo real en un `AudioStreamGenerator` (drone frigio con progresión de 4 compases, campanas que improvisan, y en combate bajo, bombo y caja con tempo que sube). La intensidad sigue a la partida (menú/preparación en calma; combate según enemigos; héroes y jefes al máximo). Buses `Musica` y `Efectos` con volumen aparte en Opciones. ~20 ms de CPU por segundo de audio. No suena en las pruebas ni sin pantalla (hay prueba de la síntesis con `render()`).
- [x] **Sinergias (resonancias)** — con 2 dones de la misma familia se activa un efecto extra (`balance.json` → `draft.sets`): Infierno (fuego), Tempestad (rayo), Jauría (bestias), Avaricia (almas) y Bastión (Puerta, con el don nuevo Sello del Abismo). Los dones de una familia que ya llevas salen ×1,8 en el draft, así cada partida tira hacia una build. Aviso grande al activarse y lista bajo los iconos de dones.
- [x] **Encargos** (`balance.json` → `contracts`, `Sim.contracts_enabled`): en la preparación de la primera oleada se ofrecen dos objetivos opcionales para la partida (Puerta intacta, Solo fuego, Solo rayo, Tizón invicto, Austero, Manada viva, Agorero) que dan 60-90 de esencia al ganar si se cumplen. El estado (o «fallido») sale abajo durante el combate y el premio en la pantalla final. No hay encargos en La Grieta.
- [x] **Medida con todo activo** (remezcla, augurios, dones, resonancias, encargos; `tools/balance.tscn -- 80 8 14`, `BAL_CLIMB=1`): primera partida bot torpe 49%, bot hábil 92%. Carrera subiendo Ira: 62, 50, 62, 50, 75, 62, 75, 88, 50, 62, 50% en las partidas 1-11 (asedio 1 Ira 0-3 y asedio 2 Ira 0-2), y luego 25-0% en el asedio 2 con Ira 3+, que queda como techo del bot torpe. Antes de la noche: 62% y después 100% siempre.
- [x] **Terreno por partida** (`balance.json` → `terrains`, con la remezcla): Llanura de ceniza (nada), Fisura de lava (franja fija que quema a los humanos en un carril), Osario (humanos −15% de velocidad en un carril) y Viento del Abismo (Brasa cae antes, Rayo alcanza menos). Dibujados en la arena (grieta con lava y ascuas, huesos y calaveras, ráfagas) y con etiqueta abajo a la izquierda (descripción al pasar el ratón). Es la parte de «mapas que cambian».
- [x] **Guardar a mitad de partida** — entre oleadas la partida se guarda sola en `user://partida.txt` (`var_to_str`, conserva tipos): al entrar en preparación y tras cada compra, colocación, draft o augurio. Al abrir el juego, «Continuar» la recupera (oleadas remezcladas, terreno, dones, encargo, reto y estado del generador al azar incluidos). Se borra al ganar, perder o empezar otra. Probado con una vista real que juega una oleada, se destruye y otra la recupera.
- [x] **Consejos de una sola vez** — la primera vez que aparece un encargo, un augurio, un don, un terreno o La Grieta, sale una línea abajo que lo explica (7 s; se recuerda en `opciones.json` → `tips`). No sale durante el tutorial ni en las pruebas.
- [x] **Estadísticas por partida** en la pantalla final (mejor bestia y sus bajas, mejor Brasa, dones, augurios aceptados, terreno), con el demonio a la izquierda y Tizón a la derecha.
- [x] **Medida de variedad** (`tools/variedad.gd`, `godot --headless --path . -s res://tools/variedad.gd`, 60 pares de semillas seguidas): distancia media de composición por oleada 0,25 (antes 0: idénticas); augurios repetidos entre dos partidas 28%; opciones del primer draft repetidas 22% (antes ~30% con el pool viejo).
- [x] **Previsión con el augurio** — Marea multiplica los comunes, Campeón añade «élite al azar», Niebla avisa del frente único; tarjetas con 3 líneas y nombres largos que no se salen.


## Entorno (paso 0)
- [x] Godot 4.7.2 estándar en `/opt/godot/godot` (enlace `/usr/local/bin/godot`), desde
  `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`.
- Pruebas: `godot --headless --editor --import --path .` (una vez) y `godot --headless --path . res://tests/run_scene.tscn` → `FIN_SUITE fallos=0` (≈4 s).
- Capturas: `xvfb-run` ya instalado (apt `xvfb`).
- Plantillas web 4.7.2 en `~/.local/share/godot/export_templates/4.7.2.stable/` (solo las dos `web_nothreads_*`).
- [ ] Guardar los pasos como setup script de un entorno propio (el entorno actual es el Default; se propondrá al final para no bloquear el turno con una aprobación).

## Lista
1. [x] Comprobación visual — `tools/shots.tscn` hace 11 capturas (ver cabecera). Arreglado: bestiario con 7+ formas solapado (ahora 2 columnas), botones de victoria/derrota tapados por el velo, retrato y epitafio solapados, banner tapando tarjetas/árbol/rutas, tooltip cortado y con nombre repetido, etiquetas de élite cortadas, estados («agarrado») encima del nombre, texto de combate cortado, título del árbol encima de las ramas, criaturas de la forja encima del texto, icono vacío en recompensas (ahora +45, +40%, +30).
2. [x] Fallos — corregidos con pruebas (`test_bugfixes`): pinza del Alacrán, brea del Sapo y golpe de la Manta multiplicaban el nivel/cicatrices/manada dos veces; el Capataz anulaba la ralentización de la brea (ahora se multiplican); los apoyos aturdidos seguían curando. En la vista: la esencia elegida en el draft no se guardaba hasta la siguiente oleada.
3. [x] Equilibrio (bot torpe) — `tests/bot.gd` + `tools/balance.tscn` (+ `tools/debug_run.tscn` para seguir una partida).
   Antes: primera partida 80% (Verdugo 65 / Inquisidor 95), con árbol 100% desde la 2.ª partida. Después: 55% (48 / 64) en 120 partidas; árbol 80→85%, 150→98%.
   Cambios (todo JSON salvo la esencia, que pasa a `balance.json` → `meta`): Puerta 180→130; oleadas 4-6 más cargadas; Horno más fuerte y de más alcance; Trueno algo más débil; curas de clérigo/Lumbrero y barrido del Tajo rebajados; Verdugo menos letal (ejecuta al 12%); draft con menos bestias (2/2/2/1) y más recompensas (2); esencia 10+5n y 60 por victoria.
   La causa de la diferencia entre rutas era el héroe Verdugo ejecutando bestias en la oleada 5. Nota: la curva con árbol sube rápido; el segundo asedio (punto 5) debe ser el reto siguiente.
4. [x] Pulido y sensación — `scripts/juice.gd`: destello y aplastamiento al recibir golpe, chispas/ceniza/ascuas, números de daño que se suman, temblor por trauma con ruido (opción para quitarlo), pausa breve al matar élites/héroes, Brasa con 3+ impactos y barrido del Tajo; ascuas de ambiente; banner que entra deslizando y fundido a negro en cambios de fase. Sonidos por capas propios (Capataz/élite al aparecer, Lumbrero, Tirador apunta/dispara, Tajo carga/barre, Campana, Alacrán, Sapo, Manta, muerte grande). `scripts/menu.gd`: menú principal (Esc), Cómo se juega, Opciones guardadas y tutorial de la primera partida (5 pasos con resaltado).
5. [x] Más contenido — pack 2 de bestias (Gárgola de Ceniza, Enjambre Ígneo, Ánima del Garfio; siluetas por código), segundo asedio «la Orden del Alba» de 8 oleadas con Zapador, Paladín, Sacerdotisa, Ariete y jefe Gran Maestre (Juicio por carril y escolta), selección de asedio en el menú, desbloqueo al ganar, y niveles de Ira 0-5 para rejugar. Equilibrio: asedio 1 58%; asedio 2 28%/90% con 300/600 de esencia; Ira escala bien con el árbol. Pruebas en `test_content`.
6. [x] Versión web — https://infrakuervo.github.io/la_ultima_puerta/ (rama `gh-pages`). Preset `Web` en `export_presets.cfg` (sin hilos). Plantillas: solo `web_nothreads_*.zip`, sacadas del .tpz con peticiones por rangos (`/tmp/claude-0/py/remotezip.py`, ver nota de entorno). Republicar: `tools/publish_web.sh`. Probada en Chromium sin cabeza (menú, tutorial, combate).
7. [x] Cierre — descripción del PR #1 actualizada (con capturas de `docs/capturas/`), web republicada y tarea programada desactivada.

## Resumen final
- Godot 4.7.2 en headless: 215 comprobaciones, 0 fallos. Web: https://infrakuervo.github.io/la_ultima_puerta/
- Hecho: revisión visual y arreglos de interfaz; 5 fallos de lógica corregidos con prueba; bot torpe y equilibrio (primera partida del 80% al 58%, con las dos rutas igualadas); sensación de golpe (partículas, números, destellos, trauma, pausa breve, sonidos por capas); menú, opciones y tutorial; pack 2 de bestias; segundo asedio con jefe; Ira 0-5; versión web en gh-pages.

## Siguientes ideas
- Jugarlo a mano y ajustar la sensación (tiempos de la Brasa, tamaño de los números, volumen de cada sonido).
- Curva con árbol: el primer asedio se vuelve fácil en 1-2 partidas. Opciones: subir los costes del árbol, limitar los rangos por asedio o pedir Ira para algunos nodos.
- Arte final para el pack 2 y los enemigos del Alba (ahora son siluetas y sprites con tinte).
- Música procedural de fondo y un control de volumen separado para música y efectos.
- Tercer asedio (por ejemplo, la Inquisición con magia) con una mecánica nueva de mapa: carriles que se cierran o una Puerta con dos hojas.
- Logros y estadísticas por partida (bajas por bestia, mejor oleada) para dar más motivos de volver.
- Guardar a mitad de partida.

## Notas
- Entorno: el setup script se propone al final con `create_environment`. Si no se aprobó, los pasos son: descargar Godot 4.7.2 Linux (zip de GitHub) en `/opt/godot`, `apt-get install -y xvfb`, y sacar `web_nothreads_*.zip` del .tpz.
