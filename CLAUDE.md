# La Última Puerta — notas para Claude

Godot 4.7 (probado con 4.7.2) / GDScript, un demonio defiende la puerta del Infierno (ritmo estilo Legion Breaker). El usuario habla español y trabaja en Windows; prefiere comandos PowerShell listos para copiar antes que explicaciones largas. Rama de trabajo: `prototype/first-siege` (PR #1, borrador).

## Arquitectura
- `scripts/sim.gd`: toda la lógica, sin dibujo. Tick fijo 1/30 s; la vista lee `events`.
- `scripts/main.gd`: vista, ratón y sonido (modo inmediato en `_draw()`). `scripts/art.gd`: sprites y siluetas de reserva.
- Animación (solo vista): `scripts/anim.gd` (fotogramas de `art/anim/`, datos en `data/anim.json`, carga perezosa, sin fotogramas → sprite fijo) y `scripts/poses.gd` (respiración/trote/embestida/retroceso por código y reproductores de las bestias con fotogramas). `main.gd` dibuja cada unidad con `_draw_posed`: sombra plana y cuerpo con `draw_set_transform(arena_offset + ...)` (esa función sustituye la transformación: siempre componer el temblor). Para un clip nuevo: carpeta con 01.png… + entrada en `data/anim.json` + `play()` en el evento que toque.
- Efectos de Flow: `scripts/fx_layer.gd` (mezcla aditiva, por encima: explosión de Brasa, Rayo, Juicio, bola en vuelo; `spawn`, `spawn_rect`, `add_loop`) y `main.gd` → `_draw_ground_fx` (llamas y santuario en el suelo, con transparencia, debajo de las unidades). Ver `art/anim/LEEME.md`.
- `scripts/juice.gd` (partículas, números, destellos, trauma de cámara, hitstop) y `scripts/menu.gd` (menú, opciones, tutorial) son ayudantes de la vista; reciben `main` y dibujan con él. La simulación no sabe nada de ellos.
- Eventos de la simulación usados por la vista: `hit` y `kill` llevan `id`, `amount`/`kind` e `y`; `elite_spawn` al aparecer élites y héroes.
- Datos: `data/balance.json` (bestias, enemigos, élites, economía, `draft.pool`), `data/waves.json`, `data/skills.json` (árbol, efectos `fx` con `mul`/`add`).
- Arena abierta con zonas de retaguardia y vanguardia; oleadas desordenadas por frentes al azar; Brasa (área con retraso, apuntada con el ratón) y Rayo.

## Decisiones tomadas
- El árbol (110 nodos, 10 ramas) se paga con **Esencia permanente**, guardada en el `meta.json` del personaje junto con los rangos (`habilidades`) y lo pagado por nodo (`pagado`).
- **El árbol se sube al terminar la partida, con las almas que sobran**: `Sim._bank_souls()` (victoria y derrota) convierte cada alma en 1 de esencia (`meta.soul_rate`, sin multiplicar por la Ira) y lo deja en `Sim.banked` para la pantalla final. Hay un extra pequeño por oleada y por ganar (`meta.wave_base/wave_step/victory`). `Sim.tree_shop_open()` manda en `can_skill` y `can_respec`: en modo permanente solo al acabar (victoria/derrota) o entre partidas (`between_runs`, que ponen el menú con `main.open_tree_shop()` y el bot; `start_wave()` lo apaga). Entre oleadas el árbol se mira, no se compra. Sin modo permanente (pruebas antiguas) se sigue comprando con almas en preparación. Costes: `cost_base × meta.cost_scale × (1 + meta.inflation × rangos)`.
- **Personajes** (solo vista, `scripts/perfiles.gd`): `user://personajes.json` (lista, último usado) y `user://personajes/<id>/{meta.json, partida.txt, bestiario.json}`; las opciones son generales. `main._pfile(nombre)` da la ruta del personaje en uso (nunca escribir rutas `user://` a mano), `main._open_profile()` cambia de personaje (vacía todo el estado y carga el suyo) y `Perfiles._migrate_legacy()` convierte los archivos antiguos en el primero. Las pruebas usan una carpeta temporal con la meta de `Engine` `perfiles_root` (no tocan `user://`). El nombre se escribe en un `LineEdit` (`main.name_edit`) que solo se ve en el panel `nuevo` del menú.
- Tras cada oleada se elige 1 de 3 (`draft.pool`): bestias gratis o recompensas. Añadir un pack nuevo = entrada en `balance.json` (con `spot`) + `_ai_*` en `sim.gd` (y su caso en `_update_creature`) + sprite en `art/sprites/` **o** silueta por código en `Art.draw_creature` (pack 2: gárgola, enjambre, garfio) + línea en el pool + texto en `FORM_INFO` de `main.gd`. Mantener los pesos de bestias del pool bajos (1): cada bestia más en el pool sube mucho la tasa de victorias.
- Asedios en `waves.json` → `sieges` (`unlock` = id del asedio que hay que ganar). `Sim.set_siege(i, ira)` antes de `reset()`. Ira multiplica vida/daño enemigos y el extra de esencia (`balance.json` → `wrath`). Lo ganado se guarda en el `meta.json` del personaje → `asedios` (id → mayor Ira ganada).
- Enemigos con banderas de datos: `ignore_block`, `explode`, `burn_immune`, `unstoppable`, `shield_cd`, `judge_cd`, `summon_at`/`summon`, `tint`/`sprite`/`scale` (algunos reutilizan sprites con tinte; Zapador, Gran Inquisidor, Gran Maestre, Ariete, Sacerdotisa y Purificador ya tienen sprite propio de Flow). Fondo por asedio: `background` en `waves.json` → `Art.background(archivo)`. Tamaño de cada sprite: `Art.SPRITE_H` (clave entera si existe, si no lo de antes del primer «_», ver `Art.size_key`).
- Los modos permanente y elección están desactivados por defecto en `Sim` (`meta_mode`, `draft_enabled`) y los activa `main.gd`, salvo en las pruebas (`Engine` meta `sin_persistencia`).
- Élites con habilidad propia y variantes de aspecto de los enemigos comunes; los diseños elegidos del arte están en `art/LEEME*.md`.
- Rejugabilidad (todo con banderas en `Sim`, que la vista y el bot activan y las pruebas no, para que sigan siendo deterministas):
  - `remix_enabled`: oleadas remezcladas por partida (`waves.json` → `remix` por asedio; el grupo principal conserva su tipo).
  - `augurs_enabled`: dos augurios antes de cada oleada desde la 2 (`balance.json` → `augurs`, efectos con `augur_fx(k)`); `week_augur` para el reto semanal.
  - Draft con `rarity` y dones (`type: boon`, `fx` como el árbol, se suman en `_fx_totals`); `unlock: true` = solo si `Sim.unlocked` lo tiene (logros).
  - Santuario (asedio con `sanctuary`, la Inquisición): `_place_sanctuary()` al preparar y `_update_sanctuary()` cada 0,5 s.
  - La Grieta: asedio con `endless`; `_gen_wave(i)` genera oleadas tras las del asedio base; no hay victoria, récord en `records.grieta`.
  - Árbol con inflación (`meta.inflation`): cada rango comprado encarece los demás.
- Árbol 2 (`data/skills.json`; todo por datos salvo la regla de cada piedra angular):
  - `keystone: true` = piedra angular (rango único; su regla se lee en `sim.gd` con `fadd("special.<clave>")` y su contrapartida suele ser un `fx` normal). Parámetros en `balance.json` → `meta` (`tizon_revive`, `burst_r`, `ground_burn`, `arc_max`, `profane`).
  - `excl: <id>` = camino excluyente (los dos nodos se apuntan entre sí). `skill_state()` devuelve además `"excluded"` y `"sealed"`.
  - `branches[].unlock` = asedio que hay que ganar (`Sim.won`, que la vista rellena con `siege_wins`). Solo sella en `meta_mode`.
  - Dones: `set.need.<familia>` (suma al mínimo de 2), `set.power.<familia>`, `draft.family.<familia>`, `draft.kind.<bestia>`, `draft.rarity.<rareza>`. Las resonancias se suman al final de `_fx_totals()` para poder leer esas claves.
  - `Sim.skill_paid` apunta lo pagado por nodo; `respec(rama)` devuelve `meta.respec_refund` de eso y solo vale con la tienda abierta (`tree_shop_open()`). `load_tree(guardado, pagado)` migra: lo que ya no existe (`legacy` en el JSON) se devuelve entero. No renombrar ids sin pasar por ahí.
  - Vista (`main.gd`): `tree_tab` (pestaña), `_build_tree_pos()` coloca cada rama en dos columnas + una lateral (`side`), `_draw_tree_panel()` es el detalle fijo. Para un nodo nuevo basta el JSON; comprobar con `tools/shots.tscn -- <dir> arbol` y la prueba de solapes de `test_ui_smoke`.
  - Bot: `tests/bot.gd` → `STYLES` (lista de deseos, ramas, piedras y caminos que acepta). `tools/balance.tscn` repite la carrera con cada estilo y compara árboles.
- Logros (`data/logros.json` + `scripts/logros.gd`) y música procedural (`scripts/music.gd`, `AudioStreamGenerator` en modo stream, buses `Musica`/`Efectos`) son de la vista.

## Pruebas y herramientas
- `godot --headless --editor --import --path .` (una vez) y `godot --headless --path . res://tests/run_scene.tscn` → `FIN_SUITE fallos=0`. (`--script res://tests/run_tests.gd` no funciona.)
- `tests/bot.gd`: bot torpe (reacción lenta, puntería con error, draft mediano, augurio al azar el 60%). Objetivo de equilibrio: ~40-60% en la primera partida; hoy ~50% con variedad. `BAL_CLIMB=1` simula una carrera subiendo Ira tras cada victoria, una vez por estilo de compra (`BAL_STYLE=mixto,fuego,manada`; medias 59 / 57 / 60%; deben seguir parecidas y con árboles distintos); `BAL_SIEGE=3` mide La Grieta (0-2: asedios) (oleadas superadas con `BAL_ESS`).
- Capturas útiles: `tools/shots.tscn -- <dir> demonio|animacion|intro|augurio|draft|asedios|partida|victoria|derrota|arbol|piedras|personajes` (`partida` juega una partida entera con el bot a través de la vista).
- `tools/balance.tscn` (informe de equilibrio), `tools/debug_run.tscn` (línea de tiempo de una partida), `tools/shots.tscn` (capturas con xvfb-run).
- `*.uid` e `*.import` están en `.gitignore` para no chocar con la copia local del usuario.

## Versión web
- https://infrakuervo.github.io/la_ultima_puerta/ — republicar con `tools/publish_web.sh` tras cada cambio importante. `export_presets.cfg` sí se versiona.

## Pendiente
- Ver ROADMAP.md (secciones «Árbol al final y personajes», «Árbol 2», «Noche 2» y «Rejugabilidad») para lo hecho y lo siguiente.
- Más packs de bestias y asedios (el patrón está arriba).
