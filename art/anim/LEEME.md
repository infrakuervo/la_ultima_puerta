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

## Pendiente
- Peso: unos 41 MB en total (demonio y Tizón ya reducidos a 240 px de alto). Para la versión web quizá convenga bajar a 8 fps o empaquetar en hojas de sprites.
- Embestida del Horno: repetir con fondo verde (el clip magenta no se puede recortar).
- Efectos sobre negro (explosión de Brasa, impacto de Rayo): aún no hechos.
- Tizón: falta el reposo.
