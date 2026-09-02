---
name: commit
description: Preparar y hacer un commit en bouquet — stage, versión semver, Conventional Commit en español, leyendo el diff en conversación. Usar al cerrar cualquier tarea que haya tocado archivos.
---

# commit

## Por qué existe esto (NO REVERTIR)

Esta skill reemplazó a un **watcher de auto-commit**. Ese watcher corrompió
`.git/index` y costó **~5 días de trabajo sin commitear**.

De ahí sale la regla que `CLAUDE.md` repite: **ningún hook escribe git, nunca.**
Commitear es una acción en conversación, con el diff a la vista, porque la única
defensa contra un commit que no querías es que alguien lo haya mirado.

Si alguna vez parece cómodo automatizar esto: el cadáver está arriba.

## Esto NO es el último paso

`CLAUDE.md`: *un cambio commiteado NO es un cambio entregado.* Después de acá
viene **deploy** y después **verificar**.

En PadelPunilla los workflows terminaban en "Commit" durante cinco meses, y el
resultado fue exactamente el predecible: *"si el último paso escrito es commit,
el sistema produce commits sin deploys, de forma fiable."*

Al terminar, **decí cuál es el próximo paso del workflow**, con nombre.

## El procedimiento

1. **`git status` y `git diff`.** Leelos. Si aparece algo que no reconocés,
   pará y preguntá — no lo stagees "por las dudas".
2. **Stage explícito.** Rutas concretas. `git add -A` es cómodo el día que
   funciona y caro el día que arrastra un `.env`.
3. **Versión.** Se bumpea `package.json` en cada commit y la versión va **en el
   asunto**, no como tag.
   - `patch` — fix, doc, chore, refactor sin cambio observable
   - `minor` — capacidad nueva
   - `major` — se rompe un contrato de `packages/contratos`

   ⚠️ **No taggees.** `deploy.yml` dispararía un build por commit: decenas de
   canales de preview y ~20 min cada uno. La decisión de no conectarlos está
   tomada.
4. **Mensaje**, en español, dominio en español e infraestructura en inglés:

   ```
   v0.3.0 - functions: el trigger entroEnPagada con su marcador idempotente

   El marcador va en la MISMA transaccion que el efecto: si va despues,
   la ventana entre los dos es donde el segundo evento cobra dos veces.
   ```

   El asunto dice **qué cambió y dónde**. El cuerpo dice **por qué**, y sólo si
   el porqué no es obvio en el diff.
5. **Commit.** Sin `--no-verify`. Si un hook falla, se arregla la causa.

## Antes de dar por cerrada la tarea

- ¿Corriste el `cazador-de-puertas`? Lo que nadie puede abrir **no está
  entregado, está escrito**.
- ¿Actualizaste `docs/vault/`? Decisión → ADR. Estado → `_index.md`, tope 5.
- ¿Qué workflow era? Si era **E**, anotá el polizón. Si era **B** o **A**,
  todavía te faltan deploy y verificación.
