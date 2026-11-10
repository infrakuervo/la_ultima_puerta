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
7. [ ] Peso y web: medir, reducir si pasa de ~40 MB, republicar y comprobar en Chromium.
8. [ ] Rejugabilidad (ampliación del encargo: ver sección «Rejugabilidad»), incluye curva del árbol, música procedural con volúmenes aparte y logros/estadísticas.
9. [ ] Cierre: PR #1, resumen y lista de animaciones que faltan para Flow. La tarea programada solo se desactiva si ya no queda margen.

## Rejugabilidad (ampliación de la noche 2)
El usuario quiere «un procedural divertido que dé horas de juego sin cansar aunque sea repetitivo».
Plan: tras los puntos 1-7, jugar partidas de verdad (bot torpe, capturas, `tools/debug_run.tscn`), apuntar aquí qué se repite y qué aburre, y luego valorar: oleadas generadas con presupuesto, modificadores por oleada, sinergias y builds, draft con rareza, retos semanales con semilla, desbloqueos meta de contenido, ritmo (x3, menos tiempos muertos). Medir con el bot antes y después.

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
