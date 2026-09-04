# Changelog del estado — bouquet

> Lo que salió de [`_index.md`](../_index.md) por el tope de 5 entradas. No se
> borra: se mueve. Un dashboard que no entra en una pantalla dejó de ser un
> dashboard, pero el historial sigue valiendo para entender por qué algo está
> como está.
>
> Orden: **lo más nuevo arriba**.

---

## Salió el 2026-09-04, al entrar la landing alternativa

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
