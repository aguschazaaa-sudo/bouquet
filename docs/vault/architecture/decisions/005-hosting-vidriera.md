# ADR 005 — La vidriera se despliega en Firebase, con Cloudflare adelante y purga por tag

- **Fecha:** 2026-09-03
- **Estado:** aceptada en el destino de deploy · **abierta en dos verificaciones**
  (§Lo que hay que medir antes de creerle a este ADR)
- **Decide:** dónde corre `apps/tienda`, quién cachea el HTML y cómo se invalida
- **Reemplaza:** la columna *Hosting* de la vidriera en
  [ADR 001](001-stack.md). El resto de ADR 001 —Next.js para la vidriera,
  Flutter para el panel, Firebase de backend— **no cambia**
- **Toca:** [ADR 004](004-frescura-y-lecturas.md), que apoyaba la frescura en la
  revalidación on-demand de Next.js

## Contexto

El dueño decidió no usar Vercel y desplegar por Firebase (2026-09-03). La
decisión es suya y no se re-discute. Lo que sí hay que resolver es lo que ADR
001 había comprado con Vercel y ahora hay que conseguir de otra forma —porque
una de esas tres cosas es el mecanismo del que cuelga ADR 004 entero.

| Lo que compraba Vercel (ADR 001) | Qué pasa en Firebase |
|---|---|
| Deployments inmutables + promote | App Hosting hace rollouts sobre revisiones de Cloud Run: **se conserva** |
| El build no corre local ni gasta minutos de Actions | Cloud Build, **2.500 min/mes sin cargo**: se conserva |
| **ISR con revalidación on-demand de primera clase** | **No existe.** Es el problema de este ADR |

**Por qué no existe, con precisión.** Firebase App Hosting construye con Cloud
Build, sirve en **Cloud Run** y cachea en **Cloud CDN**. Dos consecuencias:

1. La caché de ISR de Next.js vive en el sistema de archivos del contenedor:
   **es efímera y por instancia.** Un `revalidatePath` invalida la copia de la
   instancia que atendió la llamada, y no la de sus hermanas.
2. La documentación de caché de App Hosting describe qué directivas de
   `Cache-Control` respeta Cloud CDN — y **no documenta ninguna purga
   on-demand**. Sin purga, la frescura sólo puede venir del TTL.

Eso rompe la propiedad que ADR 004 fue a buscar: *las lecturas escalan con las
ediciones del catálogo, no con las visitas*. Con TTL corto volvés a pagar
renders por tiempo; con TTL largo el precio miente.

## Decisión

### 1. `apps/tienda` en Firebase App Hosting

Cloud Build → Cloud Run → Cloud CDN, con rollouts por revisión.

⚠️ **App Hosting no tiene región en Sudamérica.** Las seis disponibles son
`us-central1`, `us-east4`, `us-east5`, `asia-east1`, `asia-southeast1` y
`europe-west4`. Firestore está en `southamerica-east1` y **eso no se puede
cambiar nunca**. Se elige `us-east4` o `us-central1` y se acepta el salto a São
Paulo — que ocurre **por render, no por visitante**, y con el punto 3 los
renders son pocos por día. Al visitante lo atiende el borde de Cloudflare desde
Buenos Aires.

### 2. Cloudflare adelante, y es el único caché de HTML

```
visitante ──▶ Cloudflare (borde, cachea el HTML)
                   │ MISS
                   ▼
              Cloud CDN ──▶ Cloud Run (Next.js SSR) ──▶ Firestore
```

### 3. **No se usa ISR. Se usa SSR con caché de borde y purga por tag.**

Es el cambio conceptual del ADR. La página se renderiza en el servidor, se
marca cacheable con TTL largo, y **la frescura la da la purga, no el
vencimiento**:

```
admin escribe productos/{id}
        │
        ▼
trigger revalidarVidriera  (onDocumentWritten)
        │  compara la PROYECCIÓN PÚBLICA de antes contra la de después
        │  iguales    → no hace nada
        │  distintas  → POST a la API de purga de Cloudflare, POR TAG
        ▼
Cloudflare descarta el HTML de esas URLs
        ▼
la próxima visita pega en Cloud Run, que re-renderiza y vuelve a cachear
```

Cada respuesta de la vidriera emite `Cache-Tag`:

| Página | `Cache-Tag` |
|---|---|
| `/vinos/[slug]` | `producto-<id>`, `catalogo` |
| `/vinos` y home | `catalogo` |

El trigger purga `producto-<id>` cuando cambia un producto, y `catalogo` cuando
cambia algo que altera el listado. **La condición del trigger no cambia**: sigue
siendo la comparación de proyecciones públicas de ADR 004 — descontar una
botella de 12 a 11 no purga nada.

**La purga por tag está disponible en todos los planes de Cloudflare**,
incluido el gratuito: 5 requests/minuto, hasta 100 operaciones por request. El
catálogo lo edita una persona a mano. No hay forma de acercarse a ese techo.

### 4. Un solo caché de HTML, no dos

Es la parte que hay que hacer bien o el diseño se cae:

- **Origen** (`Cache-Control`): TTL **corto** — `s-maxage=60,
  stale-while-revalidate=86400`. Acota a 60 s lo que Cloud CDN puede quedarse
  viejo, que es la capa **que no se puede purgar**.
- **Cloudflare**: una *Cache Rule* con **Eligible for cache** —el HTML no se
  cachea por defecto— y **Edge TTL override largo**, independiente del header
  del origen. Esta capa **sí** se purga.

Así el TTL largo vive donde hay purga y el TTL corto donde no la hay. **Dos
capas con `stale-while-revalidate` largo cada una es exactamente el modo de
falla que hay que evitar**: la de arriba se purga, la de abajo sirve viejo, y
nadie entiende por qué el precio no cambia.

### 5. Los assets estáticos no pasan por el optimizador en runtime

Las capas del parallax y todo asset decorativo se hornean en build y se sirven
estáticos con `Cache-Control: immutable` y hash en el nombre. `next/image` en
App Hosting optimiza **en Cloud Run**: es CPU por transformación, con caché en
disco efímero. Detalle y aritmética en
[design/parallax.md §6.4](../../design/parallax.md#64-dónde-viven-los-assets-y-qué-cuesta-en-firebase).

## Por qué

### La purga es lo que rescata a ADR 004

ADR 004 no eligió ISR por ISR: eligió **que las lecturas escalen con las
ediciones**. La tabla que decidió aquello sigue mandando:

| | A 100 visitas/día | A 250 | A 1.000 |
|---|---:|---:|---:|
| Lectura por visitante | 20.000 | **50.000** | 200.000 |
| Caché con invalidación por trigger | ~1.500 | ~1.600 | ~2.000 |

La purga por tag conserva esa propiedad **exactamente**: se re-renderiza cuando
el catálogo cambia, no cuando alguien mira. Que la invalidación la ejecute
Cloudflare en vez de Next.js no cambia ni un número de esa tabla.

### Por qué SSR y no ISR, ahora que hay purga

Porque ISR agregaría una **tercera** caché —la del contenedor— efímera, por
instancia y sin API de purga. Con Cloudflare purgable adelante, la caché de
Next.js no aporta nada y sí aporta un estado más que puede quedar viejo. **Menos
capas de caché es menos formas de servir un precio que no existe.**

### Por qué Cloudflare compra más que la purga

El egress de App Hosting se factura: **10 GiB/mes sin cargo** y después
US$ 0,15/GiB cacheado. Una landing con parallax pesa del orden de 1,2 MB por
visita nueva:

| | Visitas/mes dentro del tramo sin cargo |
|---|---:|
| App Hosting solo | ~8.700 |
| Con Cloudflare adelante (~90 % de aciertos en el borde) | **~87.000** |

El ancho de banda del plan gratuito de Cloudflare no se mide para contenido web
estándar. ⚠️ Su política de uso restringe servir bibliotecas de video o archivos
grandes no-HTML: imágenes de producto y capas de parallax entran; un catálogo de
video no.

## Por qué NO las alternativas

**Seguir con Vercel.** Descartado por el dueño el 2026-09-03. No se re-propone.

**App Hosting solo, con TTL corto y sin Cloudflare.** Es la opción de cero
proveedores nuevos. La descarto por aritmética: para que el precio no mienta más
de un minuto hace falta `s-maxage=60`, y eso son 1.440 renders diarios por
página cacheada. Con ~200 fichas es del orden de 288.000 renders/día — el mismo
número que ADR 004 usó para descartar la revalidación por tiempo, sólo que ahora
se paga en Cloud Run además de en lecturas.

**Un cache handler propio de Next.js sobre Firestore o Redis.** Resuelve la
caché por instancia, y no resuelve Cloud CDN. Además es código nuestro en el
camino crítico de todas las páginas: exactamente lo que
[la memoria del proyecto](../../../../CLAUDE.md) dice que hay que evitar cuando
existe una dependencia que ya lo hace.

**Rebuild estático completo en cada edición del catálogo.** Tentador: 2.500
minutos de build sin cargo alcanzan para ~600 builds/mes, y el catálogo lo edita
una persona. Descartado por dos motivos: un build de 3-4 minutos entre que el
dueño corrige un precio y el precio cambia en el sitio **es una ventana en la
que la tienda cobra mal**, y ADR 001 ya había rechazado el prerender en build
por lo mismo. Queda anotado como el plan B si la purga resulta inviable.

**Cloudflare Pages / Workers en vez de Firebase.** Es otra decisión de stack,
no una variante de ésta. El dueño dijo Firebase.

## Consecuencias

- **El trigger `revalidarVidriera` cambia de destino, no de condición.** En vez
  de pegarle al webhook de revalidación de Next.js, le pega a la API de purga de
  Cloudflare. La comparación de proyecciones públicas —el corazón barato de ADR
  004— queda igual.
- **Aparece un secreto nuevo:** el token de API de Cloudflare, con permiso
  `Zone.Cache Purge` y nada más. Va en Secret Manager, nunca en el repo. Es la
  segunda credencial del proyecto después de la service account, y le aplica la
  misma regla: el `.gitignore` no alcanza, se verifica con `git check-ignore`.
- **Un proveedor más en el camino de un visitante.** Si Cloudflare se cae, la
  tienda sigue en pie detrás; si se cae mal, no. Es el costo real de esta
  decisión y hay que decirlo.
- **El deploy sigue siendo reglas → functions → front**, y sigue arrastrando
  todo lo mergeado (ARQUITECTURA §10). Desplegar desde tag sigue pendiente y
  ahora importa más, porque el front ya no tiene el promote de Vercel: lo que se
  promueve es una revisión de Cloud Run.
- **`apps/admin` no se toca.** Sigue en Firebase Hosting con `hosting:clone`.

## Presupuesto de lecturas

Campo obligatorio.

| | Lecturas/día | Contra los 50.000 |
|---|---:|---|
| Presupuesto vigente de ADR 004 | ~1.700 | 3,4 % |
| **Después de este ADR** | **~1.700** | **3,4 %** |

**No cambia, y esa es la prueba de que el ADR está bien.** Si el número hubiera
subido, la purga no estaría conservando la propiedad de ADR 004 y habría que
volver a diseñar. La tabla completa sigue en
[ARQUITECTURA §6.3](../../../../ARQUITECTURA.md#63-el-presupuesto-completo).

## Lo que hay que medir antes de creerle a este ADR

Dos cosas están razonadas y **no** verificadas contra producción. Hasta que se
midan, este ADR está abierto.

**1. Que la purga de Cloudflare realmente cambie lo que ve un visitante.**
No alcanza con que la API devuelva `success: true`.

```bash
# control positivo: el string nuevo TIENE que aparecer — verificar antes que sea nuevo
curl -sI  https://<dominio>/vinos/<slug> | grep -i "cf-cache-status\|age\|cache-tag"
curl -s   https://<dominio>/vinos/<slug> | grep -c "<precio-viejo>"   # espera 1
# ...purgar por tag...
curl -s   https://<dominio>/vinos/<slug> | grep -c "<precio-nuevo>"   # espera 1
curl -s   https://<dominio>/vinos/<slug> | grep -c "<precio-viejo>"   # espera 0
# control negativo
curl -s -o /dev/null -w "%{http_code}\n" https://<dominio>/vinos/ruta-inventada
```

Un `cf-cache-status: HIT` con `Age` que **no** se reinicia después de purgar es
la señal de que la purga no llegó.

**2. Que Cloud CDN no esté sirviendo viejo por debajo.** Es la trampa de la
§Decisión 4 y el modo de falla más difícil de diagnosticar: Cloudflare purgado,
la página igual. Se mide pidiendo al origen **salteando Cloudflare** (por la
URL de App Hosting directa) y comparando el `Age` de las dos respuestas.

Y una tercera, operativa: **poner Cloudflare en proxy delante de un dominio
personalizado de Firebase puede romper la validación del certificado.** El
patrón conocido es validar con el proxy apagado y encenderlo después. Se
verifica el día que se conecte el dominio, no antes.

## Cuándo esta decisión deja de servir

- **App Hosting publica una API de purga on-demand:** desaparece la mitad del
  motivo de Cloudflare. Queda el ancho de banda, que sigue siendo motivo.
- **App Hosting abre región en Sudamérica:** se migra el backend y se elimina el
  salto a São Paulo por render.
- **La purga resulta inviable** en la medición 1: se pasa al plan B, el rebuild
  estático por Cloud Build, asumiendo su ventana de 3-4 minutos.
- **El catálogo supera ~1.000 productos:** ahí ya manda el disparador de ADR 004
  y esto se rediscute junto con los índices.

## Fuentes

- [Firebase App Hosting — overview, regiones e infraestructura](https://firebase.google.com/docs/app-hosting/about-app-hosting)
- [App Hosting — caché y directivas honradas por Cloud CDN](https://firebase.google.com/docs/app-hosting/optimize-cache)
- [App Hosting — costos](https://firebase.google.com/docs/app-hosting/costs)
- [Cloudflare — purge cache, métodos y límites por plan](https://developers.cloudflare.com/cache/how-to/purge-cache/)
- [Cloudflare — comportamiento de caché por defecto](https://developers.cloudflare.com/cache/about/default-cache-behavior)
- [Cloudflare — Cache Rules](https://developers.cloudflare.com/cache/how-to/cache-rules/)
