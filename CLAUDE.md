# La Última Puerta — notas para Claude

Godot 4.7 (probado con 4.7.2) / GDScript, un demonio defiende la puerta del Infierno (ritmo estilo Legion Breaker). El usuario habla español y trabaja en Windows; prefiere comandos PowerShell listos para copiar antes que explicaciones largas. Rama de trabajo: `prototype/first-siege` (PR #1, borrador).

## Arquitectura
- `scripts/sim.gd`: toda la lógica, sin dibujo. Tick fijo 1/30 s; la vista lee `events`.
- `scripts/main.gd`: vista, ratón y sonido (modo inmediato en `_draw()`). `scripts/art.gd`: sprites y siluetas de reserva.
- Animación (solo vista): `scripts/anim.gd` (fotogramas de `art/anim/`, datos en `data/anim.json`, carga perezosa, sin fotogramas → sprite fijo) y `scripts/poses.gd` (respiración/trote/embestida/retroceso por código y reproductores de las bestias con fotogramas). `main.gd` dibuja cada unidad con `_draw_posed`: sombra plana y cuerpo con `draw_set_transform(arena_offset + ...)` (esa función sustituye la transformación: siempre componer el temblor). Para un clip nuevo: carpeta con 01.png… + entrada en `data/anim.json` + `play()` en el evento que toque.
- `scripts/juice.gd` (partículas, números, destellos, trauma de cámara, hitstop) y `scripts/menu.gd` (menú, opciones, tutorial) son ayudantes de la vista; reciben `main` y dibujan con él. La simulación no sabe nada de ellos.
- Eventos de la simulación usados por la vista: `hit` y `kill` llevan `id`, `amount`/`kind` e `y`; `elite_spawn` al aparecer élites y héroes.
- Datos: `data/balance.json` (bestias, enemigos, élites, economía, `draft.pool`), `data/waves.json`, `data/skills.json` (árbol, efectos `fx` con `mul`/`add`).
- Arena abierta con zonas de retaguardia y vanguardia; oleadas desordenadas por frentes al azar; Brasa (área con retraso, apuntada con el ratón) y Rayo.

## Decisiones tomadas
- El árbol (69 nodos) se paga con **Esencia permanente**, guardada en `user://meta.json` junto con los rangos. Se gana por oleada y por victoria (`balance.json` → `meta`). Las almas son solo de la partida (Sabuesos, Ojos, niveles).
- Tras cada oleada se elige 1 de 3 (`draft.pool`): bestias gratis o recompensas. Añadir un pack nuevo = entrada en `balance.json` (con `spot`) + `_ai_*` en `sim.gd` (y su caso en `_update_creature`) + sprite en `art/sprites/` **o** silueta por código en `Art.draw_creature` (pack 2: gárgola, enjambre, garfio) + línea en el pool + texto en `FORM_INFO` de `main.gd`. Mantener los pesos de bestias del pool bajos (1): cada bestia más en el pool sube mucho la tasa de victorias.
- Asedios en `waves.json` → `sieges` (`unlock` = id del asedio que hay que ganar). `Sim.set_siege(i, ira)` antes de `reset()`. Ira multiplica vida/daño enemigos y esencia (`balance.json` → `wrath`). Lo ganado se guarda en `user://meta.json` → `asedios` (id → mayor Ira ganada).
- Enemigos con banderas de datos: `ignore_block`, `explode`, `burn_immune`, `unstoppable`, `shield_cd`, `judge_cd`, `summon_at`/`summon`, `tint`/`sprite`/`scale` (reutilizan sprites con tinte; no hay arte nuevo con IA).
- Los modos permanente y elección están desactivados por defecto en `Sim` (`meta_mode`, `draft_enabled`) y los activa `main.gd`, salvo en las pruebas (`Engine` meta `sin_persistencia`).
- Élites con habilidad propia y variantes de aspecto de los enemigos comunes; los diseños elegidos del arte están en `art/LEEME*.md`.

## Pruebas y herramientas
- `godot --headless --editor --import --path .` (una vez) y `godot --headless --path . res://tests/run_scene.tscn` → `FIN_SUITE fallos=0`. (`--script res://tests/run_tests.gd` no funciona.)
- `tests/bot.gd`: bot torpe (reacción lenta, puntería con error, draft mediano). Objetivo de equilibrio: ~40-60% en la primera partida; hoy 55%.
- Capturas útiles: `tools/shots.tscn -- <dir> demonio|animacion|intro|victoria|derrota`.
- `tools/balance.tscn` (informe de equilibrio), `tools/debug_run.tscn` (línea de tiempo de una partida), `tools/shots.tscn` (capturas con xvfb-run).
- `*.uid` e `*.import` están en `.gitignore` para no chocar con la copia local del usuario.

## Versión web
- https://infrakuervo.github.io/la_ultima_puerta/ — republicar con `tools/publish_web.sh` tras cada cambio importante. `export_presets.cfg` sí se versiona.

## Pendiente
- Dificultad con tiradas reales; actualizar la descripción del PR #1.
- Más packs de bestias y asedios (el patrón está arriba).
