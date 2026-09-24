## Context

Todo lo que se decidió —origen, `por_fuera`, la forma de la Orden, la
idempotencia, las guardas, el presupuesto— está en
[ADR 018](../../../docs/vault/architecture/decisions/018-pedidos-de-whatsapp.md).
Este documento dice **cómo se parte el trabajo y en qué orden**, no lo repite.

Estado de partida (medido el 2026-09-24):

- **No existe una sola Orden ni `crearOrden`.** `orden.ts` sólo tiene los estados;
  la forma del documento la fija este cambio.
- Ya están declarados, y **sin verificar**: los índices de `ordenes` en
  `firestore.indexes.json` y `contadores/{nombre}` en las reglas.
- El panel tiene `/pedidos` como una `SeccionVacia`, y `productosProvider` ya
  trae `stock`, `muestra`, `precio` y `botellas` de cada vino: el selector de
  vinos no necesita ninguna lectura nueva.
- `moverStock` es el molde de la callable: núcleo con la base por parámetro,
  probado contra el emulador de Firestore sin el de Functions (cuyo *discovery*
  no completa en esta máquina), y un envoltorio de diez líneas.
- El panel **no tiene un normalizador de teléfono en Dart**. Existe sólo en
  `contratos`.

## Goals / Non-Goals

**Goals:**

- Que un pedido de WhatsApp se cargue, descuente stock, tenga número y se vea en
  el panel, con producción verificada.
- Que la forma de la Orden que se fija acá sirva tal cual a la vidriera.
- Que ningún camino deje stock negativo, un número repetido o un pedido doble.

**Non-Goals:**

- Despachar, cancelar, cargar seguimiento, avisar por WhatsApp (EP-07).
- Cobros y reembolsos (EP-08), ni `crearOrden` de la vidriera.
- Cajas y peso del pedido en el detalle (ADR 018 §7).
- Notificaciones push (HU-06.5) y buscar por número (HU-06.4).
- Correr los casos del emulador en CI.

## Decisions

### D1. El núcleo puro va aparte de la transacción

`functions/src/pedidos/armar.ts` es una función **pura**:
`armarOrden(pedido, productosLeidos, numero, uid)` devuelve el documento de la
Orden y el stock nuevo de cada producto, o el motivo del rechazo. La transacción
(`crear.ts`) sólo lee, llama a `armarOrden` y escribe.

*Por qué:* casi toda la lógica que importa —stock, precio visto, muestra,
compuesto, snapshot, total— se prueba con `node --test` en segundos y sin
emulador. El emulador queda para lo que sólo él puede probar: concurrencia,
atomicidad y el marcador.

*Alternativa descartada:* todo adentro de `runTransaction`, como `crearOrden`
lo tendría por defecto. Cada caso de negocio costaría un arranque del emulador
(~50 s en esta máquina).

### D2. Los tipos de la Orden viven en `contratos`

`packages/contratos/src/pedido.ts` exporta `PedidoDelPanel`,
`parsearPedidoDelPanel`, `ItemDeOrden`, `OrdenNueva` y los topes. El panel y la
callable comparten así una sola forma, y el espejo de Dart la verifica contra
fixtures **calculadas por el TypeScript**, como ya hacen `stock` y `texto`.

### D3. El teléfono se espeja en Dart con fixtures calculadas

`normalizarTelefonoAR` se espeja en `core/contratos/telefono.dart`. Las
fixtures (`ENTRADAS_DE_TELEFONO`) salen de `contratos`, van al JSON generado y el
test de Dart las verifica: **si la función del panel diverge de la del servidor,
el panel mostraría un número y el servidor guardaría otro**, y `wa.me` abriría el
chat de otra persona. Es el modo de falla que el glosario ya documenta.

### D4. El id de la Orden es el `idPedido`

Ver ADR 018 §4. Se compara con las **líneas** (`productoId` y `cantidad`,
ordenadas), no con el pedido entero: el operador puede corregir un dato de
entrega en un reintento sin que eso sea otro pedido, pero no puede cambiar lo
que se descuenta.

⚠️ **Consecuencia que hay que decir:** un reintento con la misma `idPedido` y la
misma línea pero otra dirección **devuelve la Orden original sin actualizarla**.
Corregir un dato después de crear no es un reintento, y hoy no hay editar (EP-07).
Queda en el texto de la pantalla de éxito.

### D5. Un núcleo, dos callables — con el origen tipado, no parametrizado

`armarOrden` recibe el `origen` **de quien lo llama**, nunca del pedido, y hoy el
tipo sólo admite `'whatsapp'`. La diferencia entre orígenes no vive en un `if
(origen === 'whatsapp')` escondido: el día que exista la de la vidriera, esa
callable **amplía el tipo y escribe su propia rama** (claim, caja de seis).

*Por qué ahora y no después:* es el punto donde el hallazgo 12 se decide bien o
mal. Si el núcleo aprendiera el origen leyendo el pedido, la puerta que se cierra
en ADR 018 §1 quedaría abierta en el primer refactor. Y `parsearPedidoDelPanel`
**rechaza** un pedido que traiga `origen` o `estadoPago`.

*Alternativa descartada:* un parámetro `ReglasDeOrigen { exigeCajaDeSeis }` con la
rama de la vidriera rechazando con `unimplemented`. Se escribió primero en este
diseño y se sacó al programar: sin consumidor era código muerto con un test que
lo decía, y el tipo `'whatsapp'` dice lo mismo sin una línea ejecutable.

### D6. El panel: una feature `pedidos/`, de la hoja a la página

Bottom-up, cada archivo dentro de las 200 líneas y con un solo widget público:

```text
domain/      orden.dart · pedido_a_cargar.dart · linea_a_cargar.dart ·
             fallo_de_pedidos.dart · repositorio_de_pedidos.dart
data/        documento_de_la_orden.dart · repositorio_de_pedidos_firebase.dart
presentation/ textos_de_pedidos.dart
             fila_de_pedido.dart · selector_de_estado.dart · lista_de_pedidos.dart
             pantalla_de_pedidos.dart                      ← ya existe, se reemplaza
             seccion_de_items.dart · seccion_de_contacto.dart ·
             pagina_del_pedido.dart
             renglon_de_linea.dart · elegir_vinos.dart · datos_de_entrega.dart ·
             pagina_de_cargar_pedido.dart
pedidos_providers.dart
```

- **`documento_de_la_orden.dart` devuelve `null` en un documento roto**, y el
  repositorio lo cuenta y lo muestra como «pedido incompleto», no lo descarta:
  la lección de `armarCatalogo`, que descarta sin avisar, era exactamente el
  defecto que HU-03.7 tuvo que cerrar.
- **La bandeja no usa `snapshots()`.** Una lectura por apertura y otra por
  «Actualizar» ([ARQUITECTURA §6.3](../../../ARQUITECTURA.md#63-el-presupuesto-completo)):
  el riesgo de cuota es un stream sin `limit`.
- **El detalle recibe la Orden por `extra` del enrutador** y, si no la trae (URL
  directa), la lee. El `id` viaja en la ruta.
- **`pedidos` importa `catalogo_providers.dart`** para el selector de vinos. Es un
  acople entre features; el panel ya tiene uno (`catalogo → stock`) y esto lo
  amplía. Lo deja anotado para `revisor-acoplamiento`.

### D7. Orden de construcción y de deploy

1. `contratos` (estado, proyección, pedido, teléfono) → JSON regenerado → espejo Dart
2. Reglas y su suite
3. `functions`: puro → emulador → callable
4. **`revisor-pagos`, antes del commit del backend**
5. Deploy: **reglas → functions**; verificar en producción con los tres controles
6. Panel: dominio → datos → presentación → enrutador
7. `cazador-de-puertas`, CI, deploy del panel, verificación

El panel no se despliega hasta que el backend esté verificado: un formulario que
llame a una callable inexistente es el «botón fantasma» de PadelPunilla.

## Risks / Trade-offs

- **[El backend no se puede llamar con un usuario real desde acá]** —mintear un
  token lo frena el clasificador—. → Se verifica lo que se puede desde afuera
  (preflight 204, `POST` anónimo 401 JSON, función inventada 404) y **la primera
  carga real la hace el dueño**, como pasó con `moverStock`. Queda escrito como
  *no verificado hasta que alguien la use*.
- **[Cada prueba de producción deja una Orden y baja stock]** → No se corre la
  callable en producción con datos inventados. Se usa el emulador.
- **[`por_fuera` rompe una APK vieja]** → No hay APK repartida (H5); anotado.
- **[Cambio de contrato con espejo en Dart]** → El test de Dart lo compara
  contra el JSON, y `auditar_estados.mjs` verifica que el JSON esté fresco.
- **[Un pedido mal cargado no se puede cancelar]** (EP-07) → Se repone con
  `moverStock`. La Orden queda ahí, y **no hay cómo sacarla de la bandeja**:
  es una limitación real de este corte y se dice en el ADR.
- **[Dos personas cargan el mismo pedido a la vez]** → Dos `idPedido`, dos
  Órdenes, stock descontado dos veces. No hay defensa que no sea humana:
  **es el caso de la familia, con dos teléfonos, y se dice**.

## Migration Plan

Sin migración de datos: no hay Órdenes. Sí de contrato:

1. Regenerar `contratos.json` **después** del bump de versión y de tocar
   `orden.ts` (`_verdad.md` embebe la versión: al revés, CI da rojo un push
   después).
2. Deploy en el orden fijo. Rollback: `firebase functions:delete crearOrdenDelPanel`
   y republicar el `firestore.rules` anterior; el panel viejo no llama a ninguna de
   las dos.

## Open Questions

- ¿El dueño quiere que un pedido de WhatsApp pueda incluir un vino **no
  publicado**? Se decidió que sí (ADR 018 §5); si prefiere lo contrario es una
  línea.
- ¿El tope de 30 líneas alcanza? Es decisión mía (ADR 018).
