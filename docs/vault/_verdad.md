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
> **Generado:** 2026-09-03 - commit `93525f1` **+ cambios sin commitear** - huella del cuerpo `0969580a59db`

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
| `@bouquet/tienda` | 0.1.0 | `apps/tienda` | `dev`, `build`, `start`, `typecheck` |
| `@bouquet/functions` | 0.1.0 | `functions` | `construir`, `tipos`, `test` |

### Scripts de la raiz - `bouquet` 0.5.4

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
| `apps/admin/test/core/contratos/estados_orden_test.dart` | 9 |
| `packages/contratos/test/dinero.test.ts` | 7 |
| `packages/contratos/test/orden.test.ts` | 13 |
| `packages/contratos/test/proyeccion.test.ts` | 6 |
| **total** | **35** |

Conteo lexico de `test(` e `it(`. Se cuenta y no se escribe porque el `_index.md` del proyecto anterior decia 1929 cuando el runner iba por 2003. No incluye `test.skip(` ni `test.only(`: un test salteado no es un test que corre.

## 4. Hooks activos

Leidos de `.claude/settings.json`, que es lo que el harness ejecuta de verdad.

| Evento | Matcher | Script | Timeout | El script existe |
|---|---|---|---|---|
| PreToolUse | `Edit\|Write` | `scripts/hooks/vault-precheck.sh` | 10s | si |
| PostToolUse | `Edit\|Write` | `scripts/hooks/widget-size-guard.sh` | 10s | si |
| PostToolUse | `Edit\|Write` | `scripts/hooks/layer-boundary.sh` | 10s | si |
| PostToolUse | `Edit\|Write` | `scripts/hooks/server-only-guard.sh` | 10s | si |
| PostToolUse | `Edit\|Write` | `scripts/hooks/one-widget-per-file.sh` | 10s | si |
| PostToolUse | `Edit\|Write` | `scripts/hooks/no-hardcoded-colors.sh` | 10s | si |
| PostToolUse | `Edit\|Write` | `scripts/hooks/call-site-guard.sh` | 30s | si |
| Stop | `(todos)` | `scripts/hooks/post-task-reminder.sh` | 10s | si |
| Stop | `(todos)` | `scripts/hooks/doc-reminder.sh` | 10s | si |
| Stop | `(todos)` | `scripts/hooks/commit-reminder.sh` | 10s | si |

Los 10 hooks apuntan a scripts que existen. Que existan no prueba que midan: eso lo prueba `bash scripts/hooks/probar_hooks.sh`.

### Permisos del harness

- **deny**: `Bash(flutter analyze:*)`, `Bash(flutter test:*)`, `Bash(flutter build:*)`, `PowerShell(flutter analyze:*)`, `PowerShell(flutter test:*)`, `PowerShell(flutter build:*)`, `Bash(npx jest:*)`, `PowerShell(npx jest:*)`, `Bash(firebase deploy:*)`, `PowerShell(firebase deploy:*)`
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

**12 subagentes: 7 escriben, 5 verifican sin `Edit` ni `Write`** (`auditor-produccion`, `cazador-de-puertas`, `presupuesto-lecturas`, `revisor-acoplamiento`, `revisor-pagos`).

Escriben pero no tienen `Bash`, o sea que no pueden desplegar ni commitear: `vault`.

## 6. Skills declaradas

**27 skills de terceros**, declaradas en `skills-lock.json` con su hash y **no commiteadas** (`.gitignore` ignora `.claude/skills/*`). Restaurar en un clon: `bash scripts/skills_restaurar.sh`.

| Origen | Cuantas | Cuales |
|---|---|---|
| `anthropics/skills` | 5 | `brand-guidelines`, `canvas-design`, `frontend-design`, `theme-factory`, `webapp-testing` |
| `firebase/agent-skills` | 2 | `firebase-firestore`, `firebase-security-rules-auditor` |
| `fission-ai/openspec` | 12 | `openspec-apply-change`, `openspec-archive-change`, `openspec-bulk-archive-change`, `openspec-continue-change`, `openspec-explore`, `openspec-ff-change`, `openspec-new-change`, `openspec-onboard`, `openspec-propose`, `openspec-sync-specs`, `openspec-update-change`, `openspec-verify-change` |
| `mercadopago/mercadopago-claude-marketplace` | 2 | `mp-integrate`, `mp-webhooks` |
| `vercel-labs/agent-skills` | 6 | `vercel-composition-patterns`, `vercel-optimize`, `vercel-react-best-practices`, `vercel-react-view-transitions`, `web-design-guidelines`, `writing-guidelines` |

Propias del proyecto, commiteadas porque mencionan nuestro dominio: `commit`, `post-task-doc`.

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
| `Centavos` | tipo | **SIN PUERTA - nadie** | - |
| `centavos` | funcion | **SIN PUERTA - solo tests** | `packages/contratos/test/dinero.test.ts` |
| `CERO` | valor | **SIN PUERTA - nadie** | - |
| `desdePesos` | funcion | **SIN PUERTA - solo tests** | `packages/contratos/test/dinero.test.ts` |
| `sumar` | funcion | **SIN PUERTA - solo tests** | `packages/contratos/test/dinero.test.ts` |
| `porCantidad` | funcion | **SIN PUERTA - solo tests** | `packages/contratos/test/dinero.test.ts` |
| `formatearARS` | funcion | **SIN PUERTA - solo tests** | `packages/contratos/test/dinero.test.ts` |

**28 simbolos exportados. 16 SIN PUERTA.**

Sin puerta hoy: `EstadoPago`, `EstadoEntrega`, `transicionPagoValida`, `transicionEntregaValida`, `entroEnReembolsada`, `entroEnDespachada`, `entroEnEntregada`, `entroEnCancelada`, `EstadoPublico`, `Centavos`, `centavos`, `CERO`, `desdePesos`, `sumar`, `porCantidad`, `formatearARS`.

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

Archivos de codigo recorridos: 17. Archivos de test: 4. Casos de test: 35.
