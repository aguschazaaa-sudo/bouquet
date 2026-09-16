# EP-11 — Parámetros y tablero

> **Con disparador** · Workflow A, salvo **HU-11.1**, que va por **D** ·
> [volver al mapa](overview.md)

**Objetivo:** que el dueño ajuste lo que hoy es una constante en el código, y
que arranque el día sabiendo qué hay pendiente.

Cada historia lleva su propio disparador.

---

## HU-11.1 — Fijar desde qué monto el envío sale sin cargo · D

**Como** dueño, **quiero** fijar el monto desde el que no cobro el envío,
**para** empujar pedidos más grandes.

- **Disparador:** las tarifas reales del proveedor. El dueño lo dejó abierto:
  *"no sé desde qué monto me conviene"* ([`_index.md`](../../_index.md)).
- **Ya decidido:** `config` es **sólo del servidor**, creación incluida, y la
  baranda contra el dedo gordo mira el **valor nuevo**, porque en la primera
  escritura no hay anterior
  ([ARQUITECTURA §9.4](../../../../ARQUITECTURA.md#94-la-baranda-de-config-tiene-que-proteger-la-primera-escritura)).
  El panel guarda por una callable.
- **Ojo:** el checkout ya soporta `precio: 0` y lo dice con palabras, no con un
  cero ([ADR 010](../../architecture/decisions/010-el-checkout.md)).

## HU-11.2 — Ver un resumen del día

**Como** dueño, **quiero** ver al entrar cuántos pedidos hay por preparar,
cuántos pagos siguen en proceso y qué se agotó, **para** arrancar el día.

- **Disparador:** que la lista de pedidos (HU-06.1) no alcance para eso.
- **Presupuesto:** los conteos de agregación cobran **una lectura cada 1.000
  documentos contados**, así que tres contadores son unas pocas lecturas por
  apertura. Lo agotado sale del catálogo en memoria, gratis. Se cuantifica en
  el ADR.

## HU-11.3 — Ver qué se vende más

**Como** dueño, **quiero** ver qué vinos se venden más, **para** decidir qué
reponer y qué destacar.

- **Disparador:** que exista el job que calcula la popularidad. Hoy
  `metricas/popularidad` la escribe **sólo el seed**, marcada
  `simulada: true` ([glosario](../../domain/glossary.md)).
- **Ya decidido:** mostrar un ranking sobre datos que no se miden es mentirle a
  quien lo lee (§8.3). Hasta el job, esta pantalla no existe.
- **Presupuesto:** una lectura; es un solo documento.
