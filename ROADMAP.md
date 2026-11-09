# ROADMAP — trabajo autónomo

Memoria entre turnos. Al empezar cada turno: leer esto y seguir por el primer punto pendiente.
Tarea programada «La Última Puerta: seguir» (trig_01MLzV3vNtp2KM7sJUp7qaTV, cada hora, minuto 16) creada.

## Entorno (paso 0)
- [x] Godot 4.7.2 estándar en `/opt/godot/godot` (enlace `/usr/local/bin/godot`), desde
  `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`.
- Pruebas: `godot --headless --editor --import --path .` (una vez) y `godot --headless --path . res://tests/run_scene.tscn` → `FIN_SUITE fallos=0` (≈4 s).
- Capturas: `xvfb-run` ya instalado (apt `xvfb`).
- [ ] Guardar los pasos como setup script de un entorno propio (el entorno actual es el Default; se propondrá al final para no bloquear el turno con una aprobación).

## Lista
1. [x] Comprobación visual — `tools/shots.tscn` hace 11 capturas (ver cabecera). Arreglado: bestiario con 7+ formas solapado (ahora 2 columnas), botones de victoria/derrota tapados por el velo, retrato y epitafio solapados, banner tapando tarjetas/árbol/rutas, tooltip cortado y con nombre repetido, etiquetas de élite cortadas, estados («agarrado») encima del nombre, texto de combate cortado, título del árbol encima de las ramas, criaturas de la forja encima del texto, icono vacío en recompensas (ahora +45, +40%, +30).
2. [x] Fallos — corregidos con pruebas (`test_bugfixes`): pinza del Alacrán, brea del Sapo y golpe de la Manta multiplicaban el nivel/cicatrices/manada dos veces; el Capataz anulaba la ralentización de la brea (ahora se multiplican); los apoyos aturdidos seguían curando. En la vista: la esencia elegida en el draft no se guardaba hasta la siguiente oleada.
3. [ ] Equilibrio (bot torpe)
4. [ ] Pulido y sensación
5. [ ] Más contenido
6. [ ] Versión web (gh-pages)
7. [ ] Cierre

## Notas
