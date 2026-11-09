# La Última Puerta — notas para Claude

Godot 4.7 / GDScript, un demonio defiende la puerta del Infierno (ritmo estilo Legion Breaker). El usuario habla español y trabaja en Windows; prefiere comandos PowerShell listos para copiar antes que explicaciones largas. Rama de trabajo: `prototype/first-siege` (PR #1, borrador).

## Arquitectura
- `scripts/sim.gd`: toda la lógica, sin dibujo. Tick fijo 1/30 s; la vista lee `events`.
- `scripts/main.gd`: vista, ratón y sonido (modo inmediato en `_draw()`). `scripts/art.gd`: sprites y siluetas de reserva.
- Datos: `data/balance.json` (bestias, enemigos, élites, economía, `draft.pool`), `data/waves.json`, `data/skills.json` (árbol, efectos `fx` con `mul`/`add`).
- Arena abierta con zonas de retaguardia y vanguardia; oleadas desordenadas por frentes al azar; Brasa (área con retraso, apuntada con el ratón) y Rayo.

## Decisiones tomadas
- El árbol (69 nodos) se paga con **Esencia permanente**, guardada en `user://meta.json` junto con los rangos. Se gana por oleada (20+10·n) y +100 por victoria. Las almas son solo de la partida (Sabuesos, Ojos, niveles).
- Tras cada oleada se elige 1 de 3 (`draft.pool`): bestias gratis o recompensas. Añadir un pack nuevo = entrada en `balance.json` (con `spot`) + `_ai_*` en `sim.gd` + sprite en `art/sprites/` + línea en el pool.
- Los modos permanente y elección están desactivados por defecto en `Sim` (`meta_mode`, `draft_enabled`) y los activa `main.gd`, salvo en las pruebas (`Engine` meta `sin_persistencia`).
- Élites con habilidad propia y variantes de aspecto de los enemigos comunes; los diseños elegidos del arte están en `art/LEEME*.md`.

## Pruebas
`tests/suite.gd` vía `tests/run_scene.tscn`; debe terminar en `FIN_SUITE fallos=0` (182 comprobaciones). Incluye un bot que gana 5/5 por ruta, pero apunta perfecto y no usa las bestias nuevas.

## Pendiente
- Bot torpe (puntería imperfecta) para reajustar números, y bot que use el draft.
- Comprobar en pantalla élites, bestias nuevas, tarjetas de elección y bestiario con 7 formas.
- Sonidos propios para élites y bestias nuevas (ahora reutilizan los existentes).
- Dificultad con tiradas reales; actualizar la descripción del PR #1.
- Llegarán más packs de bestias.
