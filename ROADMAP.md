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
3. [x] Equilibrio (bot torpe) — `tests/bot.gd` + `tools/balance.tscn` (+ `tools/debug_run.tscn` para seguir una partida).
   Antes: primera partida 80% (Verdugo 65 / Inquisidor 95), con árbol 100% desde la 2.ª partida. Después: 55% (48 / 64) en 120 partidas; árbol 80→85%, 150→98%.
   Cambios (todo JSON salvo la esencia, que pasa a `balance.json` → `meta`): Puerta 180→130; oleadas 4-6 más cargadas; Horno más fuerte y de más alcance; Trueno algo más débil; curas de clérigo/Lumbrero y barrido del Tajo rebajados; Verdugo menos letal (ejecuta al 12%); draft con menos bestias (2/2/2/1) y más recompensas (2); esencia 10+5n y 60 por victoria.
   La causa de la diferencia entre rutas era el héroe Verdugo ejecutando bestias en la oleada 5. Nota: la curva con árbol sube rápido; el segundo asedio (punto 5) debe ser el reto siguiente.
4. [x] Pulido y sensación — `scripts/juice.gd`: destello y aplastamiento al recibir golpe, chispas/ceniza/ascuas, números de daño que se suman, temblor por trauma con ruido (opción para quitarlo), pausa breve al matar élites/héroes, Brasa con 3+ impactos y barrido del Tajo; ascuas de ambiente; banner que entra deslizando y fundido a negro en cambios de fase. Sonidos por capas propios (Capataz/élite al aparecer, Lumbrero, Tirador apunta/dispara, Tajo carga/barre, Campana, Alacrán, Sapo, Manta, muerte grande). `scripts/menu.gd`: menú principal (Esc), Cómo se juega, Opciones guardadas y tutorial de la primera partida (5 pasos con resaltado).
5. [ ] Más contenido
6. [ ] Versión web (gh-pages)
7. [ ] Cierre

## Notas
