# bouquet — estado actual

> **Este archivo es un dashboard, no un log.** Tope: **5 entradas**. La sexta se
> mueve a `changelog/_log.md`.
>
> `DIAGNOSTICO.md` §3: en PadelPunilla este archivo creció a ~15 entradas de 20
> líneas y Claude lo leía **entero en cada sesión** — el archivo más caro del
> repo en tokens, y las entradas 6 a 15 casi nunca cambiaban una decisión. Un
> dashboard que no entra en una pantalla dejó de ser un dashboard.
>
> **Y este archivo documenta la INTENCIÓN.** El comportamiento real sale de
> `_verdad.md`, que se genera desde el código. **La diferencia entre los dos es
> la deuda del proyecto, medida.**

---

## Dónde está el proyecto

**Fase: pasos 0 y 1 terminados (2026-09-01). Todavía no hay UI ni backend.**

Existe: `git init` en `main`, `CLAUDE.md`, los 10 hooks con su arnés de 30
casos, `ci.yml`, los ADRs 001-004, y **`packages/contratos`** — la máquina de
estados de Orden, la proyección de los 30 pares, el dinero en centavos, 24
tests y el contrato generado.

No existe todavía `apps/`, `functions/` ni `firestore.rules`.

**Node 24 corre TypeScript sin transpilar**, así que el paquete tiene **cero
dependencias de test** (ni jest, ni vitest, ni ts-node). La única dependencia
del repo es `typescript`, para `tsc --noEmit`. En una máquina de 7,9 GB eso no
es un detalle de gusto.

Lo próximo es el **paso 2** de
[ARQUITECTURA §12](../../ARQUITECTURA.md#12-orden-de-construcción):
`firestore.rules` e índices, antes de que haya datos.

### La capa `.claude/` (2026-09-02)

**12 subagentes reales** en `.claude/agents/` — 7 escriben, 5 verifican **sin
`Edit` ni `Write`**. Esa resta es el único enforcement real del frontmatter:
`tools:` restringe herramientas, **no rutas**. Las fronteras por ruta las
siguen midiendo los hooks.

**27 skills de terceros**, declaradas en `skills-lock.json` y **no
commiteadas** — `bash scripts/skills_restaurar.sh` las restaura. Las propias
(`commit`, `post-task-doc`) sí se commitean.

`opsx` completo (12 skills) trae dos que PadelPunilla no tenía:
**`openspec-verify-change`**, que es el paso 9 que `WORKFLOWS.md` §4 pedía
agregar, y **`openspec-bulk-archive-change`**, la respuesta a los 33 changes sin
archivar.

Y un **Workflow E** nuevo: el chore que no llega solo a producción. Su paso
definitorio es un `grep`, no un criterio, y su último paso anota **en qué deploy
ajeno viaja de polizón**.

### Tres cosas que quedaron abiertas

| Qué | Por qué | Quién |
|---|---|---|
| **Los hooks no están vivos todavía** | `.claude/` no existía cuando arrancó la sesión, así que el watcher de settings no lo observa. Hay que abrir `/hooks` una vez, o reiniciar. **Verificado: un Write a `packages/contratos/src/` NO fue bloqueado.** | el usuario |
| **No hay remote de git** | `SETUP` §0.2: elegí `origin`, verificá que resuelve, y no tengas dos. | el usuario |
| **`git push` está en `deny`, no en `ask`** | Cerrado el hueco de `SKILLS-AGENTES-MCP` §5: el allowlist ya no pre-aprueba lo que `CLAUDE.md` prohíbe. Queda una decisión abierta: con `git push` en **`deny`**, el agente no puede pushear nunca y el paso de deploy lo dispara siempre una persona. Es defendible como baranda —es el paso que sale del repo— pero **es una elección, no un descuido**. Si molesta, moverlo a `ask`. Desde 2026-09-02. | el usuario |

---

## Decisiones vigentes

| # | Decisión | ADR |
|---|---|---|
| 001 | Vidriera Next.js en Vercel · panel Flutter en Firebase Hosting · backend Firebase | [001](architecture/decisions/001-stack.md) |
| 002 | La Orden tiene **dos ejes** de estado (pago y entrega), no uno | [002](architecture/decisions/002-estados-de-orden.md) |
| 003 | Proveedor de pagos **diferido**; el contrato del webhook está escrito | [003](architecture/decisions/003-pagos.md) |
| 004 | Frescura por revalidación on-demand · filtrado del catálogo **en memoria** | [004](architecture/decisions/004-frescura-y-lecturas.md) |

---

## Lo que está pendiente y por qué

Cada pendiente lleva **fecha** y **disparador**. §2.9: una nota escrita en el
momento T describe el estado en T, y nadie tiene el trabajo de volver en T+1 —
por eso los "pendiente de deploy" mienten por construcción.

La lista completa está en
[ARQUITECTURA §11](../../ARQUITECTURA.md#11-lo-que-queda-abierto-con-su-disparador).
Los tres que bloquean algo:

| Pendiente | Disparador | Desde |
|---|---|---|
| Proveedor de pagos | Cuando el dueño quiera cobrar online | 2026-09-01 |
| Requisitos legales de venta de alcohol online | Antes de la primera venta real | 2026-09-01 |
| Deploy desde tag en vez de rama | Antes del primer deploy que incluya cobro | 2026-09-01 |

---

## Antes de creerle a este archivo

- **Un job verde no prueba que compiló; el artifact sí.**
- **Un `Deploy: success` no prueba que publicó; la lista de jobs sí.**
- **Antes de creer que una feature existe, grepeá quién la abre**, no si está
  escrita. Pasó cuatro veces en seis meses en el proyecto anterior.
- **Ante cualquier "¿esto está desplegado?", auditá producción**, no este
  archivo.
