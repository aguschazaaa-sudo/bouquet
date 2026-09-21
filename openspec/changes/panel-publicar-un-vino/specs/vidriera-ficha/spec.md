## ADDED Requirements

### Requirement: La ficha del vino muestra la descripción
La página de un vino MUST mostrar su `descripcion` cuando la tenga. El texto lo
escribe el dueño, así que la vidriera MUST renderizarlo como texto plano —
nunca como HTML— y MUST respetar los saltos de línea que el dueño puso.

Cuando no hay descripción, la sección MUST desaparecer entera: ni un título
solo, ni un texto de relleno. Un vino sin descripción se ve completo, igual que
uno sin foto.

El listado MUST NOT mostrar la descripción: es la página del vino la que la
lleva.

⚠️ **Medido el 2026-09-21, y es distinto de "no viaja":** el listado no la
dibuja —cero títulos, ningún `<p>` con el texto— pero la descripción **sí va
en el payload serializado** de `/vinos`, porque el catálogo entero llega al
navegador para filtrarse en memoria (ADR 006). Eso es lo que acota el tope de
600 de `catalogo-producto`, y por eso el tope vive en las reglas. Si algún día
pesa, la salida es proyectar una forma más liviana para el listado, no bajar
el tope.

#### Scenario: Un vino con descripción
- **WHEN** un comprador abre la ficha de un vino que tiene descripción
- **THEN** la lee, con sus saltos de línea

#### Scenario: Un vino sin descripción
- **WHEN** un comprador abre la ficha de un vino sin descripción
- **THEN** no hay título vacío ni hueco: la sección no está

#### Scenario: Una descripción con marcas
- **WHEN** la descripción trae `<b>` o `<script>`
- **THEN** se ven como texto, sin interpretarse

#### Scenario: El listado
- **WHEN** un comprador mira el listado de vinos
- **THEN** ninguna tarjeta dibuja la descripción ni su título
