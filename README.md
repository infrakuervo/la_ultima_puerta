# La Última Puerta

Prototipo (Godot 4.7, GDScript) de «Primer asedio»: defiendes la última puerta del Infierno lanzando hechizos con el ratón (Brasa y Rayo) y criando bestias que mutan y suben de nivel.
Se juega entero con el ratón, de la oleada 1 a la victoria o la derrota, y se reinicia desde la pantalla de resultados.

## Cómo ejecutarlo

1. Instala Godot 4.7.x (estándar, no .NET).
2. Abre `project.godot` desde el gestor de proyectos y pulsa F5, o desde PowerShell:

```powershell
godot --path C:\ruta\a\la_ultima_puerta
```

Controles:
- Entre oleadas: arrastra una bestia a la retaguardia (muro de atrás, zona izquierda) o a la vanguardia (cerca de los enemigos). Clic en una bestia para seleccionarla y **Subir nivel**.
- En combate: clic en la arena lanza el hechizo activo en el cursor; mantener el botón lo repite en cuanto se recarga. Cambia de hechizo con clic derecho, rueda, teclas 1/2 o los botones de abajo. Pulsar la interfaz no lanza nada.
- Botones: **Árbol** (T), **Iniciar oleada** (Espacio), **Velocidad** x1/x2 (F), **Bestiario** (B).
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

## Estructura

- `scripts/sim.gd`: toda la lógica, sin dibujo ni sonido (tick fijo de 1/30 s).
- `scripts/main.gd`: vista, ratón y avisos. `scripts/art.gd`: siluetas provisionales. `scripts/sound_bank.gd`: sonidos procedurales.
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
| Primera partida, bot torpe | 80% (Verdugo 65%, Inquisidor 95%) | 55% (Verdugo 48%, Inquisidor 64%), 120 partidas |
| Primera partida, bot hábil | 100% | 100% |
| Árbol de 80 / 150 / 300 de esencia | 100% | 85% / 98% / 100% |

Las derrotas se concentran en la oleada 6 y algunas en la 4; nadie pierde en las tres primeras.
