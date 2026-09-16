## ADDED Requirements

### Requirement: Las rutas dependen de la sesión
El destino de cada navegación MUST decidirse por el estado de la sesión: sin
sesión → `/entrar`; sin permiso → `/sin-acceso`; con permiso, `/entrar` y
`/sin-acceso` → `/catalogo`. Mientras la sesión se resuelve, MUST mostrarse una
espera y MUST NOT mostrarse ninguna sección.

#### Scenario: Abrir el panel sin sesión
- **WHEN** alguien sin sesión abre `/pedidos`
- **THEN** ve la pantalla de entrada

#### Scenario: Recargar dentro de una sección
- **WHEN** un operador recarga el navegador en `/pedidos`
- **THEN** sigue en Pedidos, no vuelve a Catálogo

### Requirement: Navegación entre secciones (HU-01.5)
Con permiso, el panel MUST mostrar una navegación con **Catálogo** y
**Pedidos**, que marca la sección activa. Toda sección con ruta MUST estar en la
navegación.

#### Scenario: Ir a Pedidos
- **WHEN** el operador toca "Pedidos"
- **THEN** la URL es `/pedidos` y la navegación la marca como activa

### Requirement: Las secciones vacías lo dicen
Catálogo y Pedidos MUST decir, en palabras para alguien no técnico, que todavía
no tienen contenido y qué va a aparecer ahí. MUST NOT simular datos.

#### Scenario: Abrir Catálogo hoy
- **WHEN** el operador abre Catálogo
- **THEN** ve un texto que explica que ahí van a estar los vinos, y ningún vino inventado

### Requirement: Se usa igual en la compu y en el teléfono (HU-01.4)
Desde 840 px de ancho, la navegación MUST ir en la banda de arriba; por debajo,
en una barra abajo. MUST NOT haber scroll horizontal a 390 px. Los objetivos
táctiles MUST medir al menos 44 px.

#### Scenario: Teléfono
- **WHEN** el panel se abre a 390 px de ancho
- **THEN** la navegación está abajo y el ancho del documento no supera el de la pantalla

### Requirement: Página no encontrada
Una ruta que no existe MUST mostrar "Esa página no existe" con un enlace a
Catálogo. MUST NOT mostrar una sección como si la ruta existiera.

#### Scenario: Ruta inventada
- **WHEN** un operador abre `/ruta-que-no-existe`
- **THEN** ve "Esa página no existe"

### Requirement: El panel no se indexa
El HTML del panel MUST llevar `noindex`, y el hosting MUST responder con
`X-Robots-Tag: noindex`.

#### Scenario: Pedir el panel
- **WHEN** se pide `/` al hosting del panel
- **THEN** la respuesta trae `X-Robots-Tag: noindex` y el HTML `<meta name="robots" content="noindex">`
