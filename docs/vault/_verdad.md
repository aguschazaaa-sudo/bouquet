# _verdad.md - lo que el codigo hace hoy

> ## AVISO: ARCHIVO GENERADO. NO SE EDITA A MANO.
>
> Lo produce `scripts/ci/generar_verdad.mjs` leyendo el repo. Cualquier
> edicion a mano se pierde en la proxima corrida y hace fallar el CI.
>
> ```
> node scripts/ci/generar_verdad.mjs .           # regenerar
> node scripts/ci/generar_verdad.mjs . --check   # exit 1 si difiere
> ```
>
> [`_index.md`](_index.md) documenta la **INTENCION**. Este archivo documenta el
> **COMPORTAMIENTO**, derivado del codigo. **La diferencia entre los dos es la
> deuda del proyecto, medida.** Si se contradicen, este tiene razon.
>
> Sin tildes a proposito: lo escribe un script, como todo lo de `scripts/ci/`.
> **Generado:** 2026-09-22 - commit `7c93581` **+ cambios sin commitear** - huella del cuerpo `98655b1b38d1`

---

## 1. La maquina de estados de Orden

Fuente: `packages/contratos/generated/contratos.json` (version 1), emitido por `packages/contratos/scripts/generar.mjs`. Que ese JSON este FRESCO lo verifica `scripts/ci/auditar_estados.mjs`; este archivo solo lo lee.

### Eje pago - 5 estados

| Estado | Nace ahi | Transiciona a |
|---|---|---|
| `pendiente` | SI | `en_proceso`, `pagada`, `rechazada` |
| `en_proceso` |  | `pagada`, `rechazada` |
| `pagada` | SI | `reembolsada` |
| `rechazada` |  | `en_proceso`, `pagada` |
| `reembolsada` |  | **terminal** |

Nace en: `pendiente`, `pagada`. Terminales: `reembolsada`.

### Eje entrega - 6 estados

| Estado | Nace ahi | Transiciona a |
|---|---|---|
| `sin_preparar` | SI | `preparando`, `cancelada` |
| `preparando` |  | `despachada`, `cancelada` |
| `despachada` |  | `entregada`, `fallida` |
| `entregada` |  | **terminal** |
| `fallida` |  | `despachada` |
| `cancelada` |  | **terminal** |

Nace en: `sin_preparar`. Terminales: `entregada`, `cancelada`.

### Proyeccion - 30 pares sobre 30 posibles

| Estado publico | Pares que lo producen | Requiere accion | Rotulo cliente | Rotulo operador |
|---|---|---|---|---|
| `recibida` | 1 |  | Pedido recibido | Recibida - falta cobrar |
| `confirmando` | 3 |  | Confirmando... | Pago en proceso |
| `pago_rechazado` | 3 |  | No pudimos cobrar el pago | Pago rechazado |
| `pagada` | 1 | SI | Pago acreditado | Pagada - falta preparar |
| `en_preparacion` | 2 |  | Preparando tu pedido | En preparacion |
| `en_camino` | 2 |  | En camino | Despachada |
| `entregada` | 1 |  | Entregado | Entregada |
| `entregada_impaga` | 4 | SI | Entregado | ENTREGADA SIN COBRAR |
| `no_entregada` | 5 | SI | No pudimos entregarlo | Entrega fallida - reprogramar |
| `cancelada` | 3 |  | Pedido cancelado | Cancelada |
| `cancelada_con_pago` | 1 | SI | Pedido cancelado | CANCELADA CON PAGO - devolver |
| `reembolsada` | 4 |  | Pedido cancelado y reintegrado | Reembolsada |

Todos los estados publicos son alcanzables: cada uno lo produce al menos un par.

## 2. Paquetes del workspace

| Paquete | Version | Ruta | Scripts |
|---|---|---|---|
| `@bouquet/contratos` | 0.1.0 | `packages/contratos` | `test`, `generar` |
| `@bouquet/tienda` | 0.1.0 | `apps/tienda` | `dev`, `build`, `start`, `typecheck`, `test` |
| `@bouquet/functions` | 0.1.0 | `functions` | `construir`, `tipos`, `test` |

### Scripts de la raiz - `bouquet` 0.27.1

| Script | Comando |
|---|---|
| `test` | `npm test --workspaces --if-present` |
| `tipos` | `tsc --noEmit --project packages/contratos && tsc --noEmit --project functions && tsc --noEmit --project apps/tienda` |
| `contratos:generar` | `npm run -w @bouquet/contratos generar` |
| `verdad` | `node scripts/ci/generar_verdad.mjs .` |
| `verificar` | `npm run tipos && npm test && node scripts/ci/auditar_estados.mjs && node scripts/ci/verificar_enlaces.mjs . && node scripts/ci/generar_verdad.mjs . --check && bash scripts/hooks/probar_hooks.sh` |

Dependencias declaradas en la raiz: `@firebase/rules-unit-testing`, `@fission-ai/openspec`, `@types/node`, `typescript`. Node exigido: `>=22.18`.

## 3. Tests - contados, no declarados

| Archivo | Casos |
|---|---|
| `apps/admin/test/app/destino_test.dart` | 26 |
| `apps/admin/test/core/contratos/catalogo_publico_test.dart` | 8 |
| `apps/admin/test/core/contratos/estados_orden_test.dart` | 9 |
| `apps/admin/test/core/contratos/plata_test.dart` | 4 |
| `apps/admin/test/core/contratos/texto_test.dart` | 8 |
| `apps/admin/test/features/acceso/sesion_test.dart` | 11 |
| `apps/admin/test/features/catalogo/borrador_de_vino_test.dart` | 35 |
| `apps/admin/test/features/catalogo/cambio_de_precio_test.dart` | 12 |
| `apps/admin/test/features/catalogo/catalogo_test.dart` | 20 |
| `apps/admin/test/features/catalogo/documento_del_vino_test.dart` | 10 |
| `apps/admin/test/features/catalogo/en_la_tienda_test.dart` | 18 |
| `apps/admin/test/features/catalogo/numeros_escritos_test.dart` | 10 |
| `apps/tienda/test/almacen.test.ts` | 1 |
| `apps/tienda/test/envios.test.ts` | 13 |
| `apps/tienda/test/filtros.test.ts` | 10 |
| `apps/tienda/test/revalidacion.test.ts` | 5 |
| `apps/tienda/test/seleccion.test.ts` | 5 |
| `packages/contratos/test/caja.test.ts` | 30 |
| `packages/contratos/test/cajas.test.ts` | 34 |
| `packages/contratos/test/carrito.test.ts` | 20 |
| `packages/contratos/test/dinero.test.ts` | 7 |
| `packages/contratos/test/envio.test.ts` | 27 |
| `packages/contratos/test/orden.test.ts` | 13 |
| `packages/contratos/test/producto.test.ts` | 33 |
| `packages/contratos/test/proyeccion.test.ts` | 6 |
| `packages/contratos/test/texto.test.ts` | 15 |
| `scripts/acceso/acceso.test.mjs` | 11 |
| `scripts/reglas/productos.test.mjs` | 54 |
| **total** | **455** |

Conteo lexico de `test(` e `it(`. Se cuenta y no se escribe porque el `_index.md` del proyecto anterior decia 1929 cuando el runner iba por 2003. No incluye `test.skip(` ni `test.only(`: un test salteado no es un test que corre.

## 4. Hooks activos

Leidos de `.claude/settings.json`, que es lo que el harness ejecuta de verdad.

| Evento | Matcher | Script | Timeout | El script existe |
|---|---|---|---|---|
| PreToolUse | `Edit\|Write` | `scripts/hooks/vault-precheck.sh` | 10s | si |
| PostToolUse | `Edit\|Write` | `scripts/hooks/widget-size-guard.sh` | 10s | si |
| PostToolUse | `Edit\|Write` | `scripts/hooks/layer-boundary.sh` | 10s | si |
| PostToolUse | `Edit\|Write` | `scripts/hooks/server-only-guard.sh` | 10s | si |
| PostToolUse | `Edit\|Write` | `scripts/hooks/frontera-features.sh` | 10s | si |
| PostToolUse | `Edit\|Write` | `scripts/hooks/one-widget-per-file.sh` | 10s | si |
| PostToolUse | `Edit\|Write` | `scripts/hooks/no-hardcoded-colors.sh` | 10s | si |
| PostToolUse | `Edit\|Write` | `scripts/hooks/call-site-guard.sh` | 30s | si |
| Stop | `(todos)` | `scripts/hooks/post-task-reminder.sh` | 10s | si |
| Stop | `(todos)` | `scripts/hooks/doc-reminder.sh` | 10s | si |
| Stop | `(todos)` | `scripts/hooks/commit-reminder.sh` | 10s | si |

Los 11 hooks apuntan a scripts que existen. Que existan no prueba que midan: eso lo prueba `bash scripts/hooks/probar_hooks.sh`.

### Permisos del harness

- **deny**: `Bash(flutter analyze:*)`, `Bash(flutter test:*)`, `Bash(flutter build:*)`, `PowerShell(flutter analyze:*)`, `PowerShell(flutter test:*)`, `PowerShell(flutter build:*)`, `Bash(npx jest:*)`, `PowerShell(npx jest:*)`, `PowerShell(firebase deploy:*)`
- **ask**: `Bash(gh workflow run:*)`, `Bash(gh run rerun:*)`, `Bash(git push:*)`, `PowerShell(git push:*)`
- **allow**: -

Se listan porque `SKILLS-AGENTES-MCP.md` 5 documenta el caso contrario: un `CLAUDE.md` que prohibia lo que el allowlist pre-aprobaba. **La configuracion le gana al documento, siempre.**

## 5. Subagentes

El `tools:` del frontmatter es **enforcement estructural**: restringe herramientas, no rutas. Un agente sin `Edit` ni `Write` no puede escribir, y eso si es real. Las fronteras por ruta las miden los hooks, no el frontmatter.

| Agente | Modelo | Escribe | Tools |
|---|---|---|---|
| `admin-datos` | sonnet | si | `Read`, `Grep`, `Glob`, `Edit`, `Write`, `Bash` |
| `admin-presentacion` | sonnet | si | `Read`, `Grep`, `Glob`, `Edit`, `Write`, `Bash` |
| `auditor-produccion` | sonnet | **NO - verificador** | `Read`, `Grep`, `Glob`, `Bash` |
| `cazador-de-puertas` | sonnet | **NO - verificador** | `Read`, `Grep`, `Glob`, `Bash` |
| `contratos` | opus | si | `Read`, `Grep`, `Glob`, `Edit`, `Write`, `Bash` |
| `functions` | opus | si | `Read`, `Grep`, `Glob`, `Edit`, `Write`, `Bash` |
| `presupuesto-lecturas` | opus | **NO - verificador** | `Read`, `Grep`, `Glob`, `Bash` |
| `reglas` | opus | si | `Read`, `Grep`, `Glob`, `Edit`, `Write`, `Bash` |
| `revisor-acoplamiento` | opus | **NO - verificador** | `Read`, `Grep`, `Glob`, `Bash` |
| `revisor-pagos` | opus | **NO - verificador** | `Read`, `Grep`, `Glob`, `Bash` |
| `tienda` | sonnet | si | `Read`, `Grep`, `Glob`, `Edit`, `Write`, `Bash` |
| `vault` | sonnet | si | `Read`, `Grep`, `Glob`, `Edit`, `Write` |
| `voz` | sonnet | si | `Read`, `Grep`, `Glob`, `Edit`, `Write` |

**13 subagentes: 8 escriben, 5 verifican sin `Edit` ni `Write`** (`auditor-produccion`, `cazador-de-puertas`, `presupuesto-lecturas`, `revisor-acoplamiento`, `revisor-pagos`).

Escriben pero no tienen `Bash`, o sea que no pueden desplegar ni commitear: `vault`, `voz`.

## 6. Skills declaradas

**28 skills de terceros**, declaradas en `skills-lock.json` con su hash y **no commiteadas** (`.gitignore` ignora `.claude/skills/*`). Restaurar en un clon: `bash scripts/skills_restaurar.sh`.

| Origen | Cuantas | Cuales |
|---|---|---|
| `anthropics/skills` | 5 | `brand-guidelines`, `canvas-design`, `frontend-design`, `theme-factory`, `webapp-testing` |
| `firebase/agent-skills` | 2 | `firebase-firestore`, `firebase-security-rules-auditor` |
| `fission-ai/openspec` | 12 | `openspec-apply-change`, `openspec-archive-change`, `openspec-bulk-archive-change`, `openspec-continue-change`, `openspec-explore`, `openspec-ff-change`, `openspec-new-change`, `openspec-onboard`, `openspec-propose`, `openspec-sync-specs`, `openspec-update-change`, `openspec-verify-change` |
| `mercadopago/mercadopago-claude-marketplace` | 2 | `mp-integrate`, `mp-webhooks` |
| `obra/superpowers` | 1 | `brainstorming` |
| `vercel-labs/agent-skills` | 6 | `vercel-composition-patterns`, `vercel-optimize`, `vercel-react-best-practices`, `vercel-react-view-transitions`, `web-design-guidelines`, `writing-guidelines` |

Propias del proyecto, commiteadas porque mencionan nuestro dominio: `brainstorm-bouquet`, `commit`, `post-task-doc`.

## 7. Simbolos publicos y quien los abre

La seccion que mas vale. Por cada simbolo exportado por `packages/contratos/src/index.ts`, **quien lo referencia** fuera de su propio modulo. Un simbolo cuyo unico consumidor es su test esta escrito, no entregado: es el modo de falla que se repitio cuatro veces en seis meses en el proyecto anterior.

Se buscan referencias en `.ts .tsx .js .jsx .mjs .cjs` del repo entero. El panel en Dart NO importa TypeScript: lo espeja via `generated/contratos.json`, asi que no cuenta como consumidor aca aunque exista.

| Simbolo | Clase | Estado | Quien lo abre |
|---|---|---|---|
| `ESTADOS_PAGO` | valor | solo el generador | `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/orden.test.ts`, `packages/contratos/test/proyeccion.test.ts` |
| `EstadoPago` | tipo | **SIN PUERTA - solo tests** | `packages/contratos/test/orden.test.ts` |
| `NACE_PAGO` | valor | solo el generador | `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/orden.test.ts` |
| `TRANSICIONES_PAGO` | valor | solo el generador | `packages/contratos/scripts/generar.mjs` |
| `ESTADOS_ENTREGA` | valor | solo el generador | `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/orden.test.ts`, `packages/contratos/test/proyeccion.test.ts` |
| `EstadoEntrega` | tipo | **SIN PUERTA - solo tests** | `packages/contratos/test/orden.test.ts` |
| `NACE_ENTREGA` | valor | solo el generador | `packages/contratos/scripts/generar.mjs` |
| `TRANSICIONES_ENTREGA` | valor | solo el generador | `packages/contratos/scripts/generar.mjs` |
| `transicionPagoValida` | funcion | **SIN PUERTA - solo tests** | `packages/contratos/test/orden.test.ts` |
| `transicionEntregaValida` | funcion | **SIN PUERTA - solo tests** | `packages/contratos/test/orden.test.ts` |
| `entroEn` | funcion | abierto | `functions/src/index.ts`, `packages/contratos/test/orden.test.ts` |
| `entroEnPagada` | valor | abierto | `functions/src/index.ts`, `packages/contratos/test/orden.test.ts` |
| `entroEnReembolsada` | valor | **SIN PUERTA - solo tests** | `packages/contratos/test/orden.test.ts` |
| `entroEnDespachada` | valor | **SIN PUERTA - solo tests** | `packages/contratos/test/orden.test.ts` |
| `entroEnEntregada` | valor | **SIN PUERTA - solo tests** | `packages/contratos/test/orden.test.ts` |
| `entroEnCancelada` | valor | **SIN PUERTA - solo tests** | `packages/contratos/test/orden.test.ts` |
| `ESTADOS_PUBLICOS` | valor | solo el generador | `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/proyeccion.test.ts` |
| `EstadoPublico` | tipo | **SIN PUERTA - nadie** | - |
| `proyectarEstadoPublico` | funcion | solo el generador | `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/proyeccion.test.ts` |
| `ROTULOS` | valor | solo el generador | `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/proyeccion.test.ts` |
| `REQUIEREN_ACCION` | valor | solo el generador | `packages/contratos/scripts/generar.mjs` |
| `Centavos` | tipo | abierto | `apps/tienda/src/features/carrito/checkout/ElResumen.tsx`, `apps/tienda/src/features/catalogo/TarjetaDeCajaSugerida.tsx`, `apps/tienda/src/shared/ui/Precio.tsx` |
| `centavos` | funcion | abierto | `apps/tienda/src/features/carrito/LineaDelCarrito.tsx`, `apps/tienda/src/features/carrito/TotalDelCarrito.tsx`, `apps/tienda/src/features/carrito/checkout/ElResumen.tsx`, `apps/tienda/src/features/catalogo/FichaDeVino.tsx`, `apps/tienda/src/features/catalogo/TarjetaDeCajaSugerida.tsx`, `apps/tienda/src/features/catalogo/TarjetaDeVino.tsx`, `apps/tienda/src/server/envios.ts`, `apps/tienda/src/shared/ui/Precio.tsx`, `apps/tienda/test/envios.test.ts`, `apps/tienda/test/filtros.test.ts`, `apps/tienda/test/seleccion.test.ts`, `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/caja.test.ts`, `packages/contratos/test/cajas.test.ts`, `packages/contratos/test/carrito.test.ts`, `packages/contratos/test/dinero.test.ts`, `packages/contratos/test/envio.test.ts`, `scripts/ci/auditar_estados.mjs` |
| `CERO` | valor | **SIN PUERTA - solo tests** | `packages/contratos/test/caja.test.ts` |
| `desdePesos` | funcion | **SIN PUERTA - solo tests** | `packages/contratos/test/carrito.test.ts`, `packages/contratos/test/dinero.test.ts` |
| `sumar` | funcion | abierto | `apps/tienda/src/features/carrito/textos.ts`, `apps/tienda/src/features/catalogo/TarjetaDeCajaSugerida.tsx`, `apps/tienda/src/server/envios.ts`, `packages/contratos/test/dinero.test.ts` |
| `porCantidad` | funcion | **SIN PUERTA - solo tests** | `packages/contratos/test/dinero.test.ts` |
| `formatearARS` | funcion | abierto | `apps/tienda/src/features/carrito/checkout/OpcionDeEntrega.tsx`, `apps/tienda/src/shared/ui/Precio.tsx`, `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/dinero.test.ts` |
| `MONTOS_DE_MUESTRA` | valor | solo el generador | `packages/contratos/scripts/generar.mjs` |
| `TIPOS_DE_PRODUCTO` | valor | **SIN PUERTA - nadie** | - |
| `TipoDeProducto` | tipo | **SIN PUERTA - nadie** | - |
| `COLORES` | valor | abierto | `apps/tienda/src/app/carrito/page.tsx`, `apps/tienda/src/app/layout.tsx`, `apps/tienda/src/app/pedido/page.tsx`, `apps/tienda/src/features/catalogo/PestanasDeColor.tsx`, `apps/tienda/src/features/catalogo/filtros.ts`, `apps/tienda/src/features/landing/seleccion.ts`, `apps/tienda/src/shared/tokens/colores.ts` |
| `Color` | tipo | abierto | `apps/tienda/src/features/catalogo/PestanasDeColor.tsx`, `apps/tienda/src/features/catalogo/filtros.ts`, `apps/tienda/src/features/catalogo/textos.ts`, `apps/tienda/src/features/landing/seleccion.ts` |
| `VARIETALES` | valor | abierto | `packages/contratos/test/producto.test.ts`, `scripts/ci/auditar_varietales.mjs` |
| `Varietal` | tipo | abierto | `apps/tienda/src/features/landing/seleccion.ts` |
| `GRADUACION_MINIMA` | valor | abierto | `scripts/ci/auditar_varietales.mjs` |
| `GRADUACION_MAXIMA` | valor | abierto | `scripts/ci/auditar_varietales.mjs` |
| `DESCRIPCION_MAXIMA` | valor | abierto | `packages/contratos/test/producto.test.ts`, `scripts/ci/auditar_varietales.mjs` |
| `FichaVino` | tipo | **SIN PUERTA - nadie** | - |
| `ProductoSimple` | tipo | **SIN PUERTA - nadie** | - |
| `ProductoCompuesto` | tipo | **SIN PUERTA - nadie** | - |
| `Producto` | tipo | abierto | `apps/tienda/src/features/navegacion/secciones.ts`, `packages/contratos/test/producto.test.ts` |
| `BALDES` | valor | solo el generador | `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/producto.test.ts` |
| `Balde` | tipo | **SIN PUERTA - nadie** | - |
| `UMBRAL_QUEDAN_POCAS` | valor | solo el generador | `packages/contratos/scripts/generar.mjs` |
| `TOPE_POR_PEDIDO` | valor | solo el generador | `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/producto.test.ts` |
| `viajaSolo` | funcion | **SIN PUERTA - solo tests** | `packages/contratos/test/producto.test.ts` |
| `balde` | funcion | abierto | `apps/tienda/src/app/carrito/page.tsx`, `apps/tienda/src/features/carrito/LineaDelCarrito.tsx`, `apps/tienda/src/features/catalogo/EstadoDelVino.tsx`, `apps/tienda/src/features/catalogo/FichaDeVino.tsx`, `apps/tienda/src/features/catalogo/TarjetaDeVino.tsx`, `apps/tienda/src/features/catalogo/filtros.ts`, `apps/tienda/src/features/catalogo/textos.ts`, `apps/tienda/src/features/landing/seleccion.ts`, `apps/tienda/test/filtros.test.ts`, `apps/tienda/test/seleccion.test.ts`, `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/caja.test.ts`, `packages/contratos/test/cajas.test.ts`, `packages/contratos/test/carrito.test.ts`, `packages/contratos/test/producto.test.ts`, `scripts/ci/auditar_estados.mjs` |
| `tope` | funcion | abierto | `apps/tienda/src/app/vinos/[slug]/page.tsx`, `apps/tienda/src/app/vinos/page.tsx`, `apps/tienda/src/features/carrito/ControlDeCaja.tsx`, `apps/tienda/src/features/carrito/ControlDeCompra.tsx`, `apps/tienda/src/features/carrito/LineaDelCarrito.tsx`, `apps/tienda/src/features/carrito/PaginaDelCarrito.tsx`, `apps/tienda/test/filtros.test.ts`, `apps/tienda/test/seleccion.test.ts`, `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/caja.test.ts`, `packages/contratos/test/cajas.test.ts`, `packages/contratos/test/carrito.test.ts`, `packages/contratos/test/producto.test.ts`, `scripts/ci/auditar_estados.mjs`, `scripts/ci/auditar_varietales.mjs`, `scripts/reglas/productos.test.mjs` |
| `textoDelBalde` | funcion | abierto | `apps/tienda/src/features/carrito/LineaDelCarrito.tsx`, `apps/tienda/src/features/catalogo/EstadoDelVino.tsx`, `apps/tienda/src/features/catalogo/textos.ts`, `packages/contratos/test/producto.test.ts` |
| `esCorte` | funcion | abierto | `apps/tienda/src/features/catalogo/DatosDelVino.tsx`, `apps/tienda/src/features/catalogo/HojaDelVino.tsx`, `apps/tienda/src/features/catalogo/ListadoDeVinos.tsx`, `apps/tienda/src/features/catalogo/filtros.ts`, `apps/tienda/src/features/catalogo/textos.ts`, `apps/tienda/src/features/landing/seleccion.ts`, `apps/tienda/test/filtros.test.ts`, `apps/tienda/test/seleccion.test.ts`, `packages/contratos/test/caja.test.ts`, `packages/contratos/test/cajas.test.ts`, `packages/contratos/test/carrito.test.ts`, `packages/contratos/test/producto.test.ts` |
| `Validacion` | tipo | abierto | `apps/tienda/src/features/carrito/checkout/borrador.ts` |
| `validarProducto` | funcion | abierto | `packages/contratos/test/producto.test.ts`, `scripts/seed/seed.mjs` |
| `ProductoPublicado` | tipo | abierto | `apps/tienda/src/features/carrito/PaginaDelCarrito.tsx`, `apps/tienda/src/features/carrito/checkout/PaginaDelCheckout.tsx`, `apps/tienda/src/features/catalogo/DatosDelVino.tsx`, `apps/tienda/src/features/catalogo/EstadoDelVino.tsx`, `apps/tienda/src/features/catalogo/FichaDeVino.tsx`, `apps/tienda/src/features/catalogo/HojaDelVino.tsx`, `apps/tienda/src/features/catalogo/ListadoDeVinos.tsx`, `apps/tienda/src/features/catalogo/NotaDelVino.tsx`, `apps/tienda/src/features/catalogo/PanelDeFiltros.tsx`, `apps/tienda/src/features/catalogo/PestanasDeColor.tsx`, `apps/tienda/src/features/catalogo/SinResultados.tsx`, `apps/tienda/src/features/catalogo/TarjetaDeVino.tsx`, `apps/tienda/src/features/catalogo/VentanaDeBotella.tsx`, `apps/tienda/src/features/catalogo/filtros.ts`, `apps/tienda/src/features/catalogo/textos.ts`, `apps/tienda/src/features/landing/seleccion.ts`, `apps/tienda/test/filtros.test.ts`, `apps/tienda/test/seleccion.test.ts`, `packages/contratos/test/caja.test.ts`, `packages/contratos/test/cajas.test.ts`, `packages/contratos/test/carrito.test.ts` |
| `proyectarProducto` | funcion | **SIN PUERTA - nadie** | - |
| `DocumentoCrudo` | tipo | abierto | `apps/tienda/src/server/catalogo.ts`, `packages/contratos/test/producto.test.ts` |
| `Descarte` | tipo | **SIN PUERTA - nadie** | - |
| `Catalogo` | tipo | abierto | `apps/tienda/src/server/catalogo.ts` |
| `CatalogoArmado` | tipo | **SIN PUERTA - nadie** | - |
| `armarCatalogo` | funcion | abierto | `apps/tienda/src/server/catalogo.ts`, `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/producto.test.ts`, `scripts/ci/auditar_estados.mjs` |
| `CasoDeBalde` | tipo | **SIN PUERTA - nadie** | - |
| `CASOS_DE_BALDE` | valor | solo el generador | `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/producto.test.ts` |
| `CLASES_DE_DESCARTE` | valor | solo el generador | `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/producto.test.ts` |
| `ClaseDeDescarte` | tipo | **SIN PUERTA - nadie** | - |
| `CasoDeDescarte` | tipo | **SIN PUERTA - nadie** | - |
| `BODEGAS_DE_MUESTRA` | valor | solo el generador | `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/producto.test.ts` |
| `CASOS_DE_DESCARTE` | valor | solo el generador | `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/producto.test.ts` |
| `VERSION_DEL_CARRITO` | valor | **SIN PUERTA - nadie** | - |
| `LineaDeCarrito` | tipo | **SIN PUERTA - nadie** | - |
| `ProductoDelCarrito` | tipo | **SIN PUERTA - nadie** | - |
| `Carrito` | tipo | abierto | `apps/tienda/src/app/carrito/page.tsx`, `apps/tienda/src/features/carrito/almacen.ts`, `apps/tienda/src/features/carrito/useCarrito.ts`, `apps/tienda/src/features/navegacion/secciones.ts`, `packages/contratos/test/caja.test.ts`, `packages/contratos/test/carrito.test.ts` |
| `esProductoId` | valor | **SIN PUERTA - nadie** | - |
| `parsearCarrito` | funcion | abierto | `apps/tienda/src/features/carrito/almacen.ts`, `apps/tienda/test/almacen.test.ts`, `packages/contratos/test/caja.test.ts`, `packages/contratos/test/carrito.test.ts` |
| `carritoVacio` | funcion | abierto | `apps/tienda/src/features/carrito/almacen.ts`, `apps/tienda/test/almacen.test.ts`, `packages/contratos/test/caja.test.ts`, `packages/contratos/test/carrito.test.ts` |
| `Cambio` | tipo | **SIN PUERTA - nadie** | - |
| `fijarCantidad` | funcion | abierto | `apps/tienda/src/features/carrito/ControlDeCompra.tsx`, `packages/contratos/test/carrito.test.ts` |
| `agregar` | funcion | abierto | `apps/tienda/src/features/carrito/ControlDeCaja.tsx`, `apps/tienda/src/features/carrito/ControlDeCompra.tsx`, `apps/tienda/src/features/carrito/EstadoDeLaCaja.tsx`, `apps/tienda/src/features/carrito/textos.ts`, `apps/tienda/src/features/catalogo/FichaDeVino.tsx`, `packages/contratos/test/caja.test.ts`, `packages/contratos/test/carrito.test.ts`, `scripts/ci/auditar_estados.mjs`, `scripts/reglas/productos.test.mjs` |
| `quitar` | funcion | abierto | `apps/tienda/src/features/carrito/ControlDeCompra.tsx`, `apps/tienda/src/features/carrito/LineaDelCarrito.tsx`, `apps/tienda/src/features/carrito/PaginaDelCarrito.tsx`, `apps/tienda/src/features/carrito/textos.ts`, `packages/contratos/test/carrito.test.ts`, `scripts/acceso/acceso.mjs`, `scripts/acceso/acceso.test.mjs`, `scripts/reglas/productos.test.mjs` |
| `unidadesEnCarrito` | funcion | **SIN PUERTA - solo tests** | `packages/contratos/test/caja.test.ts`, `packages/contratos/test/carrito.test.ts` |
| `ESTADOS_DE_LINEA` | valor | **SIN PUERTA - nadie** | - |
| `EstadoDeLinea` | tipo | **SIN PUERTA - nadie** | - |
| `LineaResuelta` | tipo | abierto | `apps/tienda/src/features/carrito/LineaDelCarrito.tsx` |
| `CarritoResuelto` | tipo | abierto | `apps/tienda/src/features/carrito/EstadoDeLaCaja.tsx`, `apps/tienda/src/features/carrito/TotalDelCarrito.tsx`, `apps/tienda/src/features/carrito/checkout/ElResumen.tsx` |
| `resolverCarrito` | funcion | abierto | `apps/tienda/src/features/carrito/ControlDeCaja.tsx`, `apps/tienda/src/features/carrito/PaginaDelCarrito.tsx`, `apps/tienda/src/features/carrito/TotalDelCarrito.tsx`, `apps/tienda/src/features/carrito/checkout/PaginaDelCheckout.tsx`, `packages/contratos/test/caja.test.ts`, `packages/contratos/test/cajas.test.ts`, `packages/contratos/test/carrito.test.ts` |
| `BOTELLAS_POR_CAJA` | valor | abierto | `apps/tienda/src/features/catalogo/ReglaDeLaCaja.tsx`, `packages/contratos/test/caja.test.ts`, `packages/contratos/test/envio.test.ts` |
| `botellasEnCarrito` | funcion | abierto | `apps/tienda/src/features/carrito/TotalDelCarrito.tsx`, `apps/tienda/src/features/carrito/checkout/PaginaDelCheckout.tsx`, `packages/contratos/test/caja.test.ts`, `packages/contratos/test/cajas.test.ts` |
| `botellasSueltas` | funcion | **SIN PUERTA - solo tests** | `packages/contratos/test/caja.test.ts`, `packages/contratos/test/cajas.test.ts` |
| `botellasGuardadas` | funcion | abierto | `apps/tienda/src/features/carrito/ContadorDelCarrito.tsx`, `packages/contratos/test/caja.test.ts` |
| `botellasSueltasGuardadas` | funcion | abierto | `apps/tienda/src/features/carrito/ContadorDelCarrito.tsx`, `packages/contratos/test/caja.test.ts` |
| `CargaDelPedido` | tipo | abierto | `apps/tienda/src/features/carrito/checkout/useCotizacion.ts`, `apps/tienda/src/server/envios.ts`, `apps/tienda/test/envios.test.ts`, `packages/contratos/test/envio.test.ts` |
| `cargaDelPedido` | funcion | abierto | `apps/tienda/src/features/carrito/EstadoDeLaCaja.tsx`, `apps/tienda/src/features/carrito/checkout/PaginaDelCheckout.tsx`, `packages/contratos/test/caja.test.ts` |
| `EstadoDeLaCaja` | tipo | abierto | `apps/tienda/src/features/carrito/EstadoDeLaCaja.tsx`, `apps/tienda/src/features/carrito/PaginaDelCarrito.tsx` |
| `contarCaja` | funcion | abierto | `apps/tienda/src/features/carrito/ContadorDelCarrito.tsx`, `packages/contratos/test/caja.test.ts` |
| `estadoDeLaCaja` | funcion | abierto | `apps/tienda/src/features/carrito/EstadoDeLaCaja.tsx`, `apps/tienda/src/features/carrito/TotalDelCarrito.tsx`, `packages/contratos/test/caja.test.ts`, `packages/contratos/test/cajas.test.ts` |
| `sePuedeCobrar` | funcion | abierto | `apps/tienda/src/features/carrito/PaginaDelCarrito.tsx`, `apps/tienda/src/features/carrito/checkout/PaginaDelCheckout.tsx`, `packages/contratos/test/caja.test.ts`, `packages/contratos/test/cajas.test.ts` |
| `LineaDePedido` | tipo | **SIN PUERTA - nadie** | - |
| `PedidoDeCompra` | tipo | **SIN PUERTA - solo tests** | `packages/contratos/test/carrito.test.ts` |
| `CajaSugerida` | tipo | **SIN PUERTA - solo tests** | `packages/contratos/test/cajas.test.ts` |
| `CajasArmadas` | tipo | **SIN PUERTA - nadie** | - |
| `validarCajasSugeridas` | funcion | abierto | `apps/tienda/src/server/catalogo.ts`, `packages/contratos/test/cajas.test.ts`, `scripts/seed/seed.mjs` |
| `verificarComposicion` | funcion | abierto | `packages/contratos/test/cajas.test.ts`, `scripts/seed/seed.mjs` |
| `ESTADOS_DE_LUGAR` | valor | **SIN PUERTA - nadie** | - |
| `EstadoDeLugar` | tipo | **SIN PUERTA - nadie** | - |
| `LugarDeCaja` | tipo | **SIN PUERTA - nadie** | - |
| `CajaSugeridaResuelta` | tipo | abierto | `apps/tienda/src/features/carrito/ControlDeCaja.tsx`, `apps/tienda/src/features/catalogo/CarrilDeCajas.tsx`, `apps/tienda/src/features/catalogo/TarjetaDeCajaSugerida.tsx`, `apps/tienda/src/server/catalogo.ts` |
| `CajasResueltas` | tipo | **SIN PUERTA - nadie** | - |
| `resolverCajasSugeridas` | funcion | abierto | `apps/tienda/src/server/catalogo.ts`, `packages/contratos/test/cajas.test.ts` |
| `llenarConLaCaja` | funcion | abierto | `apps/tienda/src/features/carrito/ControlDeCaja.tsx`, `packages/contratos/test/cajas.test.ts` |
| `CAJA_KG` | valor | abierto | `apps/tienda/src/server/envios.ts`, `packages/contratos/test/envio.test.ts` |
| `Bulto` | tipo | abierto | `apps/tienda/src/server/envios.ts` |
| `pesoDelBultoKg` | funcion | **SIN PUERTA - solo tests** | `packages/contratos/test/envio.test.ts` |
| `bultosDelPedido` | funcion | abierto | `apps/tienda/src/server/envios.ts`, `packages/contratos/test/envio.test.ts` |
| `cajasADespachar` | funcion | abierto | `apps/tienda/src/features/carrito/checkout/PaginaDelCheckout.tsx`, `packages/contratos/test/envio.test.ts` |
| `pesoDelPedidoKg` | funcion | abierto | `apps/tienda/src/features/carrito/checkout/PaginaDelCheckout.tsx`, `packages/contratos/test/envio.test.ts` |
| `MODALIDADES_DE_ENTREGA` | valor | **SIN PUERTA - nadie** | - |
| `ModalidadDeEntrega` | tipo | **SIN PUERTA - nadie** | - |
| `DestinoDeEnvio` | tipo | abierto | `apps/tienda/src/server/envios.ts` |
| `PROVINCIAS` | valor | abierto | `apps/tienda/src/features/carrito/checkout/ADondeVa.tsx` |
| `ProvinciaIso` | tipo | abierto | `apps/tienda/src/server/envios.ts` |
| `esProvinciaIso` | funcion | abierto | `apps/tienda/src/server/envios.ts` |
| `nombreDeProvincia` | funcion | abierto | `apps/tienda/src/features/carrito/checkout/PaginaDelCheckout.tsx` |
| `OpcionDeEnvio` | tipo | abierto | `apps/tienda/src/features/carrito/checkout/ComoViaja.tsx`, `apps/tienda/src/features/carrito/checkout/OpcionDeEntrega.tsx`, `apps/tienda/src/server/envios.ts` |
| `ProveedorDeEnvio` | tipo | abierto | `apps/tienda/src/server/envios.ts` |
| `totalConEnvio` | funcion | abierto | `apps/tienda/src/features/carrito/checkout/ElResumen.tsx`, `packages/contratos/test/envio.test.ts` |
| `SIN_CARGO` | valor | abierto | `apps/tienda/src/features/carrito/checkout/ElResumen.tsx`, `apps/tienda/src/features/carrito/checkout/OpcionDeEntrega.tsx` |
| `normalizarTelefonoAR` | funcion | **SIN PUERTA - solo tests** | `packages/contratos/test/envio.test.ts` |
| `DatosDeEntrega` | tipo | abierto | `apps/tienda/src/features/carrito/checkout/borrador.ts` |
| `validarDatosDeEntrega` | funcion | abierto | `apps/tienda/src/features/carrito/checkout/borrador.ts`, `packages/contratos/test/envio.test.ts` |
| `MotivoSinCotizacion` | tipo | **SIN PUERTA - nadie** | - |
| `ResultadoDeCotizacion` | tipo | abierto | `apps/tienda/src/features/carrito/checkout/useCotizacion.ts`, `apps/tienda/src/server/envios.ts` |
| `normalizar` | funcion | abierto | `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/envio.test.ts`, `packages/contratos/test/texto.test.ts`, `scripts/ci/auditar_estados.mjs` |
| `clave` | funcion | abierto | `apps/tienda/src/features/carrito/almacen.ts`, `apps/tienda/src/features/catalogo/PanelDeFiltros.tsx`, `apps/tienda/src/features/catalogo/SinResultados.tsx`, `apps/tienda/src/features/catalogo/filtros.ts`, `apps/tienda/src/features/oficio/SelloDeContacto.tsx`, `apps/tienda/test/almacen.test.ts`, `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/carrito.test.ts`, `packages/contratos/test/texto.test.ts`, `scripts/acceso/acceso.test.mjs`, `scripts/ci/auditar_estados.mjs`, `scripts/ci/generar_verdad.mjs` |
| `aSlug` | funcion | abierto | `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/texto.test.ts`, `scripts/ci/auditar_estados.mjs` |
| `seParecen` | funcion | abierto | `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/texto.test.ts`, `scripts/ci/auditar_estados.mjs` |
| `ENTRADAS_DE_TEXTO` | valor | solo el generador | `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/texto.test.ts` |
| `PARES_DE_TEXTO` | valor | solo el generador | `packages/contratos/scripts/generar.mjs`, `packages/contratos/test/texto.test.ts` |

**136 simbolos exportados. 47 SIN PUERTA.**

Sin puerta hoy: `EstadoPago`, `EstadoEntrega`, `transicionPagoValida`, `transicionEntregaValida`, `entroEnReembolsada`, `entroEnDespachada`, `entroEnEntregada`, `entroEnCancelada`, `EstadoPublico`, `CERO`, `desdePesos`, `porCantidad`, `TIPOS_DE_PRODUCTO`, `TipoDeProducto`, `FichaVino`, `ProductoSimple`, `ProductoCompuesto`, `Balde`, `viajaSolo`, `proyectarProducto`, `Descarte`, `CatalogoArmado`, `CasoDeBalde`, `ClaseDeDescarte`, `CasoDeDescarte`, `VERSION_DEL_CARRITO`, `LineaDeCarrito`, `ProductoDelCarrito`, `esProductoId`, `Cambio`, `unidadesEnCarrito`, `ESTADOS_DE_LINEA`, `EstadoDeLinea`, `botellasSueltas`, `LineaDePedido`, `PedidoDeCompra`, `CajaSugerida`, `CajasArmadas`, `ESTADOS_DE_LUGAR`, `EstadoDeLugar`, `LugarDeCaja`, `CajasResueltas`, `pesoDelBultoKg`, `MODALIDADES_DE_ENTREGA`, `ModalidadDeEntrega`, `normalizarTelefonoAR`, `MotivoSinCotizacion`.

Que aparezcan aca **no es un bug**: `functions/` y `apps/` todavia no existen y este paquete se escribio primero a proposito. Lo que si es un bug es que esta lista no baje cuando esas carpetas aparezcan. **La lista es la deuda.**

## 8. Lo que todavia no existe

Se comprueba por ruta, en cada corrida. Un `si` aca no dice que funcione.

| Ruta | Que seria | Existe |
|---|---|---|
| `apps/tienda` | vidriera Next.js | si |
| `apps/admin` | panel Flutter | si |
| `functions` | Cloud Functions | si |
| `firestore.rules` | reglas de Firestore | si |
| `storage.rules` | reglas de Storage | si |
| `firestore.indexes.json` | indices compuestos | si |
| `firebase.json` | proyecto Firebase | si |
| `.mcp.json` | MCP versionado en el repo | si |

Las secciones de arriba que dependen de estas rutas se emiten vacias con su nota. Un generador que se saltea una seccion en silencio es indistinguible de uno que la encontro vacia.

---

Archivos de codigo recorridos: 114. Archivos de test: 28. Casos de test: 455.
