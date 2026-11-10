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

## Efectos de Flow (`efectos/`)
Recortados de vídeos sobre fondo negro con `ffmpeg`: tramo útil, fps, recorte por energía (la caja con el 96-97% del brillo) y un corte de niveles para dejar el fondo a cero (el negro de los vídeos no es puro y en mezcla aditiva se veía un recuadro). Datos en `data/anim.json` → `efectos`.
| Clip | Origen | Uso en el juego |
|---|---|---|
| `brasa/` | explosión, 0-1,8 s, 37 fotogramas | al caer la Brasa (`brasa_land`), escala con el radio; mezcla aditiva (`scripts/fx_layer.gd`) |
| `rayo/` | impacto, 0-1,3 s, 25 fotogramas | en el blanco del Rayo; aditiva |
| `juicio/` | rayo de luz, 0,3-2,3 s, 31 fotogramas, solo la franja central | Juicio del Gran Maestre y del Gran Inquisidor, estirado a lo largo del carril; aditiva |
| `bola/` | bola de fuego, bucle de 2 s | proyectil de la Brasa en vuelo; aditiva |
| `llamas/` | llamas, bucle de 2 s | suelo ardiendo del Horno; **en el suelo**, debajo de las unidades |
| `santuario/` | sigilo dorado, bucle de 3 s | santuario de la Inquisición; **en el suelo**, ancla en el centro del anillo (150, 181) |

`llamas` y `santuario` se guardaron con transparencia (alfa = brillo) y se dibujan en la arena con mezcla normal (`main.gd` → `_draw_ground_fx`) para que las unidades queden por delante. Los demás van en la capa aditiva, por encima. Sin fotogramas, cada uno vuelve a su dibujo por código.

## Sprites fijos nuevos (`art/sprites/`)
Zapador, Ánima del Garfio, Gárgola de Ceniza, Gran Inquisidor, Gran Maestre, Ariete Bendito, Sacerdotisa de la Luz (sobre fondo blanco) y Purificador, recortados de imágenes de Flow sobre verde (quitar verde, limpiar el borde verde, recortar y escalar a ~1,6 veces su alto en pantalla). Tamaños en `Art.SPRITE_H`. La Gárgola en piedra se dibuja con tinte gris. Fondo del Alba: `art/fondo-alba.jpg` (`waves.json` → `background` del asedio).

## Pendiente
- Peso: 41 MB en PNG, pero la versión web los importa como WebP con pérdida (`tools/anim_lossy.sh`) y el `.pck` queda en ~14 MB. No hace falta bajar fps.
- Embestida del Horno: repetir con fondo verde. El segundo intento («Furnace beast charging lunge») salió con otra criatura (un encapuchado con antorcha), no el Horno: no se usa.
- Efectos sobre negro (explosión de Brasa, impacto de Rayo): aún no hechos.
- Tizón: falta el reposo.
