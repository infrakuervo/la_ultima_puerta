# La Última Puerta

Prototipo (Godot 4.7, GDScript) de «Primer asedio»: defiendes la última puerta del Infierno lanzando hechizos con el ratón (Brasa y Rayo) y criando bestias que mutan y suben de nivel.
Se juega entero con el ratón, de la oleada 1 a la victoria o la derrota, y se reinicia desde la pantalla de resultados.

## Jugar en el navegador

**https://infrakuervo.github.io/la_ultima_puerta/** (versión web, GL Compatibility sin hilos; se actualiza con `tools/publish_web.sh`).

## Cómo ejecutarlo

1. Instala Godot 4.7.x (estándar, no .NET).
2. Abre `project.godot` desde el gestor de proyectos y pulsa F5, o desde PowerShell:

```powershell
godot --path C:\ruta\a\la_ultima_puerta
```

Controles:
- Entre oleadas: arrastra una bestia a la retaguardia (muro de atrás, zona izquierda) o a la vanguardia (cerca de los enemigos). Clic en una bestia para seleccionarla y **Subir nivel**.
- En combate: clic en la arena lanza el hechizo activo en el cursor; mantener el botón lo repite en cuanto se recarga. Cambia de hechizo con clic derecho, rueda, teclas 1/2 o los botones de abajo. Pulsar la interfaz no lanza nada.
- Botones: **Árbol** (T), **Iniciar oleada** (Espacio), **Velocidad** x1/x2/x3 (F), **Bestiario** (B). **Esc** abre el menú (pausa).
- Menú principal con Jugar/Continuar, «Cómo se juega» y Opciones (volumen, velocidad inicial, temblor de pantalla, repetir tutorial; se guardan en `user://opciones.json`). La primera partida trae un tutorial breve.
Pantalla 1280x720 con GL Compatibility.

## Pruebas automáticas

Desde la raíz del repo (la primera orden importa los recursos y solo hace falta una vez):

```powershell
godot --headless --editor --import --path .
```

```powershell
godot --headless --path . res://tests/run_scene.tscn
```

Debe terminar con `FIN_SUITE fallos=0`.

Sale con 0 si todo pasa. También se puede abrir y ejecutar `tests/run_scene.tscn` desde el editor (la salida va al registro del juego). Comprueba: datos, combate de la oleada 1, Presa, Brasa, Rayo, niveles, vuelta de Tizón con cicatriz, flujo de ruta y reliquia (ambas rutas), Horno, Trueno y su hueco, Ojo (combo y marca), préstamo del Ojo, economía, partidas completas automáticas de las dos rutas (Puerta invulnerable) y un recorrido por la interfaz con el ratón. Al final imprime un informe de equilibrio (5 semillas por ruta).

## Rejugabilidad

- **Cada partida es distinta:** las oleadas se remezclan (mismo presupuesto, otra composición) y antes de cada oleada eliges un **augurio** de riesgo/recompensa o ninguno.
- **Draft con rareza:** además de bestias y recompensas salen **dones** raros y épicos que duran toda la partida y empujan a una build (fuego, rayo, bestias, almas, Puerta). Algunos se abren con **logros**.
- **La Grieta:** modo sin fin con oleadas generadas que no paran de crecer; guarda tu récord.
- **Reto semanal:** misma semilla para todos durante la semana, con un augurio fijo y récord propio.
- **Logros y estadísticas** en el menú; **música procedural** que sube con el combate (volumen aparte de los efectos); velocidad x1/x2/x3.
- El árbol encarece cada rango comprado, así la Ira sigue siendo un reto durante muchas partidas.

## Estructura

- `scripts/sim.gd`: toda la lógica, sin dibujo ni sonido (tick fijo de 1/30 s).
- `scripts/main.gd`: vista, ratón y avisos. `scripts/art.gd`: sprites y siluetas. `scripts/sound_bank.gd`: sonidos procedurales (con capas para élites y bestias nuevas).
- `scripts/juice.gd`: partículas, números de daño, destello al golpear, temblor suave y pausa breve en los golpes grandes. `scripts/menu.gd`: menú, opciones y tutorial.
- `data/balance.json`: costes, vidas, daños, tiempos, casillas. `data/waves.json`: oleadas, rutas y textos. Todo se edita sin tocar código.
- `user://bestiario.json`: bestiario sencillo (formas vistas y registro de Tizón).

## Qué hay (orden de URI-111)

00. Árbol de habilidades (`data/skills.json`, 69 nodos y 235 rangos en 8 ramas: Brasa, Rayo, Demonio, Bestias, Jauría, Horno y Trueno —estas dos se abren al elegir ruta—, Ojo). Cada rango se compra con almas entre oleadas; hay requisitos entre nodos, y las mejoras de bestias (vida, daño, velocidad, cicatrices, manada, regeneración) conviven con las de cada forma. Los efectos son datos (`fx`: `mul`/`add` sobre una clave como `brasa.cd` o `horno.inhale_max`), así que se amplía editando el JSON. La Brasa empieza lenta (cae a 1,5 s, enfriamiento 6,5 s, radio 75) para que el árbol la mejore.
0. Dirección anterior (URI-117 + niveles): arena abierta sin casillas, con retaguardia y vanguardia; los enemigos llegan sin orden por frentes sorteados; el demonio ya no ataca solo: **Brasa** (círculo con retardo y llamas) y **Rayo** (inmediato, con cadena) se lanzan con el ratón; con almas se suben de nivel las bestias (+25% de vida y daño por nivel, máximo 3) y se mejoran los hechizos (radio de Brasa, cadena de Rayo).
1. Partida base: Puerta, Tizón con Presa, campesinos, previsión de la oleada, colocación libre, x1/x2, reinicio.
2. Seis oleadas, elección de ruta tras la 4, héroe y reliquia en la 5, pantallas de victoria y derrota.
3. Mutaciones: Horno de Fosas (Verdugo) y Sabueso del Trueno (Inquisidor), Ojo de Latón con combos visibles y préstamo en la oleada 6.
4. Economía (reclutar, Ojo, mejoras de hechizos, subir nivel) y vínculo (Tizón conserva el nombre, vuelve gratis con cicatriz, bestiario).
5. Legibilidad: tres siluetas, aviso y sonido propios por forma (PRESA, INHALA, SALTA/HUECO, CAMPANA, MARCA, COMBO) y animación de mutación en pantalla.

Fuera de alcance a propósito: Árbol del Abismo y Ceniza, Caballero del Alba, repeticiones, arte final.

## Números clave (primera pasada, en `data/balance.json`)

Almas iniciales 40; bonus por oleada 15; Sabueso 40, Ojo 60, subir nivel 30/45 (65/90 con «Más allá del límite»); las mejoras de hechizo ya van en el árbol.
Puerta 130. Brasa inicial: 40 de daño en radio 75, cae a los 1,5 s, enfriamiento 6,5 s, quema; el árbol la acelera y la ensancha. Rayo: 38 de daño, enfriamiento 1,2 s, alcance 800; mejorado salta al 60% a un segundo blanco.
Horno: inhala hasta 5 enemigos (alcance 460, enfriamiento 6 s), escupe 34 en 280 px y quema 8/s durante 4 s.
Trueno: salto cada 10 s (alcance 760), 32 al caer y descargas 16/12/8, vuelve a los 6 s. Salta a apoyos y tiradores (élites incluidas).
Ojo: 12 de daño, y sobre enemigos en llamas encadena a 3 más.

## Situaciones para probar a mano

- **La colocación mejora la partida:** en la oleada 4, el Horno en la vanguardia agrupa a los escuderos que llegan por el mismo frente y la llamarada cubre a varios; con el Ojo en la retaguardia el combo de llamas encadena, y una Brasa sobre el grupo remata. Con el Horno lejos del frente por donde entran no inhala nada.
- **El salto del Trueno deja pasar a un enemigo:** con un clérigo en un frente y escuderos en otro, el Trueno salta al clérigo y el frente que cubría queda sin bloqueo (aparece HUECO). Los escuderos avanzan hasta que vuelve.

## Estado de verificación

Ver la descripción del PR: qué se ha ejecutado y qué no.

## Arte

Pack de la Fosa en `art/` (fondo y 11 sprites, reducidos a ~1,6x su tamaño en pantalla). Si falta algún PNG se usa la silueta provisional de `scripts/art.gd`.
Cada enemigo común aparece con una de tres variantes de aspecto (sorteada al salir; los héroes no varían).

### Animaciones

- Por fotogramas (`art/anim/`, vídeos de Google Flow recortados; ver `art/anim/LEEME.md`): el demonio (reposo, Rayo, Brasa, golpe, victoria y derrota; también en el menú y en las pantallas finales), Tizón y los Sabuesos (carrera y mordisco) y el Horno (reposo, carrera y mordisco). Los datos de cada clip están en `data/anim.json` (fps, bucle, fotograma de impacto, mano, alto y pies); `scripts/anim.gd` los carga cuando hacen falta. Si falta una carpeta o un fotograma se usa el sprite fijo.
- Por código para todos los demás (`scripts/poses.gd`): respiración, trote, embestida al atacar y retroceso al recibir.
- Intro en vídeo (`art/video/intro_demonio.ogv`) al abrir el juego; se salta con clic o tecla y se quita en Opciones.
- Versión web: `tools/publish_web.sh` importa los fotogramas como WebP con pérdida (`tools/anim_lossy.sh`), así el `.pck` pesa ~14 MB.

## Élites

Seis unidades con habilidad propia, en `data/balance.json` (campo `elite`) y `data/waves.json`:

- **Capataz** (oleada 3, 6): acelera ×1,4 a los aliados en 170 px.
- **Muro de Marfil** (4, 6): absorbe 60% del daño al aliado que protege.
- **Tirador** (4): avisa y dispara un virote que atraviesa hasta 3 criaturas de la fila (100/70/50%).
- **Lumbrero** (6): pulso de curación a todos los aliados cercanos, de cualquier fila.
- **Verdugo del Tajo Negro** (6): levanta el hacha y barre; hay que tumbarlo antes o ponerle un señuelo delante.
- **Campana** (6): repique que aturde e interrumpe a las criaturas cercanas.



## Progreso permanente

El árbol se paga con **Esencia**, que se conserva entre partidas (`user://meta.json`, junto con los rangos comprados). Se gana al superar cada oleada (10 + 5×n) y +60 por victoria (`data/balance.json` → `meta`). Se compra entre oleadas y en las pantallas de victoria o derrota. Las almas quedan solo para Sabuesos, Ojos y niveles de bestia. Árbol completo: 6635 de Esencia.

## Bestias nuevas y elección tras cada oleada

Tras cada oleada superada se ofrecen **3 opciones al azar** (pool ponderado en `data/balance.json` → `draft.pool`): bestias nuevas gratis (Alacrán de la Fosa, Sapo de Brea, Manta del Umbral, Sabueso) o recompensas (almas, reparar la Puerta, esencia). Hay que elegir una antes de iniciar la siguiente oleada. Para añadir un pack nuevo: entrada de la bestia en `balance.json` (con `spot`: front/rear), su `_ai_*` en `sim.gd`, sprite en `art/sprites/` y una línea en el pool.

- **Alacrán** (vanguardia): tanque; agarra a un invasor 3 s y le hace 28 de daño.
- **Sapo de Brea** (retaguardia): escupe brea sobre el grupo más denso; daña y ralentiza a la mitad mientras pisan el charco.
- **Manta del Umbral** (retaguardia): elige el carril con más enemigos, lo cruza en vuelo (intocable) golpeando y aturdiendo a todos, y vuelve.

Arte: `art/LEEME_bestias.md` (diseños elegidos y alternativas en `art/alternativas/`).

## Equilibrio (bot torpe)

`tests/bot.gd` juega como una persona en su primera partida: reacciona tarde (decide cada ~0,45 s y lanza 0,3 s después sobre la posición vieja), apunta con error (~38 px), se adelanta a medias, se distrae un 18% de las veces, tarda en cambiar de hechizo y elige en el draft con preferencias medianas.
Informe: `godot --headless --path . res://tools/balance.tscn -- 120 10 8` (primera partida, bot hábil de referencia y carreras acumulando esencia; `BAL_ESS=0,80,150` mide con árboles fijos).

| Medida | Antes | Después |
| --- | --- | --- |
| Primera partida, bot torpe | 80% (Verdugo 65%, Inquisidor 95%) | 55% (Verdugo 48%, Inquisidor 64%), 120 partidas; 58% tras el pack 2 |
| Primera partida, bot hábil | 100% | 100% |
| Árbol de 80 / 150 / 300 de esencia | 100% | 85% / 98% / 100% |

Las derrotas se concentran en la oleada 6 y algunas en la 4; nadie pierde en las tres primeras.

## Segundo asedio, Ira y bestias del pack 2

**Asedios** (`data/waves.json` → `sieges`): el *Primer asedio* (6 oleadas) y el *Segundo asedio: la Orden del Alba* (8 oleadas), que se abre al ganar el primero. Se eligen en el menú (Jugar).
Enemigos del Alba (`data/balance.json` → `enemies`):
- **Zapador**: no se para ante las bestias; corre a la Puerta y revienta (20). Hay que matarlo con hechizos o al paso.
- **Paladín del Alba**: acorazado y no arde.
- **Sacerdotisa de la Luz**: cada 6 s da un escudo de 35 a quien tenga cerca.
- **Ariete Bendito**: 900 de vida, imparable (no se deja agarrar, aturdir ni arrastrar) y no se para; 30 a la Puerta por golpe.
- **El Gran Maestre** (jefe, oleada 8): 2400 de vida; cada 9 s marca el carril con más bestias y, tras 1,5 s de aviso, lo **juzga** (40 a cada bestia de ese carril); al bajar del 75/50/25% llama a su escolta.

**Ira** (0-5): al ganar un asedio se abre el siguiente nivel de Ira en él. Cada nivel: enemigos +30% de vida, +15% de daño, y +30% de esencia (`balance.json` → `wrath`).

**Bestias del pack 2** (en el draft, dibujadas por código en `scripts/art.gd`):
- **Gárgola de Ceniza** (vanguardia): herida por debajo del 35%, se vuelve piedra 2,5 s (inmune); al romperse cura un 10% y suelta una onda de 20 + la mitad del daño encajado.
- **Enjambre Ígneo** (retaguardia): cada 5,5 s quema a los dos enemigos más enteros a su alcance; con el Ojo, el combo de llamas funciona también sin Horno.
- **Ánima del Garfio** (vanguardia): cada 7 s engancha a un apoyo o tirador lejano (carril propio o vecinos), lo arrastra a su carril y lo aturde 1 s.

Equilibrio tras el contenido nuevo (bot torpe): primer asedio 58% en la primera partida (160 partidas); segundo asedio 0% sin árbol, 28% con 300 de esencia, 90% con 600. Ira 3 en el primer asedio: 47% con 600 de esencia, 93% con 1500; Ira 5: 40% con 1500, 100% con 3000.

## Versión web

`export_presets.cfg` trae el preset **Web** (sin hilos, para GitHub Pages; incluye `data/*.json` y excluye `tests/`, `tools/` y `art/alternativas/`). Hacen falta las plantillas de exportación de Godot 4.7.2 (basta con `web_nothreads_release.zip` y `web_nothreads_debug.zip`).

```powershell
godot --headless --path . --export-release "Web" build/web/index.html
```

`tools/publish_web.sh` exporta y publica `build/web` en la rama `gh-pages`.
