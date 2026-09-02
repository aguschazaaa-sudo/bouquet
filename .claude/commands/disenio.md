---
description: Definir la dirección visual ANTES de escribir componentes — sistema de estilo, tokens y mockups navegables.
---

# /disenio — la idea visual antes del código

**Corre en el hilo principal a propósito**, no en un subagente: las skills de
canvas publican Artifacts y un subagente no puede publicarlos.

## Por qué este paso existe

En composición bottom-up, el primer componente hoja que escribís **fija la
paleta, la escala tipográfica y el espaciado del proyecto entero** — casi
siempre sin que nadie lo haya decidido. Después cada componente nuevo hereda esa
decisión accidental, y "arreglar el diseño" pasa a ser reescribir todo.

**Decidí el sistema antes del primer widget, no después del décimo.**

## El orden

### 1. Dirección, no componentes
Skill: `brand-guidelines`.

Qué vende bouquet, a quién, y qué tiene que sentir alguien que entra. Una tienda
de vinos no es un e-commerce genérico: el producto tiene origen, bodega,
varietal y añada, y **eso es la estética**, no un filtro.

Salí de acá con **adjetivos y referencias**, no con componentes.

### 2. El sistema de estilo
Skill: `theme-factory`.

Tokens concretos: paleta, escala tipográfica, escala de espaciado, radios,
sombras, densidad. **Los dos frentes comparten la dirección y no el código** —
la vidriera es Next.js y el panel es Flutter. El puente son los tokens, escritos
una vez y espejados.

⚠️ `no-hardcoded-colors.sh` bloquea `Colors.*`, `Color(0x…)` y hex fuera de
tokens en el panel. **Si este paso no produjo tokens, el hook te va a frenar en
el primer widget** — y va a tener razón.

### 3. Mockups navegables antes del código
Skill: `canvas-design`, o la skill `design` para un canvas multi-artboard.

Pantallas reales con contenido real: un vino con nombre largo, una bodega sin
foto, un carrito con un solo ítem, una orden `cancelada` que ya estaba `pagada`.
**Los estados feos son el diseño**; los mockups con datos perfectos mienten.

### 4. Recién ahí, componentes
`frontend-design` y `web-design-guidelines` para la vidriera,
`flutter-premium-ui` para el panel.

## La regla que sostiene todo esto

**No compongas con genéricos.** Un card que sirve para cualquier cosa no sirve
para vender vino. La técnica —jerarquía, ritmo tipográfico, densidad, motion con
intención— es lo que separa una pantalla que se ve profesional de una que se ve
armada con piezas de catálogo.

Y **la vidriera la usa gente que puede irse.** Es el único front del repo donde
la calidad visual es plata directa.

## Salida

1. `docs/vault/design/direccion.md` — adjetivos, referencias, qué NO es.
2. `docs/vault/design/tokens.md` — el sistema, con los nombres exactos que van
   a existir en código.
3. Los artboards, enlazados desde `direccion.md`.

**Hasta que existan 1 y 2, `tienda` y `admin-presentacion` no deberían escribir
componentes visuales nuevos.**
