---
name: post-task-doc
description: Actualizar docs/vault después de una tarea — decisión al ADR, estado al _index.md con tope 5, pendientes con fecha y disparador. Usar antes de commitear.
---

# post-task-doc

Corre **siempre**, y ese es todo su valor. Una skill que corre en cada tarea
moldea el proyecto; una que corre cuando alguien se acuerda, no.

## Dónde va cada cosa

| Qué escribiste | Dónde va |
|---|---|
| Una **decisión** con alternativas descartadas | un ADR en `architecture/decisions/` |
| El **estado** del proyecto | `_index.md` — **tope 5 entradas** |
| Un término del negocio | `domain/glossary.md` |
| Algo que quedó pendiente | `_index.md` **con fecha y disparador** |
| El comportamiento real del código | **`_verdad.md`, que se genera — no a mano** |

## Las tres reglas

**1. `_index.md` es un dashboard, no un log.** La sexta entrada se mueve a
`changelog/_log.md`. En PadelPunilla creció a ~15 entradas de 20 líneas y se
leía **entero en cada sesión**: el archivo más caro del repo en tokens, y las
entradas 6 a 15 casi nunca cambiaban una decisión.

**2. Todo pendiente lleva fecha y disparador.** Sin eso miente por
construcción: describe el estado en el momento T, y nadie tiene el trabajo de
volver en T+1. Así es como se acumularon las secciones "pendiente de deploy"
que decían cualquier cosa.

**3. Este vault documenta la INTENCIÓN.** El comportamiento sale de
`_verdad.md`, generado desde el código. **La diferencia entre los dos es la
deuda del proyecto, medida.**

## Antes de escribir "completa"

**Grepeá.** Que una clase exista no prueba que alguien la abra; que una página
exista no prueba que haya una ruta. En el proyecto anterior el vault declaró
cuatro veces una feature entregada que no tenía puerta — una decía *"59/59
completa"*.

Si vas a escribir que algo está desplegado, **auditá producción**, no este
archivo. La forma corta: `firebase functions:list`, o `gh run view <id> --log |
grep "functions\[<nombre>("`.

## Campos obligatorios de un ADR

Fecha · estado · qué decide · **qué se descartó y por qué** · **presupuesto de
lecturas contra los 50.000/día** · `⚠️ EXTRAPOLADO` si viene de PadelPunilla y
no está validado acá.

Y si codifica algo que costó dolor: **"Por qué existe esto (no revertir)"** con
la fecha y el daño. Una regla con su cadáver adjunto no se revierte por
comodidad.
