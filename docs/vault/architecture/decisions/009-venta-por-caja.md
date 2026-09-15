# ADR 009 — La venta por caja de seis

- **Fecha:** 2026-09-14
- **Estado:** aceptada y **aplicada en stage**. Las reglas están **publicadas**;
  la tienda **no se despliega** (los cinco gates de siempre siguen abiertos)
- **Decide:** que el vino se venda sólo de a 6 botellas, dónde vive esa regla, y
  qué es una caja que ofrece el vendedor
- **Toca:** [ADR 008](008-catalogo-stock-y-carrito.md) — el carrito sube a
  `version: 2` y guarda `botellas` por línea; `tipo: 'compuesto'` queda
  explícitamente sin uso
- **Hace cumplir:** `packages/contratos` (120 tests), `apps/tienda` (21), los 26
  casos de `firestore.rules` contra el emulador, y el seed, que se niega a
  sembrar una caja que no suma una caja
- **Planificación:** `openspec/changes/cajas-de-seis/`

## Contexto

El vino viaja en cajas físicas de 6, así que una botella suelta no tiene con qué
viajar. La vidriera dejaba armar un carrito de cualquier tamaño y calcular un
total que no se podía despachar.

Entró **antes** que `crearOrden` a propósito: después habría sido una
restricción de cobro sobre un carrito que ya aprendió a prometer cualquier
número.

⚠️ **El diseño cambió de forma dos veces durante el brainstorm**, y las dos
versiones descartadas están abajo con su motivo. Es la parte que impide volver a
proponerlas.

## Decisión

### 1. Una caja que ofrece el vendedor NO es un producto

Es una lista de `productoId` con un nombre. Elegirla **llena el carrito**; desde
ahí el comprador cambia lo que quiera.

El argumento es el precio: **no hay descuento**, así que una caja sugerida no
tiene precio propio —es la suma de sus vinos—, y algo sin precio propio no
necesita un documento en `productos`. Sin precio propio tampoco hay stock que
derivar, ni una caja entera que se caiga porque uno de los seis se agotó.

| Alternativa | Por qué no |
|---|---|
| Un `compuesto` con `componentes[]`, stock por `min(floor(stock/cantidad))` y precio escrito a mano | Era el diseño hasta que el dueño decidió que **no va con descuento**. Sin descuento el precio es la suma, y guardar una suma es guardar algo que puede contradecir a sus partes. Arrastraba: unión discriminada en la proyección, `precioDeLasPartes`, un chequeo de deriva en CI, ficha y tarjeta propias, y un `componenteIds` desnormalizado para la purga |
| Precio derivado (suma menos descuento) en un compuesto | El precio cambiaría solo entre que el comprador lo mira y `crearOrden` lo valida. ADR 008 ya midió ~13 minutos de atraso posible |
| Un descuento por llevar seis | Descartado por el dueño. Y no se validaba con lo que existe: `precioUnitarioVisto` es **por línea**, y un descuento por carrito no es propiedad de ninguna línea |
| Reemplazar el carrito al elegir una sugerencia | Borra trabajo del comprador sin avisar |

**`tipo: 'compuesto'` queda en el modelo sin un solo uso.** Es deliberado:
sacarlo es la migración que ADR 008 se ahorró, y el día que exista una caja de
regalo con precio propio el campo está.

### 2. La cuenta es en botellas, no en unidades de venta

`Σ cantidad × presentacion.botellas`.

No es teórico: el catálogo de muestra ya tiene **2 productos de 2 botellas sobre
20**, así que contar unidades daría el número equivocado desde el primer día. Es
la misma unidad en la que `balde` ya mide el stock.

### 3. La regla NO vive en `parsearCarrito`

Es precondición de **cobro**, no de **validez**. Un carrito de 4 botellas es
alguien comprando.

Meterla en el parser tendría un efecto que nadie quiere: `parsearCarrito`
rechaza en vez de corregir —por diseño—, así que un carrito a medio llenar se
descartaría entero en la visita siguiente y el comprador volvería a una tienda
que le vació el changuito.

### 4. El carrito sube a `version: 2` y guarda `botellas`

⚠️ **Es la única excepción a "el carrito no guarda nada del producto", y está
razonada.**

ADR 008 prohíbe guardar precio y nombre porque *"un carrito viejo no puede
recordar un precio que ya no existe"*. `presentacion` es **inmutable por regla
de Firestore**: esto no es un snapshot que envejece, es un hecho que no se mueve.

Existe porque el contador de la barra vive en **todas** las rutas y sólo lee
`localStorage`. Sin el campo no puede contar botellas: con un pack de 2 en el
pedido mostraría **3 donde hay 6**, y alguien seguiría comprando una caja ya
cerrada. Las alternativas eran leer el catálogo en el layout —una lectura de
Firestore en cada ruta, y la home a ISR— o que la barra mintiera.

**No es la fuente de verdad:** `resolverCarrito` lo recalcula contra la
proyección y lo corrige, con test.

⚠️ **Esto NO cierra el hallazgo 1 del ADR 008**, y conviene decirlo porque el
campo se le parece. Aquél pide que `crearOrden` guarde un snapshot de `botellas`
en `items[]` para que una cancelación reponga lo que se descontó; éste es lo
contrario —un valor que se pisa con la proyección— y sólo cubre que la barra no
cuente botellas viejas. Quien escriba `crearOrden` no puede cerrar esa fila
mirando este campo.

**Un carrito `version: 1` se DESCARTA, no se migra.** Se cambió con la tienda
sin desplegar: no había un solo carrito real al que le pasara. Era gratis ahora
y dejaba de serlo el día del primer deploy público.

### 5. Un tamaño, una constante

`BOTELLAS_POR_CAJA = 6`, en un solo archivo. `contarCaja(botellas, porCaja)`
toma el tamaño por parámetro para poder **probar cajas de 3 sin mutar una
constante**: la garantía que interesa no es "hoy da 6", es "la regla es
paramétrica", y eso sólo se prueba corriéndola con dos tamaños.

### 6. Dónde vive la lectura, y por qué la home no la paga

Tres condiciones, las tres del presupuesto de lecturas:

1. **Adentro de `obtenerVidriera`, NO en un `unstable_cache` aparte.** Un
   segundo `unstable_cache` con `revalidate` numérico le baja el `revalidate` a
   la página que lo llama: si lo tocara la home, la ruta más visitada pasaría
   sola a ISR de 60 s y leería Firestore por visita, **sin un error ni un
   aviso**. Medido en la build: `/` sigue saliendo `○` sin revalidate, con
   `/vinos` en `1m` como control.
2. **`leerCatalogoSinCache` NO la incluye.** La home la llama directo y no
   dibuja carril: pagaría por un documento que no renderiza.
3. **`/carrito` y `/vinos/[slug]` no la leen por su cuenta.** Las tres rutas
   comparten una entrada de caché.

### 7. El join de las cajas va EN MEMORIA

Nunca con un `get()` por id. Con 6 cajas de 6 ids serían **36 lecturas por
reconstrucción**: 32 → 68, más que el doble, y **133 %** de la cuota con el
catálogo del MVP a 250 visitas. La misma disciplina que los filtros
([ADR 004 §3](004-frescura-y-lecturas.md)); acá vale 30×.

### 8. La escritura del documento está cerrada incluso para el admin

`allow read: if esAdmin(); allow write: if false;`, con el patrón de `metricas`.
La única regla que importa de una caja es que **sume una caja**, y eso sólo se
sabe mirando `presentacion.botellas` de cada producto: comprobarlo en las reglas
serían **seis `get()` facturados por escritura**, que es exactamente el costo
invisible que ese archivo evita con el custom claim. Lo verifica
`verificarComposicion` del lado del servidor, y el seed se niega a sembrar una
caja que no cierra.

## Presupuesto de lecturas

Campo obligatorio. Lo cuantificó `presupuesto-lecturas` y **corrigió el encuadre
de la propuesta**: no es "+1 por build, 0 por visita". Es **+1 por
reconstrucción**, y hasta el tramo 4 las reconstrucciones **escalan con las
visitas**, porque la caché de datos de Next vive en la memoria de cada instancia
de Cloud Run y no se comparte.

**Medido contra stage**, no razonado: 20 productos + 11 bodegas + popularidad +
cajas = **33**; el control sin carril da **32**.

| | Hoy (20/11) | MVP (200/30) |
|---|---:|---:|
| Por reconstrucción | 32 → **33** | 231 → **232** |
| 100 visitas/día | 3.200 → **3.300** (6,6 %) | 23.100 → **23.200** (46,4 %) |
| 250 visitas/día | 8.000 → **8.250** (16,5 %) | 57.750 → **58.000** (116,0 %) |

**Delta: +0,2 puntos de cuota a 100 visitas, +0,5 a 250. Entra.**

⚠️ La línea del MVP a 250 visitas **ya estaba en 115,5 %**. Este cambio la lleva
a 116 %: no lo causa, pero tampoco corresponde darle el pase de "es un
documento" a un renglón que ya está fuera de cuota. Ese desborde lo debe el
tramo 4.

**La lectura se cobra exista o no el documento**, así que se paga aunque no haya
ninguna caja cargada. El manejo tiene precedente: `leerUnidades` tolera un
`metricas/popularidad` ausente.

## Consecuencias

- ⚠️ **Todo carrito guardado con `version: 1` se descarta.** Sin impacto real:
  la tienda nunca se desplegó.
- El contador de la barra puede **no coincidir** con `/carrito`. Normalmente
  muestra de **más**, porque lo guardado no sabe qué se agotó —y sobre-reportar
  es la dirección segura: el que cree que cerró la caja abre el carrito y se
  entera, que cuesta un clic y no plata—. Pero también puede mostrar de
  **menos**, si un producto se recreó con otra presentación: ahí lo guardado
  dice 1 y la proyección 2. `/carrito` es la fuente de verdad y ahí se
  recalcula. Es el precio de que la barra cueste cero lecturas.
- **El carril no responde a los filtros.** Son filtros de botellas —color, cepa,
  orgánico— y una caja es múltiple en los tres: decir que una caja "es blanca"
  sería mentira.
- Una caja sugerida cuyo vino se agota **se muestra igual**, con el lugar
  marcado. Sólo se descarta cuando se la puede juzgar mal.
- Sin trigger de purga, el carril envejece como el precio (~13 min). Para un
  carril **sin precio propio, sin stock y sin foto** eso no cuesta plata — y es
  un argumento a favor de este diseño. ⚠️ Deja de valer el día que una caja
  lleve precio propio.
- **`crearOrden` hereda un noveno punto**: rechazar todo pedido que no sume un
  múltiplo de `BOTELLAS_POR_CAJA` botellas, recalculado en el servidor.
  ⚠️ **Y tiene que aplicar la regla sobre el MISMO conjunto que va a cobrar y
  despachar.** Una línea agotada sigue en `carrito.lineas` a propósito —para que
  el parser no descarte el carrito entero—, y `PedidoDeCompra` no lleva marca de
  vigencia: si `crearOrden` mapea `lineas → LineaDePedido[]` pero valida la caja
  sobre el resuelto, valida 6 y despacha 7. Lo marcó `revisor-pagos`.
- **`verificarComposicion` la corre SÓLO el seed, no CI.** El invariante de que
  una caja sume una caja vive en una convención, no en una frontera: el día que
  un panel escriba cajas por una callable, nada obliga a esa callable a
  llamarla. La mitigación real es que `resolverCajasSugeridas` descarta la caja
  que demostrablemente no suma, así que una escritura mala degrada a *"la caja
  desaparece"*, no a *"la caja miente"*.

## Lo que apareció midiendo, y ningún documento sabía

| Qué | Cómo apareció |
|---|---|
| ⚠️ **Todos los botones de la vidriera tenían cuatro triangulitos grises en las esquinas** | Ampliando el botón de una caja sugerida. `<button>` trae `background-color` de sistema —medido, los tres canales en 107— y `appearance: auto`, y `.boton` nunca los reseteaba porque sus dos capas son pseudo-elementos. Le pasaba al `Agregar` de cada vino **desde que existe**; a 30 px no se nota, a 200 sí. Misma familia que los del cartucho. Arreglado en `shared/ui`, medido antes y después |
| **El aviso de venta por caja faltaba en la ficha** | El primer `curl` dio `/vinos` = 2 y la ficha = **0**. Lo destapó el control negativo, no la lectura del código |
| **La tarjeta no decía cuántas botellas trae** | Mirando el PNG. `Dos y dos` son **cuatro renglones y seis botellas**, y eso es justo lo que hay que entender |
| ⚠️ **La API de Rules devolvió 403 y mi script lo leyó como "ningún release"** | Le faltaba el quota project. Una lista vacía por error de lectura **confirma cualquier cosa**: es el modo de falla exacto contra el que avisa `CLAUDE.md` |
| ⚠️ **`next build \| head` mata la build por SIGPIPE** | La página quedó pidiendo un CSS que daba **404**, y el arreglo del botón "no aparecía". No era el CSS: era una build truncada por el pipe |
| **Un test viejo habría pasado por el motivo equivocado** | Usaba `version: 1` literal para probar cantidades inválidas; con la versión nueva lo rechazaba la **versión**, no la cantidad |
| **`grep` sobre el HTML da 2, no 1** | El string viaja en el DOM **y** en el payload RSC. Contar líneas con `grep -c` daría 1: el HTML de Next es una sola línea |
| ⚠️ **La tarjeta decía seis y el botón entregaba cinco** | Lo encontró `revisor-pagos`. `llenarConLaCaja` respetaba el `tope` y `resolverCajasSugeridas` **no**: con un id repetido y stock para uno solo, la tarjeta decía *"6 botellas, completa"* y cobraba seis en la vitrina. Dos cuentas de lo mismo que no coinciden — LECCIONES 6.4, el motivo por el que ese archivo comparte `esProductoId` en vez de copiarlo. **Y lo delataba su propio test**, que construía el fixture exacto, asertaba el carrito y nunca la tarjeta |
| **Dos clases CSS escritas que no existían** | `cazador-de-puertas`. `.caja-sugerida--incompleta` y `.control-caja` se escribían y no tenían regla: una caja incompleta se veía **idéntica** a una completa, y yo había mirado el PNG sin notarlo porque el aviso en palabras me tapó la ausencia |

## Lo que hay que medir antes de creerle a este ADR

| Qué | Cómo | Disparador |
|---|---|---|
| El carril en un teléfono de verdad | Mirarlo: el Chrome headless de esta máquina no baja de 504 px sin emulación | La próxima revisión del dueño |
| La purga del carril | Con `Cache-Tag: catalogo`, editar un producto tiene que refrescar el carril | El tramo 4 |
| El gate apagado | Con un catálogo real, `data-catalogo-de-muestra` tiene que dar 0 | El primer catálogo real |

## Cuándo esta decisión deja de servir

- Aparecen cajas de 3 **y** de 6 conviviendo: hoy el tamaño es una constante, no
  un dato por producto.
- Entra un descuento por volumen: `precioUnitarioVisto` no alcanza para
  validarlo.
- Una caja pasa a tener precio propio: ahí sí es un `compuesto`, y vuelve todo
  lo que este ADR descartó.
