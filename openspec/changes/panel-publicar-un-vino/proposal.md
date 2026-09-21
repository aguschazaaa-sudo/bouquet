## Why

El panel carga vinos que **nadie puede poner a la venta**. Lo único que escribe
`publicado` es la factory del alta, con `false`:

```
$ grep -rn "publicado" apps/admin/lib --include=*.dart
data/documento_del_vino.dart:35:    'publicado': false,
```

Nada lo vuelve a tocar nunca. Y `domain/borrador_de_vino.dart:96` ya tiene
`precioFijo => original?.publicado ?? false`, una rama que hoy **no se puede
ejecutar**: ningún vino está publicado. El hito 1 —que el dueño cargue su
catálogo real— no termina en "cargado", termina en "a la venta".

Historias: **HU-03.5 · HU-03.6 · HU-03.7** de
[EP-03](../../../docs/vault/features/panel/EP-03-productos.md). Con estas tres,
**EP-03 queda cerrada**.

**Por qué las tres juntas:** el proposal de `panel-cargar-un-vino` ya lo dejó
escrito — *"las tres necesitan el espejo en Dart de `validarProducto` y del
balde: van juntas en el próximo change"*. Publicar sin decir qué va a pasar es
la pantalla que EP-03 pide evitar, y el precio de un vino publicado es el mismo
campo con otra baranda.

**Y cierra dos hallazgos de `revisor-pagos` que ADR 008 dejó abiertos:**

| # | Qué | Hoy |
|---|---|---|
| 1 | Borrar y recrear un producto con el mismo id **se saltea la inmutabilidad** de `tipo` y `presentacion` | `firestore.rules` todavía tiene `allow delete: if esAdmin()` |
| 2 | **Se puede publicar con `precio: 0`** | `d.precio is int && d.precio >= 0` lo acepta, `validarProducto` lo acepta, y un `precioUnitarioVisto: 0` coincidiría |

## What Changes

- **Publicar y despublicar (HU-03.6).** Un interruptor en la página del vino y
  en el renglón del catálogo. **El panel no borra: despublica** — un vino fuera
  de la tienda conserva su historia, su id y su slug.
- **Antes de publicar, el panel valida lo mismo que la vidriera**, y lo dice
  campo por campo. Hoy `armarCatalogo` descarta y reporta en `descartes`, pero
  **eso sólo se lee en el log del build**: un vino publicado puede no aparecer
  nunca y nadie se entera.
- **Cambiar el precio de un vino que está en la tienda (HU-03.5)**, con dos
  barandas: la confirmación del dedo gordo escrita **sobre el valor nuevo** —no
  sólo sobre el anterior ([ARQUITECTURA §9.4](../../../ARQUITECTURA.md#94-la-baranda-de-config-tiene-que-proteger-la-primera-escritura))—
  y el aviso de que el precio nuevo puede tardar **~13 minutos** en verse hasta
  el tramo 4 de Cloudflare.
- **Ver lo que ve el comprador (HU-03.7):** el balde (`disponible` ·
  `quedan-pocas` · `agotado`), el tope por pedido, y **por qué un vino
  publicado no aparece en la tienda**. Todo calculado por el mismo contrato que
  usa la vidriera, nunca por una cuenta propia del panel.
- **El contrato generado gana un bloque nuevo.**
  `packages/contratos/generated/contratos.json` pasa a llevar las fixtures de
  `balde`/`tope` y de los motivos de descarte de `armarCatalogo`, calculadas
  por el TypeScript de hoy. El espejo en Dart se verifica contra ese JSON, y
  `auditar_estados.mjs` verifica que el JSON esté fresco. Mismo patrón que
  `estado_publico.dart`: **el panel no re-implementa la regla, la lee.**
- **Las reglas se endurecen en tres puntos:**
  - **`allow delete` se cierra.** Cierra el hallazgo 1 en la base, no sólo en
    la pantalla.
  - **`publicado == true` exige `precio > 0`.** Cierra el hallazgo 2 en la
    base. Un borrador sin precio sigue pudiendo existir: nace con `publicado:
    false`.
  - **Cada entrada de `imagenes` tiene que ser una URL `https://`.** Hoy las
    reglas sólo miran que sea una lista de hasta 10; `armarCatalogo` exige
    `startsWith('https://')`, así que una entrada que no lo sea **descarta el
    producto entero de la vidriera sin un error visible**.

### La decisión que este change toma, y que EP-03 dejaba abierta

**La foto NO bloquea publicar.** EP-03 lo dejaba como *"Abierto: si hace falta
al menos una foto para publicar"*. Se cierra por dos hechos medidos:

1. `VentanaDeBotella.tsx:45` **ya renderiza el caso sin foto** —silueta y la
   palabra "sin foto"—, así que publicar sin foto no rompe la vidriera: la
   degrada, y de una forma que alguien diseñó a propósito.
2. **EP-04 no está construida.** Si la foto fuera requisito, hoy no se podría
   publicar **nada** y el hito 1 quedaría trabado esperando un ADR de recorte a
   WebP.

Lo que sí hace falta es que el panel **lo diga antes de publicar**, no después.
Eso es HU-03.7, y va en el mismo change a propósito.

### Lo que este cambio NO hace

- **No sube fotos** (EP-04). El recorte a WebP necesita su propio ADR: la
  vidriera sirve la foto ya recortada y sin `next/image`, y hoy eso lo hace el
  seed con `sharp`.
- **No toca el stock** (EP-05). Su callable y `crearOrden` escriben el mismo
  campo y **se diseñan juntas**; `crearOrden` es hito 2. El panel **lee** el
  stock para el balde, y no lo escribe.
- **Sí agrega la `descripcion`.** Era el hallazgo 14 del
  [mapa del panel](../../../docs/vault/features/panel/overview.md) —"HU-03.4 la
  nombra y el modelo no la tiene"— y el dueño lo contestó el 2026-09-21: la
  ficha la lleva. Entra en este change, punta a punta.
- **Toca la vidriera, y eso NO agrega un objetivo al deploy.** Medido el
  2026-09-21: no hay `apphosting.yaml` en el repo, `apphosting:backends:list`
  no devuelve backends en ninguna región y no hay servicios de Cloud Run. **La
  vidriera nunca se desplegó**, así que "un deploy de `tienda` arrastra los
  seis gates abiertos" es un riesgo de un deploy que este change no hace. El
  código de la ficha se verifica con `npm run dev`, que CLAUDE.md lista como
  ciclo local de segundos. El deploy sigue siendo **reglas → panel**.
- **No borra fotos de Storage** ni toca `imagenes`: sólo endurece qué acepta la
  regla.
- **No cambia el slug de un vino publicado.** Desde ADR 013 el slug es el id y
  no cambia nunca.

## Presupuesto de lecturas

Campo obligatorio (`CLAUDE.md`). Cuota: **50.000 lecturas/día**.

| Qué | Lecturas | Por qué |
|---|---:|---|
| Ver el balde, el tope y el motivo de descarte de cualquier vino | **0** | Sale del catálogo que ya está en memoria (HU-03.1) y del espejo en Dart. Ningún `get()` nuevo |
| Detectar un slug duplicado contra los de muestra | **0** | `Catalogo.duenoDelSlug` ya existe y trabaja en memoria (ADR 013 §4) |
| Publicar o despublicar | **1** | El `update` no lee; el stream trae el documento que cambió |
| Cambiar el precio | **1** | Ídem |
| Las reglas nuevas | **0** | `precio > 0`, el `https://` y el `delete` cerrado son todos sobre `request.resource.data`. Ningún `get()` ni `getAfter()` |

**Publicar los 200 vinos del MVP cuesta ~200 lecturas, una sola vez: el 0,4 %
de la cuota de un día.** El uso diario no cambia.

## Capabilities

### New Capabilities

- `panel-publicar-vino`: publicar y despublicar un vino desde el panel, con la
  validación previa que espeja a la vidriera, y cambiar el precio de un vino
  que está en la tienda con sus dos barandas (HU-03.5, HU-03.6).
- `panel-espejo-vidriera`: el balde, el tope y **el motivo por el que un vino
  publicado no aparece en la tienda**, calculados desde el contrato generado y
  no por el panel (HU-03.7).

### Modified Capabilities

- `catalogo-producto`: se le **agregan** requisitos — un producto no se borra;
  un producto publicado tiene `precio > 0`; cada entrada de `imagenes` es una
  URL `https://`; y el contrato generado publica las fixtures de `balde`,
  `tope` y de los motivos de descarte. La capability la define el change
  `catalogo-y-carrito`, que **todavía no está archivado**, así que no existe en
  `openspec/specs/` y el delta va como `ADDED`. Se le agrega además la
  `descripcion` de la ficha.
- `panel-vino`: el formulario de carga y corrección gana el campo de la
  descripción. La define `panel-cargar-un-vino`, sin archivar todavía.
- `vidriera-ficha`: la página del vino muestra la descripción cuando la hay, y
  cuando no, la sección no está. La define `catalogo-y-carrito`.

## Impact

- **`packages/contratos`:** las fixtures nuevas en `scripts/generar.mjs` y su
  `generated/contratos.json` regenerado. `balde`, `tope` y `armarCatalogo` **no
  cambian de comportamiento**: se exponen, no se tocan.
- **`firestore.rules`:** `allow delete` cerrado; `publicado == true` exige
  `precio > 0`; `imagenes` exige `https://` por entrada. Casos nuevos en
  `scripts/reglas/productos.test.mjs`, cada uno con su aceptado y su rechazado.
  ⚠️ **El `delete` cerrado es un cambio de comportamiento sobre datos que ya
  existen**: hay que confirmar que `scripts/seed/borrar.mjs` no dependa de las
  reglas del cliente (usa el Admin SDK, que las saltea — se verifica, no se
  supone).
- **`scripts/ci/auditar_estados.mjs`:** audita el bloque nuevo del contrato con
  control positivo y negativo, como ya hace con `texto` y `plata`.
- **`apps/admin`:** el espejo en Dart del balde, el tope y los descartes en
  `core/contratos/`; `publicar`, `despublicar` y `cambiarPrecio` en el
  repositorio; el interruptor, la confirmación del precio y el bloque "cómo se
  ve en la tienda" en `presentation/`.
- **Los vinos de muestra:** tienen `muestra: true` y el panel **no los
  despublica** — `muestra` es del servidor y las reglas lo congelan. El panel
  muestra el motivo y no ofrece el interruptor.
- **Deploy:** reglas → panel. Sin functions, sin tienda.
- **Workflow D** en HU-03.5 y HU-03.6: `revisor-pagos` es obligatorio antes de
  desplegar, y el backend —las reglas— va verificado antes que la pantalla.
