# ADR 001 — Vidriera en Next.js, panel en Flutter, backend en Firebase

- **Fecha:** 2026-09-01
- **Estado:** aceptada
- **Decide:** con qué se escribe cada front-end y dónde vive cada uno

## Contexto

bouquet tiene dos superficies con requisitos opuestos:

- **La vidriera** vive o muere de que Google y WhatsApp puedan leerla. Una tienda
  de vinos que no aparece en una búsqueda no tiene negocio.
- **El panel** lo usa una persona autenticada. Nadie googlea un panel.

## Decisión

| Superficie | Stack | Hosting |
|---|---|---|
| Vidriera | Next.js (App Router, SSR + ISR) | Vercel |
| Panel | Flutter (web + Android) | Firebase Hosting |
| Backend | Firebase: Firestore, Cloud Functions (TS), Storage, Auth | — |

## Por qué

Flutter web dibuja todo dentro de un `<canvas>`. Medido en producción en
PadelPunilla el 2026-08-26: un club real y un club inventado se diferenciaban en
**cero bytes**, y `site:padelpunilla.com.ar` no devolvía **ninguna** página.

Lo que falta más que el texto son los **enlaces**: sin `<a href>` no hay grafo de
rastreo, así que Google ni siquiera llega a la página que no puede leer.

**Y el consejo que circula por internet ya no se puede seguir.** Todo artículo de
"Flutter SEO" dice *usá el renderer HTML*; ese renderer **se eliminó en Flutter
3.29** junto con el flag `--web-renderer`. Quedan CanvasKit y skwasm, los dos
sobre canvas. `--wasm` mejora el rendimiento y **no cambia nada** de
indexabilidad. No hay flag, no hay configuración, no hay workaround.

## Por qué NO todo en Flutter

Es la alternativa que se evaluó en serio, porque tiene una ventaja real: una sola
base de código y un solo pipeline.

PadelPunilla la resolvió con un subsistema de prerender en tiempo de build. La
nota del vault dice explícitamente cuándo deja de servir: *"se migra a Cloud
Function cuando pase lo primero de: el catálogo deje de caber cómodamente en un
deploy, o los clubes empiecen a editar datos que tienen que verse el mismo día"*.

**Las dos condiciones se cumplen el día uno en una tienda:**

- No son 9 URLs. Son productos × bodegas × varietales × regiones.
- **El precio y el stock cambian el mismo día.** Prerenderizar en build significa
  que la ficha del producto miente hasta el próximo deploy. En una cancha de
  pádel es tolerable (el club cambia de dirección una vez por año); acá es el
  dato que decide la compra.

Y hay un tercero que PadelPunilla no tuvo: el JSON-LD `Product`/`Offer` con
`price` y `availability` es lo que arma el resultado enriquecido de Google. Un
precio prerenderizado viejo no es una página desactualizada — es una
**discrepancia entre el structured data y la página**, que Google penaliza.

O sea: elegir Flutter para la vidriera no ahorra el segundo pipeline, lo cambia
por uno peor — un prerender como Cloud Function, mantenido a mano, sirviendo
markup de segunda.

## Por qué NO todo en Next.js (panel incluido)

Ahorraría un stack. Se descarta por dos razones:

1. El panel se va a usar desde el celular en el depósito, y una app instalable
   con cámara nativa para las fotos de producto es una diferencia real.
2. Es donde el conocimiento acumulado sirve: los cuatro hooks HARD, la
   arquitectura por capas y la disciplina de composición bottom-up están escritos
   para Flutter y probados durante seis meses.

## Por qué Vercel y no Firebase Hosting para la vidriera

Cuesta un segundo proveedor. Compra tres cosas:

1. **Deployments inmutables con promote.** Es `LECCIONES` §3.3 —*promové, no
   republiques*— implementado por la plataforma: se promueve un build ya
   verificado en vez de recompilar. En PadelPunilla ese error dejó un release
   atascado el 2026-06-23.
2. **ISR con revalidación on-demand de primera clase**, que es el mecanismo del
   que depende [ADR 004](004-frescura-y-lecturas.md).
3. **El build no corre acá ni gasta minutos de GitHub Actions.** La capa gratuita
   son 2.000 min/mes (§3.6) y esta máquina tiene 7,9 GB de RAM con 0,4 libres
   (§9.4). Sacar el build de Next.js de las dos restricciones es gratis.

## Consecuencias

- Dos pipelines de deploy, con dos modelos de release distintos. Documentado en
  [ARQUITECTURA §10](../../../../ARQUITECTURA.md#10-deploy-y-entornos).
- La service account de Firebase vive como variable de entorno en Vercel. Eso
  crea un modo de falla nuevo —credenciales filtradas al bundle del cliente— que
  cierra el hook `server-only-guard.sh`. **Es una regla que se escribe como hook
  o no existe** (§9.3).
- `packages/contratos` lo importan los tres lados de TypeScript directo, y Dart
  lo espeja con un test contra el JSON generado.
- El ciclo de feedback es asimétrico: la vidriera se desarrolla local en
  segundos, el panel depende de CI. Eso ordena el plan de construcción
  ([ARQUITECTURA §12](../../../../ARQUITECTURA.md#12-orden-de-construcción)).

## Trampas ya pagadas que aplican igual

Aunque la vidriera no sea Flutter, tres lecciones de §1.2 y §1.3 se transfieren:

- **Auditá el `<head>` como parte del checklist de release.** Un `<script>` común
  en el `<head>` frena el parseo del `<body>`; un `<link rel=stylesheet>` frena
  el primer pintado. Todo script de terceros que una tienda acumula —analytics,
  píxel de Meta, chat, widget de reseñas, SDK de pagos— es candidato.
- **`og:image:width` / `og:image:height` no son opcionales.** Sin ellas el
  rastreador de Facebook baja la imagen entera antes de decidir el tamaño, y en
  el **primer** scrapeo —justo cuando alguien comparte— la tarjeta sale sin foto.
  Y si no podés medir la imagen, **omití las etiquetas**: declarar un tamaño
  equivocado es peor que no declarar ninguno.
- **WhatsApp no ejecuta JavaScript** para armar la vista previa: lee el HTML
  crudo. En Argentina, donde el canal de venta es WhatsApp, eso no es SEO — es
  conversión.
