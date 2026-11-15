# La Última Puerta · Pack de la Fosa

- fondo-fosa.png · Fondo panorámico 1672 × 941 para la cámara fija elevada. Puerta a la izquierda, brecha enemiga a la derecha y suelo continuo. La puerta está pintada en el fondo.
- sprites/ · 11 PNG individuales con canal alfa. Son poses estáticas. El demonio, las bestias y el Ojo miran a la derecha. Los enemigos miran a la izquierda.

## Integración en Godot

Importar los PNG como texturas 2D. Mantener el filtro lineal. Escalar el fondo al viewport de 1280 × 720 y conservar las posiciones de juego como coordenadas de suelo. Para las unidades terrestres, usar un Sprite2D y colocar el origen del personaje en los pies. Para el Ojo, usar un punto de suelo bajo el cuerpo y desplazar el sprite hacia arriba. Ajustar la escala de cada textura por unidad. Las dimensiones del PNG no determinan el alcance ni la colisión.

Los nombres de los archivos coinciden con las claves del prototipo. El fondo y los sprites se generaron con ImageGen a partir de la referencia low poly elegida.

## Direcciones de generación

- Fosa · Ruinas góticas de basalto, cámara ortográfica elevada, violeta en el fondo, lava en el borde inferior, puerta naranja y entrada enemiga abierta. Suelo despejado para apuntar con Brasa y Rayo.
- Bestias · Mandíbula común a las tres formas. Tizón es delgado, Horno es ancho con costillas incandescentes y Trueno es alto con cuernos de cobre y acentos cian.
- Defensores · Demonio de obsidiana con mano de brasa y Ojo de Latón flotante con iris cian.
- Humanos · Campesino con antorcha, escudero de marfil, ballestero, clérigo con farol, verdugo de hacha e inquisidor con campana.
