## Why

Hoy la foto principal de un vino es **la primera que se subió**, y cambiarla
cuesta sacarla y volverla a subir: dos gestos, una pasada más por
`procesarFoto` y un crudo más en Storage. El próximo paso del hito 1 es que el
dueño cargue su catálogo real, y ahí es donde un vino va a tener dos fotos: la
etiqueta y la contraetiqueta, o una de la bodega y una propia.

**Se construye antes de su disparador, y a propósito.** ADR 015 dejó HU-04.2
esperando *"el primer vino con dos fotos"*. Se midió en producción el
2026-09-24: 22 productos, **0 con dos fotos o más**. No se cumplió. Se toma
igual porque el hito 1 se cierra ahora, y la única salida que hoy existe para
cambiar la principal destruye la foto que se quiere conservar.

Historia: **HU-04.2** de [EP-04](../../../docs/vault/features/panel/EP-04-fotos.md),
**recortada**, como se explica abajo.

## El recorte: se elige la principal, las demás no se ordenan

HU-04.2 pide *"elegir cuál es la primera foto y en qué orden van las demás"*.
**La segunda mitad no le cambia nada a nadie**: la vidriera lee sólo
`imagenes[0]`, en los dos lugares donde dibuja una foto:

```
apps/tienda/src/features/catalogo/VentanaDeBotella.tsx:30   const foto = producto.imagenes[0];
apps/tienda/src/features/landing/seleccion.ts:49            foto: p.imagenes[0] ?? null,
```

Ordenar la segunda y la tercera sería una pantalla que no decide nada, la misma
objeción que ADR 015 le hizo a toda la historia cuando cada vino tenía una sola
foto. **Queda afuera, con disparador: el día que la ficha muestre más de una
foto.**

## What Changes

- Cada foto que no es la principal tiene **"Usar como principal"**: un toque,
  sin confirmación. No se pierde nada y se deshace con otro toque (criterio 3
  del [overview](../../../docs/vault/features/panel/overview.md)).
- La principal se marca como tal **sólo si hay dos fotos o más**. Con una sola
  no hay nada que elegir.
- En un vino guardado, el cambio es una **transacción que relee `imagenes`** y
  escribe la lista con la elegida al frente. Choca con
  [ARQUITECTURA §5.3](../../../ARQUITECTURA.md#53-escrituras-concurrentes-en-arrays),
  que prohíbe reescribir el array, y la transacción es lo que cuida lo que esa
  regla protege: que no se pierda la foto que otra persona subió en el medio.
  Detalle en `design.md`.
- En un alta sin guardar, el cambio es sobre la lista en memoria: no toca la
  base.
- Si la foto elegida ya no está, porque otra persona la sacó, el panel lo dice
  y no escribe.
- Dos textos de error dejan de hablar sólo de **subir**, porque ahora sirven a
  tres operaciones. "Tu cuenta no tiene permiso para subir fotos" es falso
  cuando lo que se rechazó fue elegir la principal.

**No cambia:** ni `firestore.rules` (ya aceptan una `imagenes` reescrita si es
válida), ni `functions/`, ni `contratos`, ni la vidriera.

## Capabilities

### New Capabilities

_Ninguna._

### Modified Capabilities

- `panel-fotos-vino`: **se agregan** requisitos para elegir la principal. La
  capability la declaró `panel-fotos-de-un-vino`, que todavía no se archivó,
  así que `openspec/specs/` no la tiene todavía. Por eso este delta **sólo
  agrega** (`## ADDED Requirements`) y no modifica nada: archiva igual en
  cualquier orden.

## Impact

- **Panel, feature `fotos`**: la función pura `conPrincipal` en `domain/`, que
  usan las dos rutas; `hacerPrincipal` en `RepositorioDeFotos` y en su
  implementación de Firebase; `ErrorDeFotos.yaNoEsta`; `RenglonDeFoto` y
  `SeccionDeFotos`.
- **Lecturas**: **1 por cambio**, la de la transacción, más 1 por cada sesión
  del panel que tenga el catálogo abierto, porque `productosProvider` es un
  `snapshots()` y recibe el documento cambiado. Cargando el catálogo, con 50
  cambios por día y dos sesiones abiertas: **150/día, el 0,3 % de la cuota de
  50.000**. La página no lee nada nuevo: el vino sale del catálogo en memoria.
- **La vidriera**: cambiar la principal de un vino **publicado** cambia su
  foto en la tienda. Hoy le llega en la próxima reconstrucción. Con el tramo 4
  va a disparar una purga, igual que `moverStock` (ADR 016): conviene elegir
  la foto **antes** de publicar.
- **Deploy**: sólo `admin`. No hay reglas ni functions que desplegar antes.
