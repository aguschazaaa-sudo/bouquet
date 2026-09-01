# ADR 004 — Frescura del catálogo por revalidación on-demand, y filtrado en memoria

- **Fecha:** 2026-09-01
- **Estado:** aceptada
- **Decide:** cómo la vidriera obtiene los datos, con qué frescura y a qué costo

## Contexto

Dos requisitos que tiran para lados opuestos:

- **Frescura.** §1.1: *"el precio y el stock cambian el mismo día"*. Una ficha de
  producto que miente hasta el próximo deploy es el dato que decide la compra,
  mal.
- **Costo.** §4.1.7: la cuota gratuita de Firestore son **50.000 lecturas/día**, y
  a escala MVP los dólares no asustan pero la cuota sí.

Y un dato del negocio que cambia todo: **el catálogo es de menos de 200 productos
y lo edita una persona a mano.**

## Decisión

### 1. La vidriera lee del lado servidor, nunca desde el navegador

Todo acceso a Firestore vive en `apps/tienda/src/server/**` con el Admin SDK. El
visitante no tiene un SDK de Firestore en la mano.

### 2. ISR con revalidación disparada por trigger

```
admin escribe productos/{id}
        │
        ▼
trigger revalidarVidriera  (onDocumentWritten)
        │  compara la PROYECCIÓN PÚBLICA de antes contra la de después
        │  iguales    → no hace nada
        │  distintas  → POST al webhook de revalidación de la tienda
        ▼
Next.js regenera /vino/<slug> y el listado
```

Fallback: `revalidate` de 6 h, por si un webhook se pierde.

### 3. El filtrado del catálogo se hace en memoria

La proyección publicada entera (~200 productos) se carga una vez por
revalidación. Bodega, varietal, región y rango de precio se filtran sobre esa
lista, no con queries de Firestore.

### 4. El stock se muestra en baldes

`disponible` · `últimas unidades` · `agotado`. Nunca el número exacto.

## Por qué

### El número que decide

| | A 100 visitas/día | A 250 | A 1.000 |
|---|---:|---:|---:|
| Lectura por visitante | 20.000 | **50.000** | 200.000 |
| ISR con revalidación por trigger | ~1.500 | ~1.600 | ~2.000 |

Una vidriera que lee Firestore por visitante **revienta la cuota gratuita a las
250 visitas diarias** — que para una tienda es un día flojo. Con ISR, las
lecturas escalan con las **ediciones del catálogo**, y el catálogo lo edita una
persona.

### Por qué comparar la proyección y no el documento

Es el detalle que hace que esto sea barato. Descontar una botella de 12 a 11
cambia el documento pero **no cambia lo que la página dice** (`disponible`), así
que no dispara revalidación. Cambiar el precio, agotar el stock o despublicar sí.

Es el mismo patrón que `entroEnPagada` de [ADR 002](002-estados-de-orden.md):
la condición se escribe sobre **el hecho observable**, no sobre "hubo una
escritura".

### Por qué baldes y no el número exacto

Dos razones, y la segunda es la que importa.

- **Costo:** el balde cambia pocas veces; el número cambia en cada venta.
- **Honestidad:** §7.4 — *"Últimas 3 botellas"* **afirma un número exacto** y
  *"poco stock"* no. Si el pool de redacciones las mezcla, mentís en la mitad de
  los casos. **Si una redacción dice algo que las otras no sostienen, no es una
  variante: es otro caso**, con su propia condición en el dominio.

Y si algún día se muestra el número exacto, tiene que ser el número exacto en el
momento de renderizar — que con ISR no se puede garantizar. El balde no tiene ese
problema porque tolera estar un rato viejo sin mentir.

### Por qué filtrado en memoria y no queries con índices

Porque con 200 productos la query no compra nada y el índice cuesta.

`bodega == X && varietal array-contains Y && precio >= A && precio <= B` con
`orderBy('precio')` es **exactamente la forma que rompe la regla 1 de §4.2** si
se arma por intuición: en un índice compuesto los campos de igualdad van *todos*
antes que el de rango. En PadelPunilla un índice se construyó perfecto, quedó
`READY`, y **no servía para ninguna query**. Al preguntar bien aparecieron **7
índices faltantes, no 1** — incluido un cron tirando `FAILED_PRECONDITION` cada
30 minutos sin que nadie lo notara.

Filtrar en memoria elimina esa familia entera de trampas para el caso que más las
tocaría. Y de paso elimina §4.3 (un `where` no devuelve los documentos donde el
campo no existe), aunque la regla de escribir `publicado` siempre en la creación
se mantiene igual.

**Un índice declarado y no consultado es costo de escritura.** Menos índices no
es sólo menos complejidad: es menos plata por cada producto que se guarda.

## Por qué NO las alternativas

**Prerender en build (lo que hizo PadelPunilla).** Descartado en
[ADR 001](001-stack.md): el precio cambia hoy, el deploy es mañana.

**Un documento denormalizado `catalogo/publico` mantenido por trigger.** Bajaría
la revalidación de 200 lecturas a 1. Descartado: 200 productos × ~2 KB son
~400 KB contra el límite de 1 MB por documento, así que nace con un techo a la
vista y hay que trocear. Con ISR la revalidación ocurre pocas veces por día, así
que las 200 lecturas no son el problema que hay que resolver. **Desnormalizar
cuesta todos los caminos de escritura + backfill + fan-out** (§4.1.5); se evalúa
otra vez si el catálogo crece.

**Revalidar por tiempo corto (60 s) en vez de on-demand.** 200 lecturas × 1.440
revalidaciones = 288.000 lecturas/día. Seis veces la cuota, para tener datos
peores que con el trigger.

## Consecuencias

- El presupuesto MVP queda en **~1.700 lecturas/día, 3,4 % de la cuota**. La
  tabla completa está en
  [ARQUITECTURA §6.3](../../../../ARQUITECTURA.md#63-el-presupuesto-completo).
- **El renglón que más se mueve es el panel, no la vidriera.** Lo caro suele ser
  `autoDispose`, no el volumen (§4.1.4). La caché del catálogo en el panel **no
  lleva `autoDispose`**: con ella son ~200 lecturas/día, sin ella ~2.000.
- El mismo artefacto de proyección publicada sirve el listado, los filtros y el
  índice de búsqueda del cliente. Una sola generación, tres consumidores (§6.4).
- **Todo ADR de feature nueva declara cuántas lecturas agrega** por apertura de
  pantalla y contra qué queda eso de los 50k/día. Campo obligatorio de la
  plantilla.

## Cuándo esta decisión deja de servir

Escrito hoy para no discutirlo después. Se migra a queries con índices cuando
pase **lo primero** de:

- el catálogo supere ~1.000 productos, o
- la proyección publicada supere ~2 MB.

Ahí valen las 4 reglas de forma de §4.2 —igualdades primero, `in` cuenta como
igualdad, no hay prefix matching, `collectionGroup` necesita índice propio— y
hace falta `scripts/ci/auditar_indices.mjs`, que **corre** cada forma de query
contra el emulador y sale con exit 1 si falta alguna. Verificar que un índice
existe y está `READY` **no verifica nada**.
