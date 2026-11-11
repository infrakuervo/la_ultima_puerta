# La Última Puerta: personajes y animaciones para Google Flow

Encargo para Codex o para quien genere los vídeos. Lista todo el arte animado que le falta al juego, en orden de prioridad, con un prompt listo para Google Flow en cada clip y el destino exacto en el repositorio. El juego está en GitHub: `infrakuervo/la_ultima_puerta`, rama `prototype/first-siege`.

Los prompts de Flow van en inglés porque Flow los sigue con más precisión. Las explicaciones van en español.

## Cómo funciona hoy

- El juego usa sprites fijos (`art/sprites/<clave>.png`) y, si existen, animaciones por fotogramas (`art/anim/<carpeta>/<clip>/01.png, 02.png…`). Los datos de cada clip (fps, bucle o una vez, fotograma de impacto, escala y pies) están en `data/anim.json`. Si falta un fotograma, se usa el sprite fijo, así que se puede añadir arte poco a poco sin romper nada.
- Ya hay clips del demonio (reposo, rayo, brasa, golpe, victoria y derrota), de Tizón (carrera y mordisco) y del Horno (reposo, carrera y mordisco). Las instrucciones de recorte están en `art/anim/LEEME.md`.
- Las bestias y el demonio miran a la derecha. Los humanos miran a la izquierda.
- Los efectos sobre fondo negro se dibujan con mezcla aditiva (`scripts/fx_layer.gd`, personaje `efectos` en `data/anim.json`): el negro no suma nada y no hace falta recortarlos.

## Reglas para todos los clips de personaje

1. **Fondo verde liso** (#00FF00), sin degradado, sin suelo ni sombra. El juego dibuja su propia sombra.
2. **Cámara fija.** Vista lateral un poco elevada, igual que los sprites actuales, sin movimiento, zoom ni cortes.
3. **El personaje no se desplaza.** Corre, camina o ataca en el sitio, centrado y de cuerpo entero, con margen alrededor. Nada debe salirse del cuadro.
4. **Mismo encuadre en todos los clips de un personaje**, con los pies a la misma altura. Sube el sprite fijo de ese personaje como imagen de referencia o primer fotograma en cada clip, para que no cambie de aspecto.
5. **Estilo del juego:** low poly facetado, colores oscuros, grietas de lava naranja en las criaturas del Infierno y armaduras de marfil, oro o tela gastada en los humanos. Las referencias de estilo son los PNG de `art/sprites/` y `art/fondo-fosa.jpg`.
6. **Duración:** entre 4 y 8 segundos. Los bucles deben empezar y acabar en la misma postura.
7. Sin texto, sin marcos y sin partículas que se salgan del personaje.

## Reglas para los efectos

- **Fondo negro puro**, sin suelo ni personajes, con el efecto centrado y la cámara fija.
- De 0,5 a 2 segundos de efecto útil. Puede sobrar vídeo al final; se recorta.

## Bloque base para los prompts

Empieza cada prompt de personaje con este bloque (FACING es right para bestias y demonio, left para humanos):

```
Stylized low-poly 3D game character, faceted surfaces, side view slightly from above, facing FACING, full body centered with empty margin around it, animating in place without moving across the frame, locked-off static camera, no camera movement, no zoom, no cuts, solid flat pure green #00FF00 background, even lighting, no ground, no shadow, no text.
```

Y cada prompt de efecto con este:

```
Game visual effect on a pure black background, centered, locked-off static camera, no ground, no characters, no text.
```

## Procesado y entrega

Para cada clip:

1. Recortar el verde con ffmpeg (chromakey y despill). Pasar a 12 fps y exportar PNG con alfa, unos 240 px de alto. Los efectos no se recortan.
2. Guardar en `art/anim/<carpeta>/<clip>/01.png, 02.png…`. Usa las carpetas indicadas abajo.
3. Añadir su entrada en `data/anim.json` y medir los pies y la escala frente al sprite fijo con capturas (`tools/shots.tscn`, ver `art/anim/LEEME.md`).
4. Para los personajes que aún no tienen sprite fijo, guardar primero una imagen fija en `art/sprites/<clave>.png` (puede ser un fotograma limpio del clip de reposo). Después, quitar en `data/balance.json` el `sprite`/`tint` prestado de ese enemigo.

Nota para el código: hoy solo las bestias y el demonio reproducen fotogramas. Los humanos usan poses por código. Para animar enemigos con fotogramas hay que extender `scripts/poses.gd` a ellos, con `Anim.new(<clave>)`, como ya se hace con las bestias.

---

## Prioridad 1: efectos (fondo negro)

Hechos e integrados: explosión de la Brasa, impacto del Rayo, llamas, bola de fuego (se usa como proyectil de la Brasa), santuario y Juicio.

Ya tienen su sitio en el juego y son lo que más se nota.

### Explosión de la Brasa

- Carpeta: `art/anim/efectos/brasa/`. Una vez, 1 a 1,5 s. Ya está en `data/anim.json`.
- Prompt: `[bloque de efecto] A fireball impact explosion seen slightly from above: a bright orange-white flash, an expanding ring of fire on the ground, flying embers and a short puff of dark smoke, then it fades out completely.`

### Impacto del Rayo

- Carpeta: `art/anim/efectos/rayo/`. Una vez, 0,5 a 0,8 s. Ya está en `data/anim.json`.
- Prompt: `[bloque de efecto] A crackling blue-white lightning strike hitting a point: a sharp electric flash, small branching arcs and cyan sparks bursting outwards, then it fades out completely.`

### Llamas de suelo (bucle)

- Carpeta: `art/anim/efectos/llamas/`. Bucle de unos 2 s, para el suelo ardiendo del Horno y de la Fisura de lava.
- Prompt: `[bloque de efecto] A wide low strip of burning flames on the ground, seen from the side, flickering steadily, seamless loop.`

### Chispazo en la mano del demonio (bucle)

- Carpeta: `art/anim/efectos/mano/`. Bucle de 1 a 2 s.
- Prompt: `[bloque de efecto] A small floating ball of fire with crackling orange sparks, hovering in place, seamless loop.`

### Luz del santuario (bucle)

- Carpeta: `art/anim/efectos/santuario/`. Bucle de unos 3 s. El santuario del tercer asedio hoy se dibuja con código.
- Prompt: `[bloque de efecto] A circular holy sigil of golden light on the ground seen from slightly above, slowly rotating runes and a soft column of golden light rising from it, seamless loop.`

### Juicio del Gran Maestre

- Carpeta: `art/anim/efectos/juicio/`. Una vez, de 1 a 1,5 s. Es un rayo de luz que barre un carril entero.
- Prompt: `[bloque de efecto] A long horizontal beam of blinding holy white-gold light that flares up, holds for a moment and fades, filling a wide horizontal strip across the frame.`

---

## Prioridad 2: clips que faltan de personajes ya animados

### Tizón: reposo

- Carpeta: `art/anim/tizon/reposo/`. Bucle de 3 a 4 s. Mismo encuadre que `carrera` y `mordisco` (427 × 240).
- Referencia: `art/sprites/sabueso.png` y un fotograma de `art/anim/tizon/carrera/`.
- Prompt: `[bloque base, facing right] A lean skeletal hellhound made of dark slag and rust-red plates with glowing lava cracks between its ribs and a burning open jaw. It stands still, breathing slowly, its tail swaying, small embers drifting from its back. Seamless loop.`

### Horno de Fosas: embestida (repetir en verde)

- Carpeta: `art/anim/horno/embestida/`. Una vez, de 1,5 a 2 s. Mismo encuadre que sus otros clips (400 × 248). El intento anterior salió con fondo magenta y no se pudo recortar.
- Prompt: `[bloque base, facing right] A huge hunched furnace beast of dark basalt with a glowing ribcage full of fire and a wide burning maw. It lowers its head and lunges forward with a powerful charge, then returns to its starting pose.`

### Horno de Fosas: inhalar

- Carpeta: `art/anim/horno/inhalar/`. Una vez, de 1 a 1,5 s. Encaja con su aviso INHALA.
- Prompt: `[bloque base, facing right] The same furnace beast opens its maw wide and sucks air in, its ribcage glowing brighter and its body swelling slightly, ready to spit fire.`

---

## Prioridad 3: bestias con sprite fijo y sin animación

Para cada una, sube su PNG de `art/sprites/` como referencia. Miran a la derecha.

### Sabueso del Trueno (`trueno.png`, carpeta `art/anim/trueno/`)

- `reposo` (bucle, 3 s): `[bloque base, facing right] A tall spiky hellhound with copper horns, cyan electric accents and a small bell on its back, standing alert, breathing, tiny sparks crackling along its horns. Seamless loop.`
- `agacharse` (una vez, 1 s): `[...] The same hound crouches low, coiling its legs and charging electricity before a jump.`
- `salto` (una vez, 1 s, saltando en el sitio): `[...] The hound leaps straight up in place and lands with a burst of cyan sparks.`

### Ojo de Latón (`ojo.png`, carpeta `art/anim/ojo/`)

- `reposo` (bucle, 3 s): `[bloque base, facing right] A floating brass eye construct with a cyan iris and dangling brass tendrils, hovering and bobbing gently, its iris looking around. Seamless loop.`
- `disparo` (una vez, 1 s): `[...] The brass eye narrows, glows and fires a short golden beam to the right, then relaxes.`

### Alacrán de la Fosa (`alacran.png`, carpeta `art/anim/alacran/`)

- `reposo` (bucle, 3 s): `[bloque base, facing right] A heavy armored scorpion of black chitin with lava-orange joints and big claws, idling, tail swaying, claws opening and closing. Seamless loop.`
- `pinza` (una vez, 1,5 s): `[...] The scorpion lunges its claw forward, snaps it shut on something and holds it.`

### Sapo de Brea (`sapo.png`, carpeta `art/anim/sapo/`)

- `reposo` (bucle, 3 s): `[bloque base, facing right] A squat toad made of dark tar and rock with a glowing orange throat sac, breathing, throat pulsing. Seamless loop.`
- `escupitajo` (una vez, 1,5 s): `[...] The toad inflates its throat and spits a blob of black tar in an arc to the right.`

### Manta del Umbral (`manta.png`, carpeta `art/anim/manta/`)

- `planeo` (bucle, 3 s): `[bloque base, facing right] A flying manta ray creature of dark violet membrane with glowing edges, gliding in place with slow wing waves. Seamless loop.`
- `picado` (una vez, 1,5 s): `[...] The manta folds its wings and dives down sharply, then spreads them again.`

---

## Prioridad 4: bestias del pack 2 (hoy son siluetas por código)

Necesitan primero un **sprite fijo** (`art/sprites/<clave>.png`, transparente, mirando a la derecha, el mismo estilo que `sabueso.png`) y después los clips. Las descripciones salen de su papel en el juego.

### Gárgola de Ceniza (clave `gargola`, carpeta `art/anim/gargola/`)
Tanque. Cuando la hieren se vuelve piedra y suelta en una onda el daño que encajó.

- `reposo` (bucle): `[bloque base, facing right] A hunched gargoyle of grey ash stone with folded bat wings, two short horns and a glowing ember in its chest, breathing slowly. Seamless loop.`
- `piedra` (una vez, 1,5 s): `[...] The gargoyle crouches and turns into solid pale stone, its glow dimming as cracks spread over its body.`
- `onda` (una vez, 1 s): `[...] The stone gargoyle bursts back to life, cracking its stone shell and releasing a ring of shockwave dust.`

### Enjambre Ígneo (clave `enjambre`, carpeta `art/anim/enjambre/`)
Ataca de lejos y prende fuego a los enemigos más enteros.

- `reposo` (bucle): `[bloque base, facing right] A floating swarm of small burning fire insects circling around a dark glowing core, buzzing in place. Seamless loop.`
- `ataque` (una vez, 1 s): `[...] The swarm stretches out to the right in a stream of burning insects and then gathers back around its core.`

### Ánima del Garfio (clave `garfio`, carpeta `art/anim/garfio/`)
Espectro que engancha a un apoyo lejano y lo arrastra.

- `reposo` (bucle): `[bloque base, facing right] A translucent cyan ghost with a hooded head, holding a rusty chain with a large iron hook, swaying and floating in place. Seamless loop.`
- `lanzar` (una vez, 1,5 s): `[...] The ghost throws the chain and hook far to the right, then pulls it back hard.`

---

## Prioridad 5: humanos comunes (miran a la izquierda)

Son los más numerosos en pantalla. Tienen sprite y tres variantes de aspecto (`_v01` a `_v03`). Basta con animar el sprite base; las variantes pueden reutilizarlo o hacerse después.

Bloque humano: `Stylized low-poly 3D medieval human, faceted surfaces, side view slightly from above, facing left, full body centered, animating in place, locked-off static camera, solid flat pure green #00FF00 background, even lighting, no ground, no shadow, no text.`

### Campesino (`campesino.png`, carpeta `art/anim/campesino/`)

- `caminar` (bucle, 1 a 2 s): `[bloque humano] A ragged peasant holding a burning torch and a pitchfork, walking in place with determination. Seamless loop.`
- `ataque` (una vez, 1 s): `[...] The peasant jabs the pitchfork forward and steps back.`

### Escudero (`escudero.png`, carpeta `art/anim/escudero/`)

- `caminar` (bucle): `[bloque humano] An ivory-armored squire with a tall red-cross shield and a short sword, marching in place behind the shield. Seamless loop.`
- `ataque` (una vez): `[...] The squire bashes forward with the shield and slashes with the sword.`

### Ballestero (`ballestero.png`, carpeta `art/anim/ballestero/`)

- `caminar` (bucle): `[bloque humano] A crossbowman in a green tunic and leather cap, walking in place carrying a crossbow. Seamless loop.`
- `disparo` (una vez): `[...] The crossbowman raises the crossbow, aims to the left and fires, the string snapping, then lowers it.`

### Clérigo (`clerigo.png`, carpeta `art/anim/clerigo/`)

- `caminar` (bucle): `[bloque humano] A robed cleric in white and gold holding a glowing lantern, walking in place slowly. Seamless loop.`
- `curar` (una vez): `[...] The cleric lifts the lantern high and it pulses with soft green healing light.`

---

## Prioridad 6: héroes, élites y enemigos nuevos

### Héroes (`verdugo.png`, `inquisidor.png`)

- Verdugo, carpeta `art/anim/verdugo/`. `caminar`: `[bloque humano] A huge hooded executioner in black leather carrying an enormous axe, walking heavily in place. Seamless loop.` `hachazo` (una vez, 1,5 s): `[...] He raises the axe over his head and brings it down in a crushing chop.`
- Inquisidor, carpeta `art/anim/inquisidor/`. `caminar`: `[bloque humano] A tall inquisitor in pale robes with a golden mitre and a large bronze bell on a staff, walking solemnly in place. Seamless loop.` `campana` (una vez): `[...] He swings the bell and it rings with a visible golden shockwave.`

### Enemigos que hoy reutilizan otro sprite con tinte
Necesitan sprite fijo propio y, si se puede, `caminar` y su acción.

- **Zapador** (clave `zapador`): `[bloque humano] A sapper in sooty clothes running hunched forward in place, carrying a lit powder keg on his back, the fuse sparking. Seamless loop.` Acción `explosion` (una vez): `[...] The keg bursts in a bright explosion.` Mejor hacer esta acción como efecto sobre negro.
- **Paladín del Alba** (clave `paladin`): `[bloque humano] A paladin in polished golden armor with a sun emblem on a large shield, marching in place, untouched by fire. Seamless loop.`
- **Sacerdotisa de la Luz** (clave `sacerdotisa`): `[bloque humano] A priestess in white and pale blue robes raising a staff that projects a shimmering blue light shield around her. Seamless loop.`
- **Flagelante** (clave `flagelante`): `[bloque humano] A barefoot penitent in a torn red hood, whipping his own back with a flail as he runs in place frantically. Seamless loop.`
- **Purificador** (clave `purificador`): `[bloque humano] An inquisition purifier in orange robes and an iron mask, carrying a fire-shooting crossbow, walking in place. Seamless loop.` Acción `disparo`: `[...] He fires a burning bolt to the left.`
- **Ariete Bendito** (clave `ariete`, hoy dibujado con código): `[bloque humano] A covered wooden battering ram on four wheels with a gilded iron head and a white banner, rolling forward in place, wheels turning. Seamless loop.`

### Élites (tienen sprite propio `*_elite.png`; animación opcional)
Capataz de la Turba, Muro de Marfil, Tirador de Cerrojo, Lumbrero del Alba, Verdugo del Tajo Negro e Inquisidor de la Gran Campana. Mismo método que su versión común: `caminar` y su acción.

### Jefes

- **El Gran Maestre** (clave `gran_maestre`): `[bloque humano] An imposing grand master in ornate gold and white armor with a tall crested helmet and a long cape, walking slowly in place. Seamless loop.` Acción `juicio` (una vez, 1,5 s): `[...] He raises his sword to the sky and it blazes with holy light.`
- **El Gran Inquisidor** (clave `gran_inquisidor`): `[bloque humano] A towering grand inquisitor in blood-red robes and a tall red mitre, holding a burning censer, walking slowly in place. Seamless loop.` Acción `juicio`: `[...] He lifts the censer and a pillar of red-gold fire rises behind him.` Derrota (una vez): `[...] He falls to his knees and collapses.`

---

## Orden recomendado

1. Efectos de la prioridad 1, que entran en el juego sin tocar código.
2. Tizón en reposo y la embestida del Horno en verde.
3. Las cinco bestias con sprite fijo.
4. Los sprites fijos del pack 2 y después sus clips.
5. Humanos comunes, con el cambio de código para que los enemigos reproduzcan fotogramas.
6. Héroes, enemigos nuevos y jefes.
