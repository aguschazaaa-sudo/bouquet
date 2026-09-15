# ADR 010 — El checkout: la entrega decide, el pago redirige

- **Fecha:** 2026-09-15
- **Estado:** aceptada y **aplicada en stage**. `/pedido` existe y está armado
  entero; **no cobra** (`EL_CHECKOUT_NO_COBRA`, el sexto gate)
- **Decide:** dónde vive el checkout, cómo se elige la entrega, qué datos se
  piden y qué no, y qué queda simulado hasta que los proveedores estén
  confirmados
- **Toca:** el **glosario** — `Zona` cambia de significado y *"fuera de zona"*
  deja de existir (§1); [ADR 003](003-pagos.md), que queda con proveedor
  elegido y forma de cobro decidida; [ADR 006](006-estructura-de-la-tienda.md),
  porque `checkout/` **no** nace como feature propia; y
  [ADR 009](009-venta-por-caja.md), que ahora tiene su consumidor: la caja
  cerrada es lo que abre la puerta
- **Hace cumplir:** `packages/contratos` (143 tests, eran 121), `apps/tienda`
  (30, eran 21), y los hooks `server-only-guard`, `frontera-features` y
  `widget-size-guard`, que bloquearon de verdad durante este cambio
- **Proveedores:** [`enviopack.md`](../proveedores/enviopack.md) y
  [`mercado-pago.md`](../proveedores/mercado-pago.md), escritos en este mismo
  cambio

## Contexto

`/carrito` sabía sumar y no sabía entregar: no había forma de decir a dónde va
el pedido ni de pagarlo, y el botón de terminar la compra no existía a propósito
([ADR 008](008-catalogo-stock-y-carrito.md) §4).

El dueño fijó cuatro cosas, y las cuatro cambian la forma de la pantalla:

1. **Envío a todo el país** por correo, más **reparto propio en el valle de
   Punilla**.
2. **No hay retiro.** No hay local al que ir a buscar nada.
3. **Mercado Pago desde el día 0.**
4. **El envío se suma al precio.** El umbral de envío sin cargo queda abierto:
   todavía no se conocen los costos reales.

La forma se eligió **mirando dos maquetas navegables** con los vinos de stage —
*el remito* (todo en una pantalla) y *el mostrador* (de a un paso). Ganó **el
remito**.

## Decisión

### 1. La modalidad la decide el código postal — y nadie queda fuera de zona

No hay selector de *"¿cómo lo querés recibir?"*. El comprador escribe su código
postal y la pantalla le ofrece lo que su dirección permite: en Punilla, que se
lo llevamos nosotros; afuera, el correo a domicilio o a sucursal. Preguntárselo
sería pedirle que sepa algo que nosotros ya sabemos.

⚠️ **Esto deroga una regla del glosario.** Decía: *"Una dirección fuera de toda
zona **no puede comprar**, y se le dice antes de que cargue el carrito"*, y
`voz.md §9.3` tiene el texto escrito (*"Todavía no llegamos hasta ahí"*). Con
envío nacional **eso es falso**: a todo el país llegamos. `Zona` pasa a
significar **hasta dónde repartimos nosotros**, no hasta dónde llega el pedido,
y la pantalla de fuera de zona **no se construye**. El texto de `voz.md §9.3`
queda sin pantalla; se deja escrito por si vuelve a hacer falta.

Lo único que puede fallar es que **no sepamos el precio todavía** —un código
postal que la tabla no reconoce, o el proveedor caído—, y para eso la salida es
escribirnos, no cerrar la puerta.

### 2. El checkout vive adentro de `carrito/`, no en una feature propia

[ADR 006](006-estructura-de-la-tienda.md) dejaba `checkout/` anotado como
feature futura. **No se hizo así**, y el motivo es su propia regla 3: una
feature no importa de otra, y el checkout necesita el `localStorage` del
carrito (`almacen.ts`, `useCarrito`), su resolución contra la proyección y su
regla de la caja.

| Alternativa | Por qué no |
|---|---|
| `features/checkout/` con el almacén bajado a `shared/` | La regla 5 dice que `shared/` no sabe de vino. Un almacén que guarda `productoId` y `botellas` está en el borde, y bajarlo sólo para esquivar la regla 3 es usar `shared/` como cajón — que es exactamente lo que el ADR 006 existe para impedir |
| `features/checkout/` importando `carrito/` | Lo bloquea `frontera-features.sh`. Y con razón: serían una sola feature con dos nombres |
| Duplicar el almacén en las dos features | Dos lectores del mismo `localStorage` que se desincronizan en la primera edición |

`carrito/` pasa a tener subcarpeta, que es lo que el mismo ADR 006 manda cuando
una feature deja de entrar en una pantalla.

### 3. El puerto en contratos, el cotizador en `server/`, y la función viaja por props

`ProveedorDeEnvio` vive en `packages/contratos/src/envio.ts` con la misma forma
que `ProveedorDePago` ([ADR 003](003-pagos.md)): un puerto, y el adaptador
afuera. Hoy la única implementación es `CotizadorSimulado`, en
`apps/tienda/src/server/envios.ts`, **con números inventados y la forma real**.

⚠️ **La Server Action no se importa desde el cliente: llega por props.** El hook
`server-only-guard` bloquea que un `'use client'` importe de `src/server/`, así
que `app/pedido/page.tsx` —Server Component— le pasa `cotizarEnvio` a la
pantalla, igual que ADR 008 §5 le pasa los elementos del catálogo al carrito.
De paso queda inyectable, que es la mitad del punto de tener un puerto.

**El `useCotizacion` hace tres cosas que no son adorno**, y las tres son
plata o precio equivocado:

- **Espera 400 ms a que dejen de escribir.** "5176" son cuatro cotizaciones y
  tres se tiran; Envíopack tiene tope de 3.000 requests cada 5 minutos.
- **Descarta las respuestas viejas.** Sin el testigo, la cotización de un
  código postal anterior puede llegar después y pintar **un precio que no es el
  de esa dirección**. No falla ruidosamente: cobra mal.
- **Re-cotiza si cambian las botellas** (abajo).

### 4. La cotización va por CAJAS, no por pedido

`Σ botellas → cajas → un bulto por caja`. Doce botellas son dos cajas y pesan
el doble: cotizar siempre una sola caja era el defecto que tenía la maqueta, y
el pedido grande viajaba a precio de chico.

`CAJA_KG = 8` y `34×24×18 cm` son **estimados, no medidos** — salen de
proveedores de cajas y de una vinoteca argentina que factura por caja de 8 kg.
Un error de medio kilo es un error de precio.

El precio del segundo bulto es **sublineal** (×1,6 y no ×2): un correo cobra
por escalón de peso. El 0,6 es inventado; la forma, no.

### 5. Lo que se le pide al comprador, y lo que no

| Campo | Por qué |
|---|---|
| Nombre y apellido | Lo pide el correo (`destinatario`, máx. 50) |
| Teléfono | **Es el canal.** Se guarda en E.164 (`+549…`) |
| Email | **Opcional** — ver abajo |
| Código postal, provincia (ISO), localidad | Lo que el correo necesita para cotizar y despachar |
| Calle y **número por separado** | Separados los pide el correo. Partir `"Av. San Martín 1234"` después es adivinar dónde termina el nombre |
| Piso, referencia | Opcionales, y bajan las entregas fallidas |

**No se pide DNI** (Mercado Pago no lo necesita para Checkout Pro) ni se crea
cuenta: el checkout es sin registro y los datos viajan dentro de la Orden
(ARQUITECTURA §5.1).

⚠️ **El teléfono se normaliza a E.164 en contratos, y no es cosmética.**
`wa.me` lee los dígitos como E.164 completo: `3548412233` es, para WhatsApp, el
país **3**. Y no falla ruidosamente — abre un chat con otra persona.

### 6. El comprobante NO va por mail

Va a una **URL estable** (`/pedido/<numero>`, pendiente) y el link viaja por
**WhatsApp**, que ya es el canal que `voz.md §9.6` promete.

El problema que esto resuelve no es el mail: es que **el comprobante de la
redirección no sobrevive**. Si se cierra la pestaña, si Mercado Pago no vuelve,
si el pago se acredita veinte minutos después por Rapipago, no queda nada. Una
URL lo arregla sin infraestructura de envío, sin spam y sin una dependencia más;
el día que se quiera mail, el link ya existe y se pega adentro.

Por eso el email es un campo opcional: un segundo camino para escribirle a
alguien, no el soporte del comprobante.

### 7. El pago no es una sección: es un botón

Con Checkout Pro el comprador elige tarjeta, cuotas o efectivo **en la pantalla
de Mercado Pago**. Ofrecer un selector acá sería preguntar dos veces. La pantalla
dice qué va a pasar (*"Te llevamos y volvés acá"*) y el botón dice `Ir a pagar`.

**Y los finales son tres, no dos** — porque `status` puede volver
`approved`, `rejected` **o** `in_process`/`pending`, y un pago en efectivo tarda
días. El tercero ya tiene su estado en la máquina (`en_proceso`,
[ADR 002](002-estados-de-orden.md)): no hay que inventarlo, hay que escribirlo.

### 8. El gate, y es el sexto

`EL_CHECKOUT_NO_COBRA = true` mientras no existan las tres cosas: `crearOrden`,
la preferencia de Mercado Pago y el webhook. El botón está deshabilitado y la
pantalla lo dice con todas las letras.

Viaja al HTML como `data-checkout-simulado` porque `auditor-produccion` audita
con `curl` y no puede grepear un `.ts`:

```
grep -rn "EL_CHECKOUT_NO_COBRA" apps/tienda/src
curl -s https://<host>/pedido | grep -o data-checkout-simulado | wc -l
```

CLAUDE.md lo dice sin rodeos: *un "Pagar" que llegue antes que su webhook es una
venta que se cobra y no se registra.*

## Por qué NO las alternativas

| Alternativa | Por qué no |
|---|---|
| Checkout en pasos (la maqueta *mostrador*) | La eligió el dueño mirando las dos: perdió. Con el pago afuera quedaban dos pasos y medio, y un acordeón de dos pasos es ceremonia sin beneficio |
| Selector de "envío o retiro" | No hay retiro, y la modalidad de envío la decide el código postal |
| Pedir la dirección antes del carrito (como pedía el glosario) | Existía para poder decir "fuera de zona" antes de que alguien cargara. Ya no hay fuera de zona |
| Mostrar el nombre del correo (OCA, Andreani) | Obliga a explicar por qué esta vez es uno y la anterior otro. El dato viaja igual, para el panel |
| Cotizar en el navegador | La credencial del proveedor no puede salir del servidor |
| Cotizar al apretar un botón "calcular" | Un paso más para algo que ya sabemos hacer solos cuando el código postal está completo |
| Guardar el borrador en `localStorage` | Es una dirección y un teléfono. Que sobrevivan a un refresh no vale dejarlos escritos en el navegador de alguien |
| `precio: 0` para el envío sin cargo | Un cero afirma que no cuesta nada. Mientras no se sepa, el renglón dice *falta la dirección* |

## Presupuesto de lecturas

Campo obligatorio.

| | Lecturas |
|---:|---|
| `/pedido` por visita | **0 de más.** Comparte la entrada de `unstable_cache` con `/vinos` y `/carrito`: es la misma proyección |
| La cotización | **0 de Firestore.** Va a un proveedor externo, no a la base |
| La build | Una ruta prerenderizada más, dentro de la misma entrada de caché de 60 s. **No medido** |

⚠️ **Lo que sí cuesta es la cotización contra el proveedor**, que se paga por
request y no en lecturas: por eso el debounce de 400 ms es parte del
presupuesto, no un detalle de la interfaz.

## Consecuencias

- ⚠️ **El glosario tiene una entrada desactualizada hasta que se corrija**:
  `Zona`. Y `voz.md §9.3` queda con un texto sin pantalla.
- ⚠️ **Los códigos postales de Punilla no están verificados uno por uno.** Un CP
  mal puesto manda al reparto propio un pedido que había que despachar, y eso
  **no falla ruidosamente**: sale más barato y no llega.
- ⚠️ **`EL_CONTACTO_ES_PROVISORIO` ahora afecta a dos pantallas.** `/pedido`
  ofrece el mismo WhatsApp del desarrollador, y lo recibe por props desde
  `app/` para que la constante siga viviendo en un solo lugar.
- **El mensaje de `server-only-guard` ofrece una salida que su propia regla no
  permite.** Dice *"Para tipos usá `import type`"*, pero su expresión regular
  (`import\s+.*['\"]@/server/`) también bloquea un `import type`. No molestó en
  este cambio —la función llega por props, que es mejor—, pero el hook promete
  algo que no cumple. Arreglarlo pide un caso nuevo en `probar_hooks.sh`.
- El checkout **no** guarda nada: ni borrador, ni dirección, ni cliente. La
  primera escritura de la vidriera va a ser `crearOrden`.

## Lo que hay que medir antes de creerle a este ADR

| Qué | Cómo | Disparador |
|---|---|---|
| El peso real de una caja de 6 | Pesarla. Los 8 kg son de catálogo de proveedores | Antes del primer cobro |
| Los códigos postales de Punilla | Uno por uno contra el buscador del Correo Argentino, con un control negativo (un CP que NO es de Punilla y no debe dar reparto propio) | Antes del primer cobro |
| Que se pueda despachar alcohol | Preguntárselo a Envíopack por contacto comercial. Ningún correo lo prohíbe por escrito **y ninguno lo permite por escrito** | Antes de contratar |
| La comisión de Mercado Pago | En el panel de la cuenta real: las páginas públicas de costos devuelven 403 y las fuentes de terceros se contradicen entre 2,99 % y 6,99 % | Antes de fijar precios |
| El umbral de envío sin cargo | Con costos reales en la mano: cuál es el ticket desde el que conviene | Cuando existan las tarifas |
| La pantalla en un teléfono de verdad | Mirarla. El Chrome headless de esta máquina no baja de 504 px sin emulación | La próxima revisión del dueño |

## Cuándo esta decisión deja de servir

- Aparece un local y con él el retiro: vuelve el selector de modalidad.
- El reparto propio pasa a cobrarse por distancia y no por caja.
- Se venden cajas mixtas con peso distinto: `CAJA_KG` deja de ser una constante.
