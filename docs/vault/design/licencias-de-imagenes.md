# Licencias de las imágenes de la home

- **Fecha:** 2026-09-08
- **Qué es:** la única fuente de verdad sobre de dónde salió cada foto de la
  vidriera y qué obliga cada una.
- **Cómo se llenó:** del campo `extmetadata` de la API de Commons, que es el
  mismo que muestra la página del archivo. No es una lectura a ojo ni una
  suposición: sale de `apps/tienda/public/landing/_assets.json`, que genera
  `scripts/assets/traer_landing.py`.
- **A propósito, este archivo no lo enlaza nadie y no enlaza a nadie.** Es una
  hoja suelta para que el dueño resuelva las licencias por su cuenta.

---

## 1. Lo que hay que hacer, corto

**Cuatro de las cinco fotos obligan a acreditar, y tres además son
ShareAlike.** Y la que más le gustó al dueño —la mesa del cierre— es
justamente la única sin procedencia conocida.

| Hay que | Cuáles |
|---|---|
| **Acreditar autor + licencia + enlace, en una página que vea el público** | `ambiente`, `rack`, `botella`, `cava` |
| **Además, ShareAlike sobre el `.webp` derivado** | `ambiente`, `botella`, `cava` |
| **Averiguar de dónde salió, o reemplazarla** | `mesa-h.webp`, `mesa-v.webp` |
| Nada | ninguna: no quedó ningún CC0 en uso |

---

## 2. Las cinco fotos

### `ambiente.webp` — fondo lejano de las escenas 1 y 2

| | |
|---|---|
| **Original** | `File:Pol Roger pupitre 3.jpg` |
| **Página** | `https://commons.wikimedia.org/wiki/File:Pol_Roger_pupitre_3.jpg` |
| **Autor** | Tomas er |
| **Licencia** | **CC BY-SA 3.0** — `https://creativecommons.org/licenses/by-sa/3.0` |
| **Obliga** | atribución **+ ShareAlike** |
| **Derivado** | recorte al 78 % de la ventana máxima, foco (0,32 / 0,46), WebP q=55 |

Un muro de culos de botella en su pupitre. El foco está corrido a la izquierda
a propósito: el borde derecho del original tiene una pared gris fría que
peleaba con la paleta cálida.

### `rack-v.webp` · `rack-h.webp` — escenario de la escena 1

| | |
|---|---|
| **Original** | `File:Wine Cellar at Chateau Kirwan.jpg` |
| **Página** | `https://commons.wikimedia.org/wiki/File:Wine_Cellar_at_Chateau_Kirwan.jpg` |
| **Autor** | Jon |
| **Licencia** | **CC BY 2.0** — `https://creativecommons.org/licenses/by/2.0` |
| **Obliga** | atribución (sin ShareAlike) |
| **Derivado** | dos recortes, foco (0,50 / 0,52) y (0,50 / 0,54), WebP q=66 |

Túnel de barricas axial con el punto de fuga centrado. Es la foto de la tanda
que más se parece a *"una cava iluminada"* en vez de *"una tienda oscura"*.

### `botella.webp` — sujeto de la escena 1

| | |
|---|---|
| **Original** | `File:Riddling racks, Veuve Clicquot cellars.jpg` |
| **Página** | `https://commons.wikimedia.org/wiki/File:Riddling_racks,_Veuve_Clicquot_cellars.jpg` |
| **Autor** | Cynwolfe |
| **Licencia** | **CC BY-SA 4.0** — `https://creativecommons.org/licenses/by-sa/4.0` |
| **Obliga** | atribución **+ ShareAlike** |
| **Derivado** | recorte al 45 %, foco (0,35 / 0,32), WebP q=84 |

Culos de botella contra pared de creta iluminada. El foco salió de un **barrido
medido de 25 centros de recorte**: el que estaba puesto a ojo daba un p95 de
0,113 y éste da 0,533 — cuatro veces y media más luz, sobre el único plano que
la dirección quiere iluminado.

### `cava-v.webp` · `cava-h.webp` — escenario de la escena 3

| | |
|---|---|
| **Original** | `File:Wine cellar of Mrva & Stanko Winery, Trnava, Slovakia - 20140723-02.jpg` |
| **Página** | `https://commons.wikimedia.org/wiki/File:Wine_cellar_of_Mrva_%26_Stanko_Winery,_Trnava,_Slovakia_-_20140723-02.jpg` |
| **Autor** | Smuconlaw |
| **Licencia** | **CC BY-SA 3.0** — `https://creativecommons.org/licenses/by-sa/3.0` |
| **Obliga** | atribución **+ ShareAlike** |
| **Derivado** | dos recortes, foco (0,42 / 0,50) y (0,46 / 0,52), WebP q=66 |

Toneles de roble de frente. En la página se sirve apagada al 68 % con un token
de escena, porque es la única escena sin sujeto y su escenario llegaba
demasiado claro detrás del texto.

### ⚠️ `mesa-h.webp` · `mesa-v.webp` — escenario de la escena 4

| | |
|---|---|
| **Original** | **DESCONOCIDO** |
| **Autor** | **DESCONOCIDO** |
| **Licencia** | **DESCONOCIDA** |
| **Obliga** | no se puede saber, y por eso **bloquea publicar** |

Una mesa tendida con una vela encendida, copas de vino, vaso bajo, servilleta y
cubiertos. Entró al repo en `v0.7.0` (`395214b`) sin tabla de licencias, junto
con los otros siete assets de esa tanda.

**Se quedó por decisión explícita del dueño**, mirando: el reemplazo que traje
de Commons —`File:Table of wine and snacks (Unsplash).jpg`, CC0, de Joel
Aguilar— se descartó porque *"parece una comida con un vaso de cerveza
negra"*. Es una decisión estética correcta y el costo es este agujero.

**Qué se descartó como identificación, y por qué:** `home-parallax-d` documenta
un `mesa.webp` distinto (`File:11 Depot St, Concord, United States (Unsplash)`,
de Michael Browning, CC0). **No es ésta**: se compararon las dos lado a lado y
la de Depot St es un salón de restaurante con una mesa larga y una silueta de
persona al fondo, no una mesa tendida con vela.

Las tres salidas, por orden de costo:

1. Identificarla y anotarla acá.
2. Reemplazarla por una CC0 equivalente — mesa tendida, vela encendida, cero
   caras.
3. Producirla. Es una foto de mesa tendida: se hace con una vela y una cámara.

---

## 3. Por qué no quedó ningún CC0

Se buscó. Commons es la única fuente alcanzable desde esta máquina que devuelve
la licencia por archivo en la respuesta de la API, y su material CC0 de vino
—casi todo donado por Unsplash antes de 2017— es **lifestyle**: living
comedores, sofás, picnics, cócteles. Se midió su luminancia y varias eran las
más claras de todas, pero ninguna sobrevive a `direccion.md §10`, que prohíbe
explícitamente el club minimalista escandinavo y el e-commerce genérico.

Las cuatro que quedaron son fotos documentales de cavas reales: piedra, creta,
roble, botella. Eso es lo que pide `direccion.md §8` —*"superficies reales […]
cero superficies de estudio"*— y el precio es que sus autores pidieron crédito.

**Y el ShareAlike no es una nota al pie.** Obliga sobre el archivo derivado —el
`.webp` recortado, no el sitio entero—, así que hay que poder decir bajo qué
licencia se publican esos tres `.webp`. Si el dueño no lo quiere, se
reemplazan los tres por CC0 y se pierde algo de calidad de encuadre.

---

## 4. Dónde tiene que aparecer el crédito

Hoy **no aparece en ninguna parte de la vidriera**, y una tabla en el vault no
cumple con CC BY: la licencia pide atribución donde se ve la obra.

El pie de la home es el lugar razonable. Hoy sólo lleva la leyenda legal de
alcohol. Falta escribirlo, y no está hecho.
