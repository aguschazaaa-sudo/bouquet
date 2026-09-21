## Context

El panel ya carga y corrige vinos (`panel-cargar-un-vino`, 2026-09-18). Todos
nacen con `publicado: false` y **nada los saca de ahí**: el único sitio que
escribe el campo es la factory del alta. Este change es el que los pone a la
venta.

Tres restricciones lo ordenan:

1. **El panel no compila en esta máquina** (`CLAUDE.md`). Todo lo que pueda
   equivocarse vive en Dart puro con `dart test`, que sí corre; el widget lee
   un resultado y no decide nada. Es el mismo reparto que ADR 013 §4.
2. **La vidriera y el panel tienen que decir lo mismo.** `armarCatalogo`
   descarta documentos con un motivo y hoy ese motivo **sólo se lee en el log
   del build**. Si el panel reimplementa la regla, las dos se desincronizan y
   el modo de falla es silencioso: un vino publicado que no aparece nunca.
3. **Dos hallazgos de `revisor-pagos` siguen abiertos** (ADR 008): el `delete`
   que se saltea la inmutabilidad, y `precio: 0` publicable.

## Goals / Non-Goals

**Goals:**

- Que un vino se pueda poner a la venta y sacar, y que el panel **no borre**.
- Que publicar esté cerrado por la misma validación que usa la vidriera, dicha
  campo por campo antes de tocar el botón.
- Que el precio de un vino publicado se pueda cambiar con una baranda que
  proteja **el valor nuevo**, no sólo la comparación con el anterior.
- Que los dos hallazgos de `revisor-pagos` queden cerrados **en las reglas**,
  no sólo en la pantalla.

**Non-Goals:**

- Subir, ordenar o borrar fotos (EP-04). Este change **lee** `imagenes`;
  nadie las escribe todavía.
- Escribir `stock` (EP-05). El panel lo lee para el balde y no lo toca.
- `descripcion` (no existe en el modelo).
- Tocar la vidriera. `armarCatalogo`, `balde` y `tope` **no cambian de
  comportamiento**: se exponen como fixtures, no se editan.

## Decisions

### 1. La foto NO bloquea publicar

EP-03 lo dejaba abierto. Se cierra con dos hechos medidos, no con una
preferencia:

- `apps/tienda/src/features/catalogo/VentanaDeBotella.tsx:45` **ya tiene el
  caso sin foto**: silueta de botella y la palabra "sin foto". Publicar sin
  foto no rompe la vidriera, la degrada de una forma que alguien diseñó.
- **EP-04 no está construida.** Nadie puede subir una foto todavía. Si la foto
  fuera requisito, hoy no se podría publicar **ningún** vino y el hito 1
  quedaría esperando un ADR de recorte a WebP.

| Alternativa | Por qué no |
|---|---|
| Exigir una foto para publicar | Traba el hito 1 entero detrás de EP-04 |
| Publicar en silencio sin foto | El operador se entera mirando la tienda, que es el modo de falla que HU-03.7 existe para cerrar |

**Lo que se paga:** el catálogo real puede nacer sin fotos. Se mitiga con el
aviso antes de publicar, y el día que EP-04 exista se puede endurecer.

### 2. El espejo viaja como fixtures en el contrato generado

`balde`, `tope` y los motivos de `armarCatalogo` se exponen en
`packages/contratos/generated/contratos.json` como **pares entrada→salida
calculados por el TypeScript de hoy**, y el espejo en Dart tiene un test que
los compara.

Es exactamente el patrón de `estado_publico.dart` y del bloque `texto`:
*"lo que viaja NO es la implementación —no se puede transportar en JSON— sino
pares entrada→salida CALCULADOS ACÁ por el TypeScript de hoy"*
(`packages/contratos/scripts/generar.mjs`).

| Alternativa | Por qué no |
|---|---|
| Que el panel llame a una callable que valide | Una lectura y una invocación por vino, para una cuenta que se puede hacer en memoria |
| Que el panel reimplemente `armarCatalogo` sin fixtures | Dos implementaciones del mismo descarte, sin nada que las compare. Es el modo de falla que ADR 002 prohíbe para los rótulos |
| Un script que compare el Dart contra el `.ts` como `auditar_varietales.mjs` | Sirve para una lista de strings; no para una función. Las fixtures sí la cubren |

**Y la auditoría exige los dos controles**, como ya hace con `texto` y `plata`:
sin un caso que entra al catálogo, un espejo que rechaza todo pasaría; sin los
tres baldes, uno que devuelve siempre `disponible` también.

**La unidad externa es el JSON, no el Dart.** Verificar que el panel es
coherente consigo mismo da verde con el panel roto.

### 3. Publicar es una acción, no un campo del formulario

El formulario de HU-03.2/03.4 no gana un `Switch` de `publicado`. Publicar y
despublicar son acciones propias, en la página del vino y en el renglón.

**Por qué:** el formulario guarda con "Guardar" y compara contra el vino como
se abrió; meter ahí una publicación haría que un cambio de ficha y una
publicación viajen juntos y que un error en la ficha impida despublicar.

- **Despublicar no se confirma.** Tiene vuelta atrás con un toque (criterio 3
  del [mapa del panel](../../../docs/vault/features/panel/overview.md)).
- **Publicar no se confirma tampoco**: lo que lo protege es la revisión previa,
  que es información, no una pregunta de sí/no.

### 4. `precioFijo` se queda, y el precio publicado tiene su propia puerta

`borrador_de_vino.dart:96` ya impide editar el precio de un vino publicado
desde el formulario. **Eso no se revierte.** Cambiar el precio de un vino en la
tienda es una acción aparte, con su confirmación y su aviso de atraso.

| Alternativa | Por qué no |
|---|---|
| Sacar `precioFijo` y dejar el precio editable como cualquier campo | El cambio de precio de un vino a la venta **rechaza los carritos abiertos** con el precio anterior: no es un campo más |

### 5. La baranda del dedo gordo se calibra sola

[ARQUITECTURA §9.4](../../../ARQUITECTURA.md#94-la-baranda-de-config-tiene-que-proteger-la-primera-escritura):
*"la condición se escribe sobre el valor nuevo, con el anterior como señal
opcional"*. Dos condiciones, cualquiera pide confirmación:

| Condición | Qué atrapa | Costo |
|---|---|---|
| El precio nuevo se aparta **10× o más de la mediana** de los vinos publicados | El cero de más y el cero de menos, **aunque el precio anterior ya estuviera mal** | 0 lecturas: la mediana sale del catálogo en memoria |
| El precio nuevo es **menos de la mitad o más del doble** del anterior | El cambio grande sobre un precio sano. Un 90 % de baja cae acá | 0 |

**Por qué la mediana y no un rango en pesos:** un piso escrito en pesos
envejece con la inflación y termina pidiendo confirmación en cada cambio o en
ninguno. La mediana del propio catálogo se recalibra sola.

⚠️ **Con menos de 5 vinos publicados la mediana no dice nada** y sólo aplica la
condición relativa. Queda escrito porque es el estado del día que se publique
el primer vino.

### 6. Las tres reglas nuevas, y por qué van en las reglas

El panel es de la familia y tiene un solo rol: una baranda de pantalla la
saltea cualquiera con la consola abierta. Estas tres van a la base porque el
costo de equivocarse es plata o un producto invisible.

| Regla | Hallazgo que cierra | Costo en lecturas |
|---|---|---|
| `allow delete: if false` | 1 — borrar y recrear se saltea `tipo` y `presentacion` | 0 |
| `publicado == true ⟹ precio > 0` | 2 — publicar con `precio: 0` | 0 |
| Cada `imagenes[i]` empieza con `https://` | La regla pedía menos que `armarCatalogo`, y la diferencia descarta el producto en silencio | 0 |

**Ninguna necesita `get()`**: las tres miran `request.resource.data`.

**El `delete` cerrado no rompe el seed.** Verificado, no supuesto:
`scripts/seed/proyecto.mjs:47-51` levanta `firebase-admin` con
`applicationDefault()`, y el Admin SDK no pasa por las reglas.

### 7. `ProductoDelPanel` gana `imagenes`

Hoy no la tiene, y el comentario del archivo dice *"entra con EP-04, que es
quien la usa"*. Este change la necesita para revisar antes de publicar y para
decir "se va a ver sin foto": **el lector llega antes que el escritor**. Se
agrega ahora, con el mapeo seguro (lista vacía si falta o si el documento trae
otra cosa).

### 8. Dónde vive cada pieza

```
packages/contratos/scripts/generar.mjs   fixtures de balde, tope y descartes
apps/admin/lib/core/contratos/
  catalogo_publico.dart                  el espejo: balde, tope, motivos
apps/admin/lib/features/catalogo/domain/
  en_la_tienda.dart                      ¿aparece? y si no, por qué  (Dart puro, con tests)
  cambio_de_precio.dart                  la baranda                  (Dart puro, con tests)
apps/admin/lib/features/catalogo/data/   publicar · despublicar · cambiarPrecio
apps/admin/lib/features/catalogo/presentation/vino/
  interruptor_de_tienda.dart             la hoja
  revision_para_publicar.dart            los motivos, campo por campo
  como_se_ve_en_la_tienda.dart           balde, tope, enlace a la ficha
  hoja_de_precio.dart                    el cambio con su confirmación
```

Composición **bottom-up**: las hojas primero, la página al final.

## Risks / Trade-offs

- **El `delete` cerrado es un cambio de comportamiento sobre datos que ya
  existen** → El único borrador es el seed, que usa el Admin SDK y no pasa por
  las reglas. Verificado en `proyecto.mjs:47-51`. La suite de reglas suma el
  caso, con su aceptado (`update` a `publicado: false`) al lado.
- **`publicado == true ⟹ precio > 0` puede rebotar una escritura que hoy
  pasa** → Ningún producto publicado tiene hoy precio 0; hay que **medirlo
  contra producción antes de desplegar**, no suponerlo. Si alguno lo tuviera,
  la regla lo dejaría atascado: no se podría ni corregir sin despublicar.
- **La regla de `imagenes` podría rebotar a los vinos de muestra** → El seed
  escribe URLs de Storage. Se verifica que todas empiecen con `https://`
  **antes** de desplegar; si alguna no, la regla se despliega igual pero el
  seed pasa por Admin SDK y no rebota — lo que rebotaría es una corrección
  desde el panel sobre ese vino.
- **La mediana con catálogo chico no discrimina** → Queda la condición
  relativa. Escrito arriba.
- **El aviso de ~13 minutos envejece con el tramo 4 de Cloudflare** → El
  número sale de ADR 008; cuando el tramo 4 exista, cambia ahí y acá. Queda
  anotado en el ADR nuevo.
- **Nadie vio el panel renderizado todavía** (`_index.md`, 2026-09-18) → Este
  change no lo arregla; lo arregla el deploy pendiente de
  `panel-cargar-un-vino`, que va **antes**.

## Migration Plan

**Orden no negociable: reglas → panel.** Sin functions, sin tienda.

1. **Antes de tocar nada**: entregar `panel-cargar-un-vino` (reglas del 09-18 +
   promover el canal `panel`). Sus reglas están sin desplegar y este change
   **también** toca `firestore.rules`: si se dejan juntas, un solo deploy
   publica dos changes y se pierde qué rompió qué.
2. `contratos`: fixtures + regenerar el JSON + tests.
3. Reglas: las tres condiciones, la suite contra el emulador, y **el conteo de
   casos antes y después** — la resta tiene que ser los nuevos.
4. Medir producción: ningún publicado con `precio: 0`; ninguna `imagenes` sin
   `https://`.
5. `revisor-pagos` sobre el diff (Workflow D, obligatorio).
6. Desplegar reglas. Verificar con la API de Rules, con control positivo y
   negativo.
7. Panel: domain → data → presentation, y CI `alcance=panel`.
8. `publicar.sh preview` → verificar → `promover` → `verificar` sobre live.

**Rollback:** las reglas vuelven publicando el ruleset anterior; el panel, con
`hosting:clone` desde la versión anterior. El orden inverso: panel primero.

## Open Questions

- **¿Cuál es el umbral exacto de la baranda relativa?** Arranca en mitad/doble.
  Se ajusta con el primer cambio de precio real que pida confirmación sin que
  hiciera falta.
- **¿El enlace a la ficha de la tienda, a qué dominio apunta?** No hay dominio
  todavía (`_index.md`). Arranca apuntando a la URL de App Hosting, y queda
  anotado que cambia con el dominio.
- **`descripcion`** sigue sin respuesta del dueño (hallazgo 14). No bloquea
  este change.
