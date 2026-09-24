# EP-04 — Fotos

> Hito 1 · Workflow A · [volver al mapa](overview.md)

**Objetivo:** que una foto sacada con el teléfono o bajada a la compu llegue a
la vidriera con la misma forma que las del seed, y que un fallo al subirla se
vea.

**Fuera de alcance:** las fotos de la landing, que son assets del repo con su
propio problema de licencias.

Las cuatro reglas de subida están en
[ARQUITECTURA §5.4](../../../../ARQUITECTURA.md#54-fotos-de-producto-la-regla-de-la-extensión),
y cada una tiene su bug detrás.

---

## HU-04.1 — Subir las fotos de un vino

**Como** operador, **quiero** subir fotos de un vino desde la compu o desde el
teléfono, **para** que se vea en la tienda.

- **Ya decidido:**
  - La extensión sale del `mimeType`, **nunca** del path: en web, `XFile.path`
    es un blob URL con una barra adentro, y la barra rompe la regla de
    Storage.
  - Ruta `productos/{productoId}/{uuid}.{ext}`, **un solo segmento**.
  - El `contentType` es el real, no `image/jpeg` fijo.
  - Hasta 10 imágenes por producto (reglas).
- ⚠️ **Falta una pieza.** La vidriera sirve la foto **ya recortada en WebP** y
  no usa `next/image`
  ([ADR 008](../../architecture/decisions/008-catalogo-stock-y-carrito.md)). Hoy
  eso lo hace el seed con `sharp`. Una foto subida desde el panel llega cruda:
  un JPEG de 4 MB del teléfono, sin recortar. Hay que decidir dónde se procesa
  —en el cliente antes de subir, o en una function sobre Storage—, y esa
  decisión es un ADR.

## HU-04.2 — Elegir la foto principal y ordenarlas

> **Recortada y construida el 2026-09-24**: se elige la principal; **las demás no
> se ordenan**, porque la vidriera lee sólo `imagenes[0]`. Change
> [`panel-foto-principal`](../../../../openspec/changes/panel-foto-principal/proposal.md),
> [ADR 015 §7](../../architecture/decisions/015-fotos-del-panel.md). Ordenar el
> resto queda con disparador: el día que la ficha muestre más de una foto.

**Como** operador, **quiero** elegir cuál es la primera foto y en qué orden
van las demás, **para** que la tienda muestre la mejor.

- **Ya decidido:** `imagenes[]` es **la única ruta** a las fotos de un producto
  ([ARQUITECTURA §5.2](../../../../ARQUITECTURA.md#52-los-campos-que-tienen-trampa-y-cuál-es)).
- ⚠️ **Choca con una regla.**
  [ARQUITECTURA §5.3](../../../../ARQUITECTURA.md#53-escrituras-concurrentes-en-arrays)
  prohíbe reescribir el array entero —dos personas editando a la vez pierden
  la foto del primero—, y cambiar el orden **es** reescribirlo. La salida
  (transacción que relee, o un campo de orden aparte) se decide en los
  requerimientos.

## HU-04.3 — Quitar una foto

**Como** operador, **quiero** sacar una foto que no va más, **para** que la
tienda deje de mostrarla.

- **Ya decidido:** se saca con `arrayRemove`.
- **Abierto:** si el archivo se borra también de Storage, y cuándo. Una foto
  borrada de Storage y todavía en la página cacheada del borde da 404 hasta la
  próxima purga.

## HU-04.4 — Saber que una subida falló

**Como** operador, **quiero** ver un mensaje claro cuando una foto no se sube,
**para** no quedarme mirando un spinner que vuelve al botón.

- **Por qué existe:** en PadelPunilla la subida falló **meses** sin un solo
  reporte. Había un `try/finally` sin `catch`: la excepción se perdía como
  error async, el spinner giraba y el botón volvía. *Un fallo invisible no
  genera reportes, genera la sensación de que "no anda".*
- **Ya decidido:** `try/catch`, y el error llega a la pantalla, con qué foto
  falló.
