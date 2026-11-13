# Pokédex Glazed

**Demo online:** <https://machinemindcore.github.io/pokedex-glazed/>

Catálogo web (HTML + CSS + JS, sin dependencias) con las **412 entradas** de la Pokédex de *Pokémon Glazed* (#000 a #411), sus **sprites de 64×64**, tipos y ubicaciones.

## Cómo abrirlo

**Opción rápida:** doble clic en `index.html`.

**Opción recomendada (servidor local):**

```powershell
powershell -ExecutionPolicy Bypass -File .\serve.ps1
```

Luego abre <http://localhost:8137/>. Puedes cambiar el puerto con `-Port 8138`.

El servidor es un script de PowerShell sin dependencias que sirve esta carpeta. Por defecto escucha solo en `127.0.0.1`; para verlo desde otro dispositivo de la red usa `-Bind 0.0.0.0` (y abre el puerto en el firewall).

## Qué incluye

- **412 tarjetas** con sprite, número, nombre, tipos y primera ubicación.
- **Buscador** por nombre, número (`#006`, `6`), tipo o lugar.
- **Filtro por tipo** multiselección (Fuego, Agua, Hada, ???…).
- **Orden**: nº de Pokédex, nombre A–Z / Z–A, más ubicaciones.
- **Ficha de detalle** con sprite a 4×, todos los lugares, evolución/cría y descarga del sprite.
- **Planificador con pool general y varios equipos**:
  - El **+** de cada tarjeta (o el de la ficha) guarda al Pokémon en el **pool general**, sin límite.
  - Cada Pokémon del pool tiene un **+** para sumarlo al **equipo activo** (máximo 6) y una **×** para sacarlo del pool y de todos los equipos.
  - Botón **+** junto a las pestañas para crear equipos. Cada pestaña se puede **renombrar** (doble clic), **duplicar** o **vaciar**.
  - Las etiquetas del pool (`1`, `2`, `3`…) indican en qué equipos está cada Pokémon.
  - Arrastra las miniaturas para cambiar el orden dentro del equipo.
  - Todo se guarda en `localStorage`; **Enlace** comparte el pool, los equipos, sus nombres y el equipo activo.
  - Análisis en vivo del equipo activo: **cobertura ofensiva** (tipos a los que golpea súper eficazmente con STAB, de 18, y cuáles faltan), **debilidades del equipo** (tipos que golpean a varios miembros) y **tipos repetidos**.
- **Pestaña Mapa**: world map de Glazed a 1920×1280 (8× pixel-perfect) con una cuadrícula interactiva de **30×20 casillas**. Al seleccionar una casilla muestra la zona, su región, los Pokémon registrados en ella y un botón para filtrar la Pokédex.
- **Enlaces directos** a una ficha: `index.html?p=006` o `?p=charizard`. El mapa tiene su propio enlace: `#mapa`.
- Atajos: `/` enfoca el buscador, `←`/`→` navegan entre fichas, `Esc` cierra.

## Imágenes de equipos

Los tres equipos están exportados como tarjetas independientes:

- `equipos/equipo-1.png`
- `equipos/equipo-2.png`
- `equipos/equipo-3.png`

Cada una mide **2400×1400 px** e incluye los sprites, tipos, cobertura ofensiva, debilidades y tipos repetidos del equipo. `equipos/index.html` es una galería para verlas juntas.

Para regenerarlas, edita `scripts/teams.json` con los equipos que quieras y ejecuta:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-cards.ps1
```

El script usa `team-card.html` y Microsoft Edge en modo headless para renderizar y recortar las imágenes.

## Corregir las zonas del mapa

Las etiquetas del mapa son aproximadas. Para revisarlas:

1. Abre `mapa/cuadricula.png`: es el mapa con una cuadrícula de ajedrez de **30×20**, con las **filas en letras (A–T)**, las **columnas en números (1–30)** y la etiqueta de cada casilla (`A1`, `B7`…) escrita dentro.
2. Edita `mapa/localizaciones.csv` (600 filas). La columna `zona_actual` muestra lo que enseña ahora la app; escribe el nombre real en `zona_correcta`. Si una casilla ya es correcta, deja `zona_correcta` vacía.
3. En el CSV, `fila` es la letra (A–T) y `columna` el número (1–30), igual que en la imagen.
4. Cuando esté completo, se puede regenerar el mapa usando esa columna.

También tienes `mapa/LEEME.txt` con el resumen.

## Estructura

```
index.html              ← la Pokédex (todo el catálogo va incluido)
sprites/000.png … 411.png
mapa/world-map.png      ← world map 1920×1280 (8× pixel-perfect)
mapa/cuadricula.png     ← referencia 30×20 con filas A–T y columnas 1–30
mapa/localizaciones.csv ← plantilla para corregir las zonas
equipos/                ← las tres tarjetas PNG + galería
serve.ps1               ← servidor local opcional
team-card.html          ← plantilla de las tarjetas de equipo
template.html           ← plantilla usada para regenerar index.html
scripts/
  parse.ps1             ← descarga y parsea la tabla de la wiki
  build-sprites.ps1     ← recorta/descarga los 412 sprites
  build-html.ps1        ← inyecta los datos en la plantilla
  build-cards.ps1       ← genera las imágenes de los equipos
  build-map-reference.ps1 ← genera cuadricula.png y localizaciones.csv
  teams.json            ← equipos usados para las imágenes
  dex.json              ← datos intermedios
  cache/                ← respuestas descargadas (wiki, CSS y sábana de sprites)
```

## Regenerar

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\parse.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\build-sprites.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\build-html.ps1
```

`parse.ps1` vuelve a descargar la lista de la wiki y `build-sprites.ps1` la sábana de sprites si no están en `scripts/cache/`.

## Fuentes y créditos

- **Datos de ubicación**: [Pokemon Locations and Availability – Fanmade Pokémon Glazed Wiki](https://fanmadepokemonglazed.fandom.com/wiki/Pokemon_Locations_and_Availability). La lista original tiene 134 entradas sin ubicación; aquí se muestran como «Sin datos».
- **Sprites**: [DS-style 64×64 Pokémon Sprite Resource](https://www.pokecommunity.com/showthread.php?t=267728), obtenidos de la sábana del [TPP Global Pokédex (dex Tunod)](http://thatswhatyouget.github.io/tpp-progress/pokedex.html?dex=Tunod). Incluye las formas propias de Glazed (Scarfed Pikachu, Kyurem-B/W, Enraged Mew, megas…).
- **World map**: [Pokemon Glazed World Map](https://www.deviantart.com/redriders180/art/Pokemon-Glazed-World-Map-347516294) de redriders180, escalado 8× con vecino más cercano. Las etiquetas de zona del mapa interactivo son aproximadas.

No se han extraído gráficos del ROM: la wiki no aloja sprites y este es el set abierto que mejor reproduce el estilo del juego.

Proyecto de fans, sin ánimo de lucro. Pokémon © Nintendo · Creatures · GAME FREAK.
