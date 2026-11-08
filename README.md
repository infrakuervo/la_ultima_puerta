# La Última Puerta

Prototipo (Godot 4.4, GDScript) de «Primer asedio»: defiendes la última puerta del Infierno con un demonio (la Garra) y bestias que mutan.
Se juega entero con el ratón, de la oleada 1 a la victoria o la derrota, y se reinicia desde la pantalla de resultados.

## Cómo ejecutarlo

1. Instala Godot 4.4 (estándar, no .NET).
2. Abre `project.godot` desde el gestor de proyectos y pulsa F5, o desde PowerShell:

```powershell
godot --path C:\ruta\a\la_ultima_puerta
```

Controles: arrastra una bestia a una casilla (o clic en la bestia y clic en la casilla) entre oleadas.
Botones: **Iniciar oleada** (Espacio), **Velocidad** x1/x2 (F), **Bestiario** (B).
Pantalla 1280x720 con GL Compatibility.

## Pruebas automáticas

```powershell
godot --headless --path C:\ruta\a\la_ultima_puerta --script res://tests/run_tests.gd
```

Sale con 0 si todo pasa. También se puede abrir y ejecutar `tests/run_scene.tscn` desde el editor (la salida va al registro del juego). Comprueba: datos, combate de la oleada 1, Presa, Garra de Guardia, vuelta de Tizón con cicatriz, flujo de ruta y reliquia (ambas rutas), Horno, Trueno y su hueco, Ojo (combo y marca), préstamo del Ojo, economía, partidas completas automáticas de las dos rutas (Puerta invulnerable) y un recorrido por la interfaz con el ratón. Al final imprime un informe de equilibrio (5 semillas por ruta).

## Estructura

- `scripts/sim.gd`: toda la lógica, sin dibujo ni sonido (tick fijo de 1/30 s).
- `scripts/main.gd`: vista, ratón y avisos. `scripts/art.gd`: siluetas provisionales. `scripts/sound_bank.gd`: sonidos procedurales.
- `data/balance.json`: costes, vidas, daños, tiempos, casillas. `data/waves.json`: oleadas, rutas y textos. Todo se edita sin tocar código.
- `user://bestiario.json`: bestiario sencillo (formas vistas y registro de Tizón).

## Qué hay (orden de URI-111)

1. Partida base: Puerta, Garra automática, Tizón con Presa, campesinos, previsión por carril, colocación libre, x1/x2, reinicio.
2. Seis oleadas, elección de ruta tras la 4, héroe y reliquia en la 5, pantallas de victoria y derrota.
3. Mutaciones: Horno de Fosas (Verdugo) y Sabueso del Trueno (Inquisidor), Ojo de Latón con combos visibles y préstamo en la oleada 6.
4. Economía (reclutar, Ojo, Garra de Guardia) y vínculo (Tizón conserva el nombre, vuelve gratis con cicatriz, bestiario).
5. Legibilidad: tres siluetas, aviso y sonido propios por forma (PRESA, INHALA, SALTA/HUECO, CAMPANA, MARCA, COMBO) y animación de mutación en pantalla.

Fuera de alcance a propósito: Árbol del Abismo y Ceniza, Caballero del Alba, repeticiones, arte final.

## Números clave (primera pasada, en `data/balance.json`)

Almas iniciales 40; bonus por oleada 8; Sabueso 40, Ojo 60, Garra de Guardia 55. Puerta 180; Garra 26 de daño.
Horno: inhala hasta 4 enemigos (alcance 300, enfriamiento 7 s), escupe 20 y quema 6/s durante 4 s.
Trueno: salto cada 8 s (alcance 760), 40 al caer y descargas 20/15/10, vuelve a los 6 s.
Ojo: 12 de daño, y sobre enemigos en llamas encadena a 3 más.

## Situaciones para probar a mano

- **La colocación mejora la partida:** en la oleada 4, el Horno en el carril 1 delante de los escuderos los agrupa y la llamarada cubre a los cuatro. Con el Ojo detrás en ese mismo carril, el combo de llamas encadena. Si pones al Horno en un carril vacío no inhala nada.
- **El salto del Trueno deja pasar a un enemigo:** con un clérigo en el carril 2 y escuderos en el 1, el Trueno salta al clérigo y el carril 1 queda sin bloqueo (aparece HUECO). Los escuderos avanzan hasta que vuelve.

## Estado de verificación

Ver la descripción del PR: qué se ha ejecutado y qué no.
