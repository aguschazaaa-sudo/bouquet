# Export de lecciones — PadelPunilla → tienda digital de vinos

Destilado de ~37.000 palabras de post-mortems de PadelPunilla (Flutter + Firebase +
Riverpod, marzo–septiembre 2026, en producción), recortado para un proyecto nuevo:
**tienda de vinos, panel de administración en Flutter, vidriera en Flutter o React,
pagos con Mercado Pago o Ualá.**

Los tres primeros son el material heredado; ARQUITECTURA.md es el diseño que sale
de ellos. Se leen en este orden:

| Documento | Qué contesta | Cuándo leerlo |
|---|---|---|
| [LECCIONES.md](LECCIONES.md) | Qué aprendimos y cómo se traduce al negocio nuevo | Antes de decidir el stack |
| [SETUP-PRIMERA-CORRIDA.md](SETUP-PRIMERA-CORRIDA.md) | Cómo dejar el repo nuevo listo antes de escribir código | Día 1 del repo |
| [DIAGNOSTICO.md](DIAGNOSTICO.md) | Qué funciona, qué no, y qué portar de cada cosa | Al armar el setup, para no copiar lo roto |
| [ARQUITECTURA.md](ARQUITECTURA.md) | El diseño de bouquet: la forma del sistema, los estados, el presupuesto de lecturas | Antes de escribir la primera línea, y cada vez que se dude de una decisión |

## La decisión que hay que tomar primero

**Vidriera en React (Next.js), panel de administración en Flutter.**

Está desarrollada con evidencia medida en [LECCIONES.md §1.1](LECCIONES.md#1-la-decisión-que-hay-que-tomar-primero).
El resumen: Flutter web dibuja en `<canvas>` — cero nodos de texto, **cero `<a
href>`** — y el renderer HTML **se eliminó en Flutter 3.29**. No hay flag que
tocar. PadelPunilla lo resolvió con un subsistema de prerender en tiempo de build,
que funciona **para 9 URLs con datos que cambian una vez por año**. Un catálogo de
vinos incumple las dos condiciones el día uno: son cientos de URLs y el precio
cambia hoy.

Si igual va todo en Flutter, es una decisión legítima — pero presupuestá el
prerender como Cloud Function desde el principio, no como tarea de "después", y
llevate las 12 trampas ya pagadas de [§1.2](LECCIONES.md#12-si-igual-va-flutter-web-las-trampas-del-prerender-ya-están-pagadas).

## Las 12 lecciones, si sólo leés una cosa

Están al final de [LECCIONES.md](LECCIONES.md#apéndice-las-12-que-me-llevaría-si-sólo-pudiera-llevarme-12).

## Nota sobre el origen

Cada afirmación de estos documentos sale de un post-mortem con fecha, commit y
número. Donde algo es extrapolación —principalmente todo lo de **pagos**, que
PadelPunilla difirió a propósito— está marcado con ⚠️ **EXTRAPOLADO**.
