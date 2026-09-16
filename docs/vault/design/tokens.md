# Tokens — el sistema, con los nombres que existen en código

> Paso 2 de `/disenio`. Los nombres de esta página son **exactamente** los de
> [`apps/tienda/src/shared/tokens/tokens.css`](../../../apps/tienda/src/shared/tokens/tokens.css):
> un token que está acá y no allá, o al revés, es un defecto. El panel en
> Flutter los espeja desde el 2026-09-16 (§7); el puente son estos nombres.
>
> Escrito el 2026-09-11, cuando el dueño eligió la maqueta **mostrador** para
> `/vinos` ([ADR 008](../architecture/decisions/008-catalogo-stock-y-carrito.md)).
> La dirección que los justifica está en [`direccion.md`](direccion.md).

## 1. Cómo se midieron los contrastes

Con la fórmula de WCAG 2.1 sobre los valores que resuelve `color-mix()`: en
`srgb` se interpola el valor codificado, en `oklab` se pasa por Oklab. No son
números copiados de la maqueta: dos de los que traía estaban mal (el borgoña
sobre papel decía ~9,4 y da **8,40**; el filete dorado sobre papel no llegaba a
3:1).

**Controles del cálculo:** negro sobre blanco da **21,00**, y dorado sobre tinta
da **8,80**, el mismo número que midió `direccion.md §2.1` por otro camino.

## 2. La marca

| Token | Valor | Uso |
|---|---|---|
| `--borgona` | `#762d2d` | El acento. Sobre papel es texto: **8,40:1** |
| `--dorado` | `#d2ae6d` | Sobre tinta es texto a tamaño de etiqueta (**8,80:1**). Sobre papel **nunca** es texto: **1,83:1** |

Salen del PNG del logo, píxel por píxel, no del PDF (`direccion.md §2.0`).

## 3. Cava — la ceremonia, oscura

| Token | Valor | Contraste sobre `--tinta` | Uso |
|---|---|---:|---|
| `--tinta` | `#1a1210` | — | El fondo |
| `--tinta-honda` | `#110b09` | — | Barras y botones sobre el fondo |
| `--marfil` | `#f5efe4` | — | Títulos |
| `--marfil-1` | marfil 94 % | **14,29** | El texto |
| `--marfil-2` | marfil 76 % | **9,59** | Los datos |
| `--marfil-3` | marfil 58 % | **6,02** | Lo accesorio. Es el piso con información |
| `--oro-filete` | dorado 85 % | — | Filetes y anillos |
| `--oro-tenue` | dorado 34 % | — | Divisiones, sin información |

## 4. Papel — la transacción, clara

`/carrito`, la mitad de abajo de la ficha y, cuando existan, el checkout y el
comprobante (`direccion.md §3`). **Todo sale de `color-mix()` sobre los colores
de la marca**: el papel no trae un solo literal nuevo.

| Token | Valor | Contraste sobre `--papel` | Uso |
|---|---|---:|---|
| `--papel` | `var(--marfil)` | — | El fondo |
| `--papel-hondo` | marfil 92 % + dorado, oklab | — | Bandas y el renglón activo |
| `--papel-ventana` | marfil 84 % + dorado, oklab | — | Detrás de la botella |
| `--tinta-1` | `var(--tinta)` | **16,13** | El texto |
| `--tinta-2` | tinta 80 % | **9,11** | Los datos |
| `--tinta-3` | tinta 64 % | **5,27** (4,81 sobre la ventana) | Lo accesorio. El piso de texto |
| `--regla` | tinta 16 % | 1,40 | Divisiones **sin información**. Nunca el único borde de un control |
| `--filete-papel` | dorado 72 % + tinta, oklab | **3,37** (3,08 sobre la ventana) | El dorado sobre papel: **sólo línea** |
| `--acento` | `var(--borgona)` | **8,40** | Lo que es texto y es acento: "Quedan pocas", el aviso, el foco |

⚠️ **`--filete-papel` iba al 80 % en la maqueta y daba 2,81:1**: por debajo del
3:1 que WCAG 1.4.11 le pide a una línea que delimita un control (el selector de
cantidad, el total). Al 72 % da 3,37 sobre papel y 3,08 sobre la ventana.

## 5. Tipografía — tres familias, y cada una tiene un solo trabajo

| Token | Familia | Trabajo |
|---|---|---|
| `--tipo-display` | Fraunces (`SOFT`, `WONK`, `opsz`) | Títulos y versalitas |
| `--tipo-texto` | Newsreader | Todo lo que se lee |
| `--tipo-cifras` | **Archivo** | **Sólo números**: precio, cantidad, total, cuentas |

Archivo es de Omnibus-Type, una fundidora de Buenos Aires: una grotesca de
verdad, que no le hace eco al decó. Va siempre con `font-variant-numeric:
tabular-nums`, para que la columna del total no baile.

⚠️ **La maqueta mostrador traía Libre Franklin, y no sirve para esto.** El
archivo que sirve Google no tiene la función `tnum`. Medido a 40 px, pidiendo
cifras tabulares:

| Familia | "1111" | "8888" | Control: proporcional |
|---|---:|---:|---|
| Libre Franklin | 74,41 | **106,89** | 74,41 / 106,89 — igual: `tnum` no hace nada |
| Archivo | 90,89 | **90,89** | 83,38 / 91,84 — distinto: la medición discrimina |

La lente cava ya lo había advertido al elegir Archivo. Lo encontró la
verificación de este documento sobre la página renderizada, antes del deploy.

Escala (fluida entre 380 y 1440 px), pesos, tracking e interlínea: `--t-kicker`
a `--t-h1`, `--peso-texto` 440, `--peso-enfasis` 520, `--peso-versalita` 600,
`--tracking-versalita`, `--tracking-rotulo`, `--interlinea-prosa` y
`--interlinea-titulo`. El porqué de los pesos (el texto claro sobre oscuro
adelgaza) está en el comentario de `tokens.css`.

## 6. Espacio, filetes y chaflanes

| Token | Valores |
|---|---|
| `--e-1` … `--e-9` | 0,25 · 0,5 · 0,75 · 1 · 1,5 · 2,25 · 3,5 · 5 · 7,5 rem |
| `--filete` · `--filete-grueso` · `--filete-marco` | 1 · 1,5 · 3 px. La jerarquía va por grosor (el isotipo modula 1,38:1) |
| `--chaflan-boton` · `--chaflan-ventana` · `--chaflan-marco` | 9 · 8 · 16 px. Si hay borde, hay chaflán (`direccion.md §6`) |

La luz (`--luz-*`), el parallax (`--amp-*`) y el movimiento (`--ease-caida`,
`--dur-*`) viven en el mismo archivo y tienen su porqué al lado.

## 7. El panel — el espejo en Flutter

Escrito el 2026-09-16, cuando el dueño eligió la **mezcla C**:

- **Los colores de la planilla:** una banda de tinta con el dorado, y
  superficies blancas sobre papel hondo.
- **La búsqueda y los renglones de la libreta.**

Lo eligió mirando el
[lienzo de las tres direcciones](https://claude.ai/artifact/1Eie7nobYEDNqQp4Ck6fv7).
El porqué está en [ADR 011 §4](../architecture/decisions/011-entrar-al-panel.md).

**El panel hereda la paleta y no la ceremonia** (`direccion.md §12`). Los
valores viven en
[`apps/admin/lib/theme/tokens.dart`](../../../apps/admin/lib/theme/tokens.dart),
que es el **único** lugar de `lib/` con literales de color. Las pantallas se los
piden a `Theme.of(context).colorScheme`, y el reparto está en
[`tema.dart`](../../../apps/admin/lib/theme/tema.dart).

Los `color-mix()` están **resueltos** con el mismo cálculo del §1. Los controles
son los de siempre: negro sobre blanco da 21,00 y dorado sobre tinta, 8,80.

| En Flutter | En la vidriera | Valor | Rol en el esquema | Contraste |
|---|---|---|---|---:|
| `Tokens.borgona` | `--borgona` | `#762D2D` | `primary`, `error` | 9,62 sobre blanco |
| `Tokens.dorado` | `--dorado` | `#D2AE6D` | `secondary` | 8,80 sobre la banda |
| `Tokens.tinta` | `--tinta` | `#1A1210` | `inverseSurface` (la banda) | — |
| `Tokens.marfil` | `--marfil` | `#F5EFE4` | `onInverseSurface` | 16,13 sobre la banda |
| — | `--marfil-2` | marfil al 76 % sobre la banda | pestañas inactivas | 9,59 |
| `Tokens.blanco` | — | `#FFFFFF` | `surface` | — |
| `Tokens.papelHondo` | `--papel-hondo` | `#F2EADB` | el fondo de las pantallas | — |
| `Tokens.papelVentana` | `--papel-ventana` | `#EFE5D1` | `surfaceContainerHighest` (avisos) | — |
| `Tokens.tinta1` | `--tinta-1` | `#1A1210` | `onSurface` | 18,45 sobre blanco |
| `Tokens.tinta2` | `--tinta-2` | `#463E3A` | las etiquetas de campo | 10,43 |
| `Tokens.tinta3` | `--tinta-3` | `#69625C` | `onSurfaceVariant`, `outline` | **6,03** sobre blanco · **5,04** sobre papel hondo |
| `Tokens.regla` | `--regla` | `#D2CCC2` | `outlineVariant` | 1,60: sin información |

- **Blanco es nuevo en el sistema, no en la marca.** La marca son dos colores
  más blanco (`direccion.md §1`), y la vidriera no lo usaba porque su papel es
  marfil.
- **`--filete-papel` (`#997E51`, 3,86 sobre blanco) no está espejado todavía.**
  Entra con los renglones del catálogo (EP-03): un token sin uso es código que
  nadie abre.
- **Tipografía:** Archivo para toda la interfaz, con `tabularFigures` en las
  cifras, y Newsreader (`estiloDeNombre`) sólo para la marca y los nombres de
  los vinos. Las dos llegan por `google_fonts`.
- **Medidas:** radio 10, superficies 12, táctil 44, botones 52. La navegación
  pasa de arriba a abajo por debajo de **840 px**.
