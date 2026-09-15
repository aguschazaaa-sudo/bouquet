## Context

La vidriera vende botellas sueltas: `/vinos`, la ficha y `/carrito` funcionan
contra 20 vinos de muestra en stage, y el carrito calcula un total de cualquier
cantidad. Pero el vino viaja en cajas físicas de 6, así que **ese total no se
puede despachar**. Y `crearOrden` todavía no existe, lo que convierte esto en la
última ventana barata para meter la regla: después es una restricción de cobro
sobre un carrito que ya aprendió a prometer cualquier número.

El diseño pasó por una ronda de brainstorm que **cambió de forma dos veces**, y
las dos versiones descartadas están abajo con su motivo, porque el motivo es lo
que impide volver a proponerlas.

Restricciones que no se negocian:

- La cuota de Firestore es **50.000 lecturas/día**, y con el catálogo del MVP la
  vidriera ya se le acerca a las 250 visitas ([ADR 008](../../../docs/vault/architecture/decisions/008-catalogo-stock-y-carrito.md)).
- El catálogo se filtra **en memoria**, sin índices compuestos ([ADR 004](../../../docs/vault/architecture/decisions/004-frescura-y-lecturas.md)).
- El carrito vive en `localStorage`; no hay colección `carritos`.
- `apps/admin` son **cinco archivos Dart**: no hay panel para cargar nada.

## Goals / Non-Goals

**Goals:**

- Que no se pueda cobrar un carrito que no sea múltiplo de `BOTELLAS_POR_CAJA`.
- Que el comprador se entere **antes de agregar**, no en el carrito.
- Que el vendedor pueda ofrecer cajas armadas sin que eso cree un producto.
- Que cambiar de 6 a 3 sea una línea.
- Cero lecturas nuevas por visita.

**Non-Goals:**

- `crearOrden` y el cobro. Acá se deja la precondición escrita y probada.
- Descuentos de cualquier tipo.
- Cajas de regalo con precio propio.
- El panel para cargar cajas sugeridas.
- Que la home muestre cajas.

## Decisions

### 1. Una caja sugerida NO es un producto

Es una lista de seis `productoId` con nombre y slug. Elegirla **llena el
carrito**; desde ahí el comprador cambia lo que quiera.

El argumento es el precio: sin descuento, una caja sugerida no tiene precio
propio —es la suma de sus seis vinos—, y algo que no tiene precio propio no
necesita ser un documento en `productos`. Sin precio propio tampoco hay stock
propio que derivar, ni una caja entera que se caiga porque uno de los seis se
agotó.

| Alternativa | Por qué no |
|---|---|
| Un `compuesto` con `componentes[]`, stock derivado por `min(floor(stock/cantidad))` y precio escrito a mano | Era el diseño hasta que se decidió que **no va con descuento**. Sin descuento, el precio de la caja es la suma, y guardar una suma es guardar algo que puede contradecir a sus partes. Arrastraba: unión discriminada en la proyección, `precioDeLasPartes`, un chequeo de deriva en CI, un carril con tarjeta y ficha propias, y `componenteIds` desnormalizado para la purga |
| Precio derivado (suma menos descuento) en un producto compuesto | El precio cambiaría solo entre que el comprador lo mira y `crearOrden` lo valida. ADR 008 ya midió ~13 minutos de atraso posible |
| Reemplazar el carrito al elegir una sugerencia | Borra trabajo del comprador sin avisar |

**Consecuencia que conviene ver:** `tipo: 'compuesto'` queda en el modelo **sin
un solo uso**. Se deja a propósito — sacarlo es la migración que ADR 008 se
ahorró, y el día que exista una caja de regalo con precio propio, el campo está.

### 2. La cuenta es en botellas, no en unidades de venta

`Σ cantidad × presentacion.botellas`.

No es teórico: el catálogo de muestra ya tiene **2 productos de 2 botellas sobre
20**, así que contar unidades daría el número equivocado desde el primer día.
El modelo ya cuenta en botellas para el `balde` —*"tres cajas de 2 ya son
pocas"*—, así que esto reusa una decisión, no inventa una.

### 3. La regla NO vive en `parsearCarrito`

Es una precondición de **cobro**, no de **validez**. Un carrito de 4 botellas es
alguien comprando.

Meterla en el parser tendría un efecto que nadie quiere: `parsearCarrito`
rechaza en vez de corregir —por diseño, y está bien—, así que un carrito a medio
llenar se descartaría entero en la visita siguiente. El comprador volvería a una
tienda que le vació el changuito.

### 4. Un solo documento para las cajas sugeridas

`cajasSugeridas/publicas`, reescrito entero, con el patrón de
`metricas/popularidad`: recalculado completo para que correrlo dos veces dé lo
mismo.

| Alternativa | Por qué no |
|---|---|
| Una colección con un documento por caja | N lecturas por reconstrucción en vez de 1, para un dato que son cinco o seis entradas de tres campos |
| Adentro del documento de cada producto | Una caja no pertenece a ningún producto |

El techo de 1 MB que ADR 004 le teme a `catalogo/publico` no aplica: acá se
guardan ids y nombres, no el catálogo.

### 5. Elegir una sugerencia AGREGA, respetando el tope

Nada se borra. Si el carrito tenía 2 botellas queda con 8, y el carrito dice que
sobran 2 — que es información verdadera y accionable. Si el `tope` de un
producto corta el agregado, la caja queda incompleta **y la pantalla lo dice**,
en vez de fingir que se llenó.

Reusa `agregar`, que ya existe y ya maneja el tope.

### 6. Dónde se comunica la restricción

| Dónde | Qué |
|---|---|
| `/vinos` y la ficha | El aviso, **en el HTML servido**, sin depender de JavaScript |
| Contador de la barra | El avance: 4 de 6. Sale de `localStorage`, cero lecturas |
| `/carrito` | Faltan N **o** sobran N — el camino más corto, nunca los dos |

El aviso va una vez por listado, no por tarjeta. El texto pasa por `voz` antes
de llegar a pantalla; el dibujo del carril y del contador, por `/disenio` antes
del primer componente.

### 7. La purga por tag ya cubre el carril, sin trabajo nuevo

Una versión anterior del diseño necesitaba un `componenteIds` desnormalizado
para que el trigger de purga supiera qué cajas contenían un vino que cambió.
**Ese problema se evaporó**: el carril vive en `/vinos`, que ya lleva
`Cache-Tag: catalogo`, y cualquier edición de producto ya purga ese tag. No hace
falta índice inverso, ni campo espejo, ni índice compuesto.

### 8. Dónde va la lectura — y por qué la home no la paga

Tres condiciones, y las tres salieron del presupuesto:

1. **La lectura va adentro de `obtenerCatalogo`, NO en un `unstable_cache`
   aparte.** Un segundo `unstable_cache` con `revalidate` numérico **le baja el
   `revalidate` a la página que lo llama** — el caso `prerender-legacy` de
   `unstable-cache.js`. Si la home lo tocara, la ruta más visitada pasaría sola
   de estática a ISR de 60 s y empezaría a leer Firestore por visita, **sin un
   error ni un aviso**. Es la misma trampa que ya obligó a que exista
   `leerCatalogoSinCache`, documentada en ADR 008.
2. **`leerCatalogoSinCache` NO la incluye.** La home lo llama directo para
   hornear su selección, y no dibuja ningún carril: si la lectura viviera ahí,
   **la home pagaría por un documento que no renderiza**. Así que las cajas se
   leen en una función propia y se componen dentro del `Promise.all` de
   `obtenerCatalogo`.
3. **`/carrito` y `/vinos/[slug]` no la leen por su cuenta.** Hoy las tres rutas
   comparten una sola entrada de caché; tres lecturas sueltas harían que una
   visita que abre listado + ficha + carrito pague +3 en vez de +1.

### 9. El carril resuelve sus seis vinos EN MEMORIA

Cada caja sugerida trae seis `productoId`. Resolverlos con un `get()` por id es
el error caro de este cambio, y tiene número: con 6 cajas son **36 lecturas por
reconstrucción**, o sea hoy `32 → 68`, **más que el doble**; a 250 visitas,
**17.000/día (34 %)**; con el MVP a 250, **66.750 (133 %)**.

El join va contra la proyección que ya está en memoria, igual que los filtros
([ADR 004 §3](../../../docs/vault/architecture/decisions/004-frescura-y-lecturas.md)).
Es la misma disciplina, y acá vale 30×.

## Presupuesto de lecturas

Campo obligatorio ([CLAUDE.md](../../../CLAUDE.md), [ARQUITECTURA §6.3](../../../ARQUITECTURA.md#63-el-presupuesto-completo)).

Medido por el agente `presupuesto-lecturas`, que **corrigió el encuadre con el
que se escribió la propuesta**: no es "+1 por build, 0 por visita". Es **+1 por
reconstrucción**, y hasta el tramo 4 las reconstrucciones **escalan con las
visitas**, porque la caché de datos de Next vive en la memoria de cada instancia
de Cloud Run y no se comparte. Es el mismo modelo contable de la tabla del ADR
008 (`3.200 = 32 × 100`).

La corrección no cambia el veredicto, pero sí el modelo — y con "0 por visita"
adentro, la quinta lectura de este tipo también parecería gratis.

```
P + B + 1 (popularidad) + 1 (cajas)
hoy:  20 + 11 + 1 + 1 =  33   (era  32)
MVP: 200 + 30 + 1 + 1 = 232   (era 231)
```

| | Hoy (20/11) | MVP (200/30) |
|---|---:|---:|
| Por reconstrucción | 32 → **33** | 231 → **232** |
| 100 visitas/día | 3.200 → **3.300** (6,6 %) | 23.100 → **23.200** (46,4 %) |
| 250 visitas/día | 8.000 → **8.250** (16,5 %) | 57.750 → **58.000** (116,0 %) |

**Delta: +0,2 puntos de cuota a 100 visitas, +0,5 a 250. ENTRA.**

⚠️ **La línea del MVP a 250 visitas ya estaba en 115,5 % antes de este cambio.**
Lo lleva a 116 %. No lo rompe, pero tampoco corresponde darle el pase de "es un
documento" a un renglón que ya está fuera de cuota: ese desborde lo debe el
tramo 4, y sigue debiéndolo.

El carrito, el contador y la regla de checkout cuestan **cero**: operan sobre
`localStorage` y sobre la proyección que ya está en memoria. `botellas` ya viaja
en la proyección.

### Tres cosas que el presupuesto dejó escritas

- **La lectura se cobra exista o no el documento.** Firestore cobra 1 lectura
  por un `get()` a un documento que no está. Si esto se despliega antes de que
  el vendedor cargue una sola caja, se paga igual. El manejo ya tiene
  precedente: `leerUnidades` tolera un `metricas/popularidad` ausente.
- **Sin trigger de purga, el carril envejece igual que el precio (~13 min).**
  `functions/src/index.ts` no exporta nada todavía. Para un carril **sin precio,
  sin stock y sin foto** eso no cuesta plata — y es un argumento a favor de este
  diseño. ⚠️ Deja de valer el día que una caja lleve precio propio.
- **La escritura es 1 por edición, sin fan-out.** Un array de mapas no indexa
  los subcampos de adentro, así que no hay costo de índice escondido.

## Risks / Trade-offs

**La restricción se comunica tarde → carritos abandonados.** Es el único modo de
falla que convierte esta regla en plata perdida. *Mitigación:* el aviso es
requisito de spec y se mide sobre el HTML servido, no sobre el DOM hidratado.

**El tope corta una sugerencia y la caja queda incompleta sin explicación.**
*Mitigación:* escenario propio en la spec; la pantalla dice que quedó incompleta.

**El día que sean cajas de 3, los carritos guardados quedan en cantidades que ya
no son múltiplo.** *Mitigación:* ninguna hace falta. El carrito sigue siendo
válido —la regla no está en el parser (decisión 3)— y lo único que cambia es el
mensaje. Es el beneficio directo de esa decisión.

**Una sugerencia cuyos vinos se agotan seguido queda siempre marcada.** Es un
problema de curaduría, no de código; la sugerencia sigue sirviendo con cinco.

**`tipo: 'compuesto'` queda sin uso y el próximo que lea el modelo va a
preguntar por qué.** *Mitigación:* el comentario del tipo ya dice *"previsto, no
construido"*; se le suma el enlace a este cambio.

⚠️ **El carril resuelve sus ids con un `get()` por vino.** Es el riesgo más caro
del cambio: **32 → 68 lecturas por reconstrucción**, 133 % de la cuota con el
MVP a 250 visitas. *Mitigación:* decisión 9, y una tarea de verificación que
cuenta las lecturas contra el control de una reconstrucción sin carril.

⚠️ **Un `unstable_cache` nuevo vuelve ISR a la home sin avisar.** No falla, no
loguea, y la ruta más visitada empieza a leer Firestore por visita.
*Mitigación:* decisión 8, más el test que ya existe —`test/revalidacion.test.ts`
falla si la home importa la caché— extendido a la lectura nueva.

## Migration Plan

Orden no negociable: **reglas → front**. No toca `functions`.

1. `firestore.rules` con la colección nueva, y los tests contra el emulador con
   un caso aceptado y uno rechazado.
2. Desplegar `reglas`.
3. Sembrar las cajas sugeridas de muestra con el seed, re-ejecutable.
4. Desplegar `tienda` — **preguntándose antes qué más se mergeó**, porque el
   deploy de front reconstruye desde el HEAD pusheado.

⚠️ **La tienda hoy NO se despliega**: tiene cinco gates abiertos (reglas sin
publicar, puerta de edad, contacto provisorio, licencias de los assets, 391 KB
de fuentes). Este cambio **no agrega un sexto**, pero tampoco se publica solo:
viaja cuando se abran los que ya están.

**Rollback:** el carril y los avisos son front; revertir el deploy los saca. El
documento de cajas sugeridas puede quedar: sin código que lo lea, no cuesta ni
una lectura.

## Open Questions

- **¿Cajas de 3?** El dueño está viendo si consigue. Es una constante y sus
  tests; no cambia nada de este diseño.
- **¿Quién carga las cajas sugeridas antes de que exista el panel?** Hoy, el
  seed. El panel es otra tarea.
- **¿Se puede llevar más de una caja?** El diseño lo permite (múltiplos), y los
  escenarios de 8 y 12 botellas lo cubren. Si el dueño quiere tope de una caja
  por pedido, es un cambio de spec, no de diseño.
