# EP-02 — Bodegas

> Hito 1 · Workflow A · [volver al mapa](overview.md)

**Objetivo:** que cada vino tenga su bodega, escrita **una sola vez**, y que
tocar una bodega nunca saque vinos de la tienda sin avisar.

**Fuera de alcance:** la página pública de la bodega (`/bodega/<slug>`), que
es de la vidriera y todavía no existe.

---

## HU-02.1 — Dar de alta una bodega

**Como** operador, **quiero** cargar una bodega con su nombre, **para** poder
asignarle vinos.

- **Ya decidido:** la forma está cerrada en `{nombre, slug}` por las reglas: la
  vidriera lee las bodegas **enteras** en cada reconstrucción, y cada campo de
  más pesa en esa lectura. El slug sale del nombre y cumple `esSlug`
  (`firestore.rules`).
- **Por qué es una entidad y no un texto:** el mismo nombre escrito de tres
  formas rompe el filtro ([glosario](../../domain/glossary.md)).

## HU-02.2 — Que me avise si la bodega ya existe

**Como** operador, **quiero** que el panel me muestre las bodegas parecidas a
la que estoy por cargar, **para** no tener "Catena" y "Catena Zapata" como dos
bodegas.

- **Ya decidido:** la comparación usa la normalización de `contratos` —acentos,
  mayúsculas—, no una propia del panel
  ([ARQUITECTURA §7](../../../../ARQUITECTURA.md#7-búsqueda-una-sola-implementación)).
  Cero lecturas extra: las bodegas ya están en memoria.
- **Relación:** se usa también al cargar un vino, donde la bodega se **elige**
  de la lista y se puede crear ahí mismo (HU-03.2).

## HU-02.3 — Corregir el nombre de una bodega

**Como** operador, **quiero** corregir el nombre de una bodega, **para**
arreglar un error de tipeo sin tocar cada vino.

- **Ya decidido:** los vinos apuntan por `bodegaId`, así que el nombre nuevo
  llega a todos solo.
- **Abierto:** si el slug cambia con el nombre. El de un producto es
  **inmutable una vez publicado** ([glosario](../../domain/glossary.md)), y la
  bodega va a tener página indexable: la propuesta es la misma regla.

## HU-02.4 — No poder borrar una bodega que tiene vinos

**Como** operador, **quiero** que el panel no me deje borrar una bodega con
vinos, **para** que esos vinos no desaparezcan de la tienda sin aviso.

- **Por qué existe:** `armarCatalogo` deja afuera, sin error, los productos de
  una bodega que no existe
  ([ADR 008 §2](../../architecture/decisions/008-catalogo-stock-y-carrito.md)).
  Hoy las reglas permiten el `delete`, así que borrar una bodega **despublica
  en silencio**.
- **Abierto:** dónde vive la baranda —en el panel, que ya tiene los productos
  en memoria, o en las reglas, que no pueden contar documentos sin un `get()`
  por vino—. Se decide en los requerimientos.
