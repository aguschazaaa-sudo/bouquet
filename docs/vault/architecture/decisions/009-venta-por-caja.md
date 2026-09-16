# ADR 009 — La venta por caja de seis

- **Fecha:** 2026-09-14
- **Ampliada:** 2026-09-15 con el **§9**, cómo se DICE la regla. Lo pidió el
  dueño mirando la pantalla: la regla base de la transacción salía al cuerpo de
  una nota al pie
- **Enmendada:** 2026-09-15 con el **§10**, que le pone un límite a la regla: lo
  que **viene en su propia caja** viaja solo y no cuenta para las seis. Lo dijo
  el dueño, y **cambia el §2**: la cuenta sigue siendo en botellas, pero sólo
  sobre las sueltas
- **Estado:** aceptada y **aplicada en stage**. Las reglas están **publicadas**;
  la tienda **no se despliega** — y el 2026-09-15 se verificó por CLI que **no
  hay a dónde**: `apphosting:backends:list` de `bouquet-vinos` devuelve la tabla
  vacía y `bouquet-vinos.web.app` da **404 Site Not Found**
- **Decide:** que la botella **suelta** se venda sólo de a 6 —y que lo que viene
  en su propia caja viaje solo (§10)—, dónde vive esa regla, cómo se dice, y qué
  es una caja que ofrece el vendedor
- **Toca:** [ADR 008](008-catalogo-stock-y-carrito.md) — el carrito sube a
  `version: 2` y guarda `botellas` por línea; `tipo: 'compuesto'` queda
  explícitamente sin uso
- **Hace cumplir:** las suites de `packages/contratos` y `apps/tienda` —el
  conteo vive en [`_verdad.md`](../../_verdad.md), que lo calcula; acá estaba
  escrito a mano y envejeció en un día—, los casos de `firestore.rules` contra
  el emulador, y el seed, que se niega a sembrar una caja que no suma una caja
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

⚠️ **ENMENDADO POR EL §10 el 2026-09-15.** La unidad es la correcta y el
conjunto no: la suma va **sólo sobre las botellas sueltas**. Esos mismos 2
productos de 2 botellas son justamente los que **no** cuentan — vienen
embalados y viajan solos. Este párrafo se deja escrito, y no corregido, porque
es el razonamiento que llevó a la regla vieja.

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

### 9. La regla se DICE con peso, y eso es parte de la decisión (2026-09-15)

⚠️ **Este ADR decidió la regla y no decidió cómo se dice, y por eso salió
susurrada.** El dueño lo marcó mirando la pantalla: *"la regla de las 6
botellas está muy tenue para ser la regla base de la transacción."* Tenía
razón, y las capturas lo miden:

| Dónde | Cómo salía | Qué había al lado |
|---|---|---|
| Cabecera de `/vinos` | Un `<p>` a `--t-cuerpo`, **debajo** de la bajada, con un filete a la izquierda: la forma tipográfica de una aclaración | `CAJAS ARMADAS`, que es una sección **opcional**, pesaba más |
| Mostrador de la ficha | `.ficha__caja`, 0,92 rem en `tinta-2`, **debajo** del precio y del botón | El monto a 1,45 rem y `LA BOTELLA` al lado: lo más grande del mostrador prometía una unidad que no se puede comprar sola |
| `/carrito` | `4 de 6` a 1,5 rem y la frase a 1 rem en `tinta-2`, entre dos filetes finos | El total a **2,5 rem**. La pantalla gritaba un número que no se puede cobrar y susurraba por qué |

**La decisión: el número deja de ser una palabra adentro de una frase y pasa a
ser una CIFRA** —Archivo tabular, 57 px a 1440—, dentro del anillo del
cartucho. Las tres piezas (`Se vende por caja` · `6` · `botellas` · la
invitación) viven en `ReglaDeLaCaja`, con dos variantes: `placa` para la cava y
`franja` para el mostrador de papel.

Tres cosas que se decidieron con esto, y el porqué de cada una:

1. **El marco es `.cartucho-deco`, no un borde nuevo.** El anillo octogonal con
   la ranura de área cero ya está medido en `shared/deco/`; escribir otro era
   volver a cometer la muesca del chaflán que ese archivo documenta. La placa
   sólo pisa `--chaflan` y el `padding`.
2. **En la ficha va ENTRE el monto y el botón**, no debajo de los dos: ocupa el
   hueco que a 1440 quedaba vacío, que es justo por donde pasa el ojo del
   precio al `Agregar`.
3. **En `/carrito` la cifra queda un escalón POR DEBAJO del total** (2,1 contra
   2,5 rem). El total es el resultado; la caja es la condición. Si empatan no
   hay jerarquía, hay ruido.

| Alternativa | Por qué no |
|---|---|
| Subirle el cuerpo y el color al párrafo | Es lo que ya era, más grande. Un párrafo con más puntos sigue siendo prosa, y la prosa no compite con un número de 2,5 rem |
| Repetir la regla en cada tarjeta del listado | Veinte veces la misma frase deja de ser información y pasa a ser ruido. Se dice **una vez por listado**, como estaba |
| Pintar la placa con un fondo | `deco.css` lo advierte: un `background` sobre el cartucho pinta las cuatro esquinas que el anillo deja afuera y aparecen los triangulitos. Se puede hacer con `clip-path: var(--octogono)`, pero el anillo dorado ya es el único tono medio de la página: el relleno no compraba nada |
| Un color de alarma para la caja incompleta | La casa no reta. El borgoña queda para la caja **cerrada**, que es donde rima con el botón `Terminar la compra` que aparece abajo |

⚠️ **En el teléfono se cae la invitación, y es medido.** El mostrador de la
ficha es `position: sticky`: lo que mida se lo come a la foto del vino durante
todo el scroll. A 390×844, con la nota puesta mide **223 px (26,4 % de la
pantalla)**; sin ella, **186 px (22 %)**. Se cae la cortesía —*"Elegí las que
quieras y armá la tuya"*, que además se dice entera en la cabecera de `/vinos`,
que es por donde se llega a la ficha— y **nunca la regla**: abajo de 480 px se
sigue leyendo `SE VENDE POR CAJA · 6 botellas`.

⚠️ **Había un CUARTO lugar y este ADR no lo sabía: el checkout.** Lo encontró
`cazador-de-puertas` barriendo el cambio. `TEXTOS.cajaIncompleta` —*"El vino
viaja de a seis. Volvé al pedido y completá la caja."*— sale por
`.resumen__impedimento`, que estaba en `tinta-3` —el **piso** de texto legible—
en itálica de 0,95 rem, debajo de un total de 2,1 rem y de un `Ir a pagar`
muerto. Es la misma inversión, en la pantalla donde se mueve la plata.

Se le subió el peso (cuerpo y `tinta-1`, sin itálica) y **no** se le puso marco:
justo abajo vive `.resumen__gate`, que ya es una caja enmarcada diciendo
*"Todavía no se puede pagar"*. Dos marcos apilados diciendo lo mismo es ruido,
no énfasis. El mismo tratamiento le toca a los otros dos impedimentos —faltan
datos, falta el envío— porque los tres contestan la misma pregunta: por qué el
botón no anda.

Esa pantalla **no es alcanzable con la caja abierta desde el flujo normal** —el
botón de `/carrito` sale sólo con la caja cerrada—, pero sí desde un marcador o
un enlace viejo, que es exactamente cuando nadie tiene el contexto para
entender un susurro.

**El copy pasó por `voz`**, que lo aprobó sin editar: el reflexivo *"se vende"*
no es la voz de trámite que `voz.md §5` prohíbe —ésa oculta quién actúa sobre
un pedido del cliente—, y el propio §9.5 ya usa esa construcción en un texto
aprobado.

### 10. Lo que viene en su propia caja NO cuenta para las seis (2026-09-15)

⚠️ **Este ADR decidió que el vino viaja de a seis y no se preguntó por el vino
que YA viene embalado.** Lo marcó el dueño: *"los vinos que vienen en cajas
(caja de 2 por ejemplo) se venden sueltos, tienen su propio packaging así que
pueden viajar solos, así que no cuentan para la caja de 6."*

El §2 decía lo contrario con todas las letras —*"el catálogo de muestra ya
tiene 2 productos de 2 botellas sobre 20, así que contar unidades daría el
número equivocado"*— y tenía razón en la unidad y no en el conjunto: la cuenta
va en botellas, **pero sólo sobre las sueltas**.

**La decisión: la regla de las seis alcanza sólo a la botella suelta.** Un
producto de más de una botella trae su embalaje, viaja solo, y frente a la caja
de seis no suma, no completa y no rompe.

| Antes | Ahora |
|---|---|
| 3 packs de 2 = una caja completa, cobrable | 3 packs = **cero** botellas sueltas, cobrable igual (cada uno viaja) |
| 4 sueltas + 1 pack de 2 = 6 botellas, **cobrable** | 6 botellas y **NO cobrable**: las 4 sueltas siguen sin caja |
| Un pedido de un solo pack = 2 botellas, **no cobrable** | **Cobrable**: es una caja cerrada que se despacha sola |

**`viajaSolo(p)` se DERIVA de `presentacion.botellas > 1`, no es un campo.** Una
unidad de venta de más de una botella es, por definición, una caja. Agregar un
booleano al documento sería tocar `validarProducto`, `firestore.rules`, el seed
y el panel para representar algo que ya está representado. ⚠️ El día que exista
un pack **sin** caja propia —dos botellas atadas—, deja de ser derivable y ahí
sí es un campo.

| Alternativa | Por qué no |
|---|---|
| Dejar la regla como estaba | Es lo que hay: cobra un pedido de 4 sueltas + 1 pack como si fuera una caja, y le niega la venta a quien quiere **sólo** una caja de regalo. Las dos son plata |
| Un campo `viajaSolo` en el documento | Cuatro lugares nuevos para un dato que ya se deduce de uno existente e **inmutable**. Y un campo que se puede contradecir con `presentacion` es un campo que algún día se contradice |
| Contar el pack como 1 botella para la caja | Inventa una equivalencia falsa y hace que dos packs "completen" un tercio de caja que no existe |
| Exigir que TODO pedido sume seis, packs incluidos | Es la regla vieja con otro nombre: obliga a comprar cuatro botellas más para poder llevarse un regalo de dos |

**Una caja armada pasa a ser de botellas sueltas, exactamente seis.** Como cada
entrada es una botella, la cuenta de entradas **es** la cuenta de botellas y se
puede exigir en la forma, sin catálogo: `validarCajasSugeridas` pide
`=== BOTELLAS_POR_CAJA` en vez de `<=`. `verificarComposicion` rechaza además al
vino empacado con su nombre adentro del motivo, y `resolverCajasSugeridas` lo
descarta **sin esperar a ver los otros cinco**: un vino que viaja solo no arma
caja con nadie, y eso se juzga con un solo producto a la vista.

⚠️ **Eso mata a la caja `dos-y-dos` del catálogo de muestra** —dos packs de 2 +
dos botellas—, que existía justamente para probar la regla vieja. La reemplaza
`dos-de-cada` (dos Alamos, dos Trumpeter Chardonnay, dos Santa Julia Rosé), que
cubre el único caso de stage que quedaba sin cubrir: una caja armada que deja
líneas de **cantidad 2** en el carrito.

#### El despacho, que es la mitad del cambio

Si el pack viaja solo, **viaja en su propio bulto**. `bultosDelPedido` pasa a
recibir la `CargaDelPedido` —`{ sueltas, propias[] }`, una entrada por unidad
empacada— en vez de un total de botellas, y `cajasADespachar` y
`pesoDelPedidoKg` salen de contar y sumar esa lista, para que no haya dos
cuentas de lo mismo.

⚠️ **Aplanar a "botellas" no era un detalle de firma: cotizaba mal.** Seis
botellas en tres packs daban `ceil(6/6) = 1` bulto — se le pide al correo **un**
bulto y se le entregan **tres**—. Y 4 sueltas + 1 pack de 2 cotizaba 1 caja de
8 kg cuando son 2 bultos y 11 kg. Medido en la pantalla: el resumen del checkout
ahora dice *"Viaja en 2 cajas · 11 kg"*, y con un solo pack *"Viaja en una caja
· 3 kg"*.

**El peso por bulto pasa a ser una función, anclada al número medido.**
`pesoDelBultoKg(n) = ⌈n × 1,118 + 0,6⌉`: con seis da **8**, que es lo que ya se
declaraba, y con dos da **3**. El 1,118 es la botella que pesó el dueño; el 0,6
del embalaje **no está medido, está calibrado** para reproducir el 8 — y está
escrito así para que el día que se pese una caja armada se corrija en un solo
lugar y los dos tamaños se muevan juntos.

⚠️ **Las MEDIDAS de un pack son una proporción, no una medición.** El ancho
escala con las botellas (24 cm / 6) con un piso de 9 cm, porque las botellas van
paradas una al lado de la otra; el largo y el alto no escalan. Con seis
reproduce la caja de catálogo. Una caja de regalo de dos puede ser más ancha y
más chata que esto.

⚠️ **Y apareció un tercer defecto midiendo esto: el cotizador simulado cobraba
por CANTIDAD DE BULTOS y no por peso**, con un comentario arriba que decía
*"un correo cobra por escalón de peso"*. Funcionaba de casualidad mientras todos
los bultos pesaban 8 kg. Con bultos de 3 kg, un pack salía **igual** que una
caja de seis llena. Ahora el precio sale del peso declarado, sublineal y anclado
a `CAJA_KG`.

#### Cómo se DICE, que es donde se veía el problema

| Dónde | Qué pasaba | Qué dice ahora |
|---|---|---|
| Ficha de un pack | La placa de §9 —lo más visible del mostrador— decía `SE VENDE POR CAJA · 6 botellas` sobre un vino al que esa regla **no lo alcanza** | `VIAJA SOLA · 2 botellas en su caja · Ya viene embalada: no necesita completar las seis` |
| Cabecera de `/vinos` | La regla, sin su excepción | La misma, más *"Las que vienen en su caja viajan solas"* |
| Línea del pedido | Nada: sus botellas no aparecían en el `4 de 6` y no había por qué | `Viaja sola: no cuenta para las seis`, en la línea del vino |
| Barra | Contaba TODAS las botellas contra 6 | Cuenta las **sueltas** mientras falten; el total cuando no falta ninguna |
| Checkout | *"El vino viaja de a seis"* | *"Las botellas **sueltas** viajan de a seis"* |
| `/pedido` vacío | *"El vino viaja de a seis"* sobre un carrito **sin nada adentro** | *"Todavía no hay nada en tu pedido"* |

**La placa es la MISMA pieza con dos mensajes, no una pieza nueva.** Es el mismo
hueco del mostrador y la misma pregunta —cómo se vende esto—, y medido pesa lo
mismo: **64,97 px** de alto en los dos casos, a 390 px.

⚠️ **Y una la vi mirando el PNG, no el diff:** con 4 sueltas y un pack, la
pantalla dice `4 de 6` arriba y `6 botellas` abajo del total. Las dos son
ciertas y juntas se leen como un error. La frase pasa a decir *"Faltan 2
botellas **sueltas**"* —y sólo cuando el pedido tiene algo que viaja solo, o la
palabra sería ruido para los otros veinte vinos—.

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

**El §10 suma CERO lecturas, y no es una promesa: es una propiedad de dónde vive
el dato.** `viajaSolo` se deriva de `presentacion.botellas`, que ya viaja en la
proyección que las tres rutas comparten; el carrito ya guardaba `botellas` por
línea desde el §4, así que la barra sigue costando **cero**; y la carga del
pedido se calcula en el navegador sobre esa misma proyección. Ni un `get()`
nuevo, ni una entrada de caché nueva. Medido en la build: `/` sigue saliendo
`○` **sin revalidate**, con `/vinos`, `/carrito` y `/pedido` en `1m` de control.

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
- **`crearOrden` hereda un noveno punto**: rechazar todo pedido cuyas botellas
  **sueltas** no sumen un múltiplo de `BOTELLAS_POR_CAJA`, recalculado en el
  servidor — y **aceptar** el pedido de sólo cajas cerradas, que tiene cero
  sueltas (§10). Un servidor que repita la regla vieja le va a negar la venta a
  quien quiere un regalo de dos.
  ⚠️ **Y tiene que armar la CARGA sobre el mismo conjunto también** (§10): la
  regla mira las sueltas, el cobro mira el total y el despacho mira los bultos —
  si esos tres salen de conjuntos distintos, se cobra uno y se despacha otro.
  Hoy `botellasSueltas`, `botellasEnCarrito` y `cargaDelPedido` filtran con el
  **mismo** predicado (`vigente` y con producto), y eso es lo que `crearOrden`
  tiene que repetir.

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
| ⚠️ **Mi verificador de contraste devolvía basura en vez de fallar** (2026-09-15) | Midiendo la placa sobre papel. El helper parseaba el color con `match(/\d+/g)`, y un `color-mix()` computado NO sale `rgb(26, 18, 16)`: sale `color(srgb 0.273726 0.243922 0.22902)`. El regex se comía los dígitos sueltos y el contraste daba **12.880.882:1**. Un número absurdo se ve; el peligro es que el mismo bug, con otro color, da un número **plausible**. Los valores que sí se leyeron (rótulo 8,40 · cifra 16,13) son los que salieron en `rgb()` |
| **El canario apareció 4 veces y la documentación decía 2** | `curl` sobre `/vinos`. No era un bug del conteo: la cadena estaba en un `aria-label` **y** en el `<p>`, por dos (DOM + payload RSC). Destapó que el `aria-label` era redundante —un lector de pantalla oía el rótulo dos veces seguidas—, se borró, y el conteo volvió a **2**. El número que no cerraba era el síntoma, no el problema |
| ⚠️ **DOS veces escribí un razonamiento con la forma de una medición**, y las dos las agarró medir | (a) *"el mostrador sin la nota mide 169 px"* era una **resta** —altura total menos la placa—; medido da **186**, 17 px más. (b) *"la regla descendiente le gana a `.regla-caja__cifra` y la cifra sale al cuerpo de la bajada"* es **falso**: la cifra es un `<span>` adentro del `<p>`, no un `<p>`, y sale a 57,12 px con la regla vieja puesta o sacada. La víctima real era el **rótulo** (13,60 px dorado → 19,04 px marfil-2: dejaba de ser un rótulo). El arreglo estaba bien por el motivo equivocado, que es la peor forma de tener razón. **Una resta y una medición se escriben igual**, y un razonamiento de cascada también |
| **Dos clases CSS escritas que no existían** | `cazador-de-puertas`. `.caja-sugerida--incompleta` y `.control-caja` se escribían y no tenían regla: una caja incompleta se veía **idéntica** a una completa, y yo había mirado el PNG sin notarlo porque el aviso en palabras me tapó la ausencia |
| ⚠️ **El cotizador simulado cobraba por CANTIDAD DE BULTOS, no por peso** (2026-09-15) | Un test nuevo del §10: *"un pack no sale lo mismo que una caja de seis"* falló. El comentario de esa función decía *"un correo cobra por escalón de peso"* y el código contaba bultos — daba igual mientras todos pesaran 8 kg, y con bultos de 3 kg empezó a mentir. **Lo destapó el caso nuevo, no una lectura del código** |
| ⚠️ **Casi le echo al §10 los 19 px que le debía al balde** (2026-09-15) | El mostrador de la ficha del pack mide **204,53 px** a 390 y el §9 tenía documentados **186**. Parecía que la placa nueva había crecido. El control: `alamos-malbec` —suelto— da **185,53 px (22,0 %)**, y `portillo-malbec` —**suelto, con stock 5**— da **204,53**, idéntico al pack. Los 19 px son el renglón `QUEDAN POCAS`, que el pack tiene porque le quedan 3. La placa pesa **64,97 px** exactos en los dos mensajes |
| **La caja `dos-y-dos` de stage se cae sola, y lo dice la build** | `[cajas] descartada cajasSugeridas.cajas[3]: 4 entradas para una caja de 6`, tres veces (una por worker). El carril de `/vinos` pasó de **4 a 3** tarjetas contra el documento viejo de stage: la degradación es *"la caja desaparece"*, no *"la caja miente"*, que es lo que el §8 prometía |

## Lo que hay que medir antes de creerle a este ADR

| Qué | Cómo | Disparador |
|---|---|---|
| El carril en un teléfono de verdad | Mirarlo: el Chrome headless de esta máquina no baja de 504 px sin emulación | La próxima revisión del dueño |
| ⚠️ **Cuánto pesa y cuánto mide una caja de 2 de verdad** | Una balanza y una cinta. Hoy el peso sale de `⌈n × 1,118 + 0,6⌉` —el 0,6 está **calibrado**, no medido— y el ancho es una proporción de la caja de seis | Cuando haya una caja de regalo en la mano, y **antes** de las tarifas reales |
| ⚠️ **Re-sembrar `cajasSugeridas/publicas` en stage** | `node scripts/seed/seed.mjs`. El documento vivo todavía tiene `dos-y-dos`, que el código nuevo descarta: el carril sirve **3** cajas y `dos-de-cada` no existe hasta que corra el seed | Antes de mirar el carril de stage, y antes del primer deploy |
| La purga del carril | Con `Cache-Tag: catalogo`, editar un producto tiene que refrescar el carril | El tramo 4 |
| El gate apagado | Con un catálogo real, `data-catalogo-de-muestra` tiene que dar 0 | El primer catálogo real |

## Cuándo esta decisión deja de servir

- Aparecen cajas de 3 **y** de 6 conviviendo: hoy el tamaño es una constante, no
  un dato por producto.
- Entra un descuento por volumen: `precioUnitarioVisto` no alcanza para
  validarlo.
- Una caja pasa a tener precio propio: ahí sí es un `compuesto`, y vuelve todo
  lo que este ADR descartó.
- **Aparece un pack SIN caja propia** —dos botellas atadas, un combo armado a
  mano—: ahí `viajaSolo` deja de poder derivarse de `presentacion.botellas` y
  pasa a ser un campo del documento, de las reglas y del panel (§10).
- **El correo cobra por bulto y no por peso**: hoy un pack de 2 se cotiza más
  barato que una caja de seis porque pesa menos. Con tarifa por bulto, mandar
  tres packs sueltos sale caro y conviene meterlos en una caja grande — y eso
  cambia el despacho, no sólo el precio.
