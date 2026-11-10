# Animaciones por fotogramas

Sacadas de vídeos de Google Flow con fondo verde y recortadas con ffmpeg (chromakey + despill). Son PNG con transparencia a 12 fps. Dentro de cada personaje, todos los clips tienen el mismo encuadre y los pies a la misma altura, así que se puede pasar de uno a otro sin que salte.

## Demonio (`demonio/`, 367 × 240; los pies quedan abajo, hacia el centro)
| Clip | Fotogramas | Tipo | Notas |
|---|---|---|---|
| `reposo/` | 52 (4,3 s) | bucle | respira y le chisporrotea la mano |
| `rayo/` | 25 (2,1 s) | una vez | el destello sale en el fotograma 7; reproducir a ~24 fps para que vaya con el enfriamiento de 1,2 s |
| `brasa/` | 33 (2,75 s) | una vez | la bola sale de la mano en el fotograma 13; reproducir a ~18-24 fps |
| `golpe/` | 23 (1,9 s) | una vez | retrocede y se rehace (golpes a la puerta) |
| `victoria/` | 77 (6,4 s) | una vez | levanta los brazos en llamas |
| `derrota/` | 41 (3,4 s) | una vez | termina de rodillas: quedarse en el último fotograma |

El cuadro es ancho porque el rayo y la bola de fuego salen hacia la derecha; en reposo, el cuerpo ocupa el centro.

## Tizón (`tizon/`, 427 × 240, mira a la derecha)
- `carrera/`: 27 fotogramas (2,25 s), bucle de galope sin desplazarse.
- `mordisco/`: 25 fotogramas (2 s), una vez; la dentellada llega hacia el fotograma 8. Reproducir a ~18 fps.

## Horno de Fosas (`horno/`, 400 × 248)
- `reposo/`: 41 fotogramas (3,4 s), bucle.
- `carrera/`: 12 fotogramas (1 s), bucle.
- `mordisco/`: 19 fotogramas (1,6 s), una vez.

## Vídeo
- `art/video/intro_demonio.ogv`: el demonio se gira hacia la cámara delante de la puerta. 1280 × 720, Theora, sin sonido, 8 s. Para la intro o el menú (VideoStreamPlayer).

## Cómo se usan en el juego
- Datos de cada clip en `data/anim.json`: `fps`, `loop` (bucle) u `hold` (se queda en el último), `start` (primer fotograma que se reproduce), `impact` (fotograma del golpe), `hand` (píxel de la mano en el impacto), y por personaje `height` (alto en pantalla del cuadro entero) y `anchor` (píxel de los pies). Un clip puede tener su propio `height`/`anchor` (el mordisco del Horno).
- Velocidades: rayo a 24 fps desde el fotograma 5 (el destello llega a los 0,08 s), brasa a 22 fps desde el 8, golpe a 16, mordisco de Tizón a 22 desde el 3, Horno 12-18.
- Para añadir un clip: carpeta con `01.png`, `02.png`… (mismo encuadre que los otros del personaje) y su entrada en el JSON. Si el encuadre cambia, medir alto y pies frente al sprite fijo (capturas con `tools/shots.tscn` → `demonio` / `animacion`).

## Efectos sobre fondo negro (preparado, sin fotogramas aún)
- Carpeta `art/anim/efectos/<clip>/01.png…` y entrada en `data/anim.json` → `efectos` (ya están `brasa` y `rayo`). Se dibujan con mezcla aditiva (`scripts/fx_layer.gd`): el negro no suma nada, así que no hace falta recortar. `anchor [-1, -1]` = centrado en el punto del impacto; `height` = alto en pantalla (la Brasa escala con su radio).
- La Brasa lo lanza al caer (`brasa_land`) y el Rayo en el blanco (`rayo`). Si falta la carpeta no pasa nada: siguen los efectos por código.

## Pendiente
- Peso: 41 MB en PNG, pero la versión web los importa como WebP con pérdida (`tools/anim_lossy.sh`) y el `.pck` queda en ~14 MB. No hace falta bajar fps.
- Embestida del Horno: repetir con fondo verde (el clip magenta no se puede recortar).
- Efectos sobre negro (explosión de Brasa, impacto de Rayo): aún no hechos.
- Tizón: falta el reposo.
