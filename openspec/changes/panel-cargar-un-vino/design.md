# Diseño — cargar y corregir un vino

## Context

El panel lee el catálogo entero con dos streams vivos sin `autoDispose`
(ADR 012 §4) y carga bodegas con el id igual al slug (ADR 012 §6). **Los
productos son de sólo lectura**: `RepositorioDeProductos` tiene un único
método, `cambios()`, y `ProductoDelPanel` lleva sólo lo que pinta el renglón.

Lo que ya fijan las reglas de `productos` y no se toca: el documento se cierra
con `hasOnly` también adentro de cada mapa; `tipo`, `presentacion`, `stock` y
`muestra` no cambian en un `update`; un alta nace con `stock == 0`. Lo que
**no** fijan y este change agrega: la unicidad del slug y `graduacion`.

**La restricción que ordena todo el diseño:** el panel **no compila en esta
máquina** (`CLAUDE.md`). `dart test` y `dart analyze` sí corren, en minutos.
Así que toda decisión que se pueda equivocar vive en **Dart puro con tests**, y
los widgets quedan finos: leen un estado y llaman a una función.

## Goals / Non-Goals

**Goals:**

- Que el dueño cargue un vino real, con o sin caja, y lo corrija, sin pedirle
  nada al desarrollador.
- Que la unicidad del slug la garantice la base, sin lecturas de más.
- Que el precio escrito a mano llegue **exacto** a centavos y que el operador
  vea, antes de guardar, cómo va a salir en la tienda.
- Que dos personas corrigiendo el mismo vino no se pisen.

**Non-Goals:**

- Publicar, cambiar el precio de un vino publicado, decir por qué un vino no
  aparece (HU-03.5 a 03.7: próximo change).
- Fotos (EP-04), stock (EP-05), compuestos, `descripcion`.
- Mostrar la graduación en la vidriera.

## Decisions

### 1. El id del producto es su slug, y las reglas lo exigen

Un vino nuevo se crea en `productos/{slug}`, en una transacción que lee el
documento y se niega si ya existe —el mismo patrón que las bodegas—. Las
reglas agregan dos condiciones:

```
create: … && request.resource.data.slug == productoId
update: … && request.resource.data.slug == resource.data.slug
```

**Por qué:** Firestore no deja que dos documentos compartan id, así que la
unicidad la da la base **por construcción**. Cero lecturas, cero `get()`.

| Alternativa | Por qué no |
|---|---|
| La reserva `slugs/{slug}` que anotó ADR 008 | Una colección más, reglas con `getAfter()` —una lectura **facturada por evaluación**, el costo invisible que ADR 008 evita con el claim— y una pregunta sin respuesta: quién borra la reserva de un slug que cambió |
| Id aleatorio + chequeo en memoria | Deja abierta la carrera entre dos personas de la familia. Dos publicados con el mismo slug quedan **afuera los dos** de la vidriera (`armarCatalogo`), sin un error |
| Id aleatorio + transacción sobre una query por slug | Las transacciones del SDK cliente no bloquean una query: la carrera sigue |

**Lo que se paga:** el slug queda fijo **desde el alta**, no desde la
publicación como decía el glosario. Un error de tipeo en el nombre se corrige;
en la dirección, no. Se mitiga mostrando la dirección **mientras se escribe**,
antes de guardar. El slug es la URL que Google indexa: que no se mueva es lo que
se quería de todos modos, y HU-03.4 ya decía que el panel no ofrece editarlo.

**Los de muestra.** Tienen id `muestra-<slug>`, así que no chocan con un vino
real **en la base**, pero sí en la vidriera, y sólo si los dos están
publicados. Por eso el formulario **avisa y deja guardar** cuando el choque es
con uno de muestra, y **no deja** cuando es con uno real (que la base igual
rechazaría). El choque de dos publicados lo resuelve HU-03.6.

### 2. `graduacion`: entero en décimas, entre 50 y 250

`fichaVino.graduacion` opcional (ausente o `null`, como la añada). 13,5 % se
guarda `135`.

- **Por qué entero:** la misma disciplina que el precio. Un `double` de Dart
  (`14.0`) y un `number` de JS (`14`) se guardan distinto en Firestore
  (`doubleValue` contra `integerValue`), y `is int` en las reglas rechazaría
  uno de los dos según quién escribió.
- **Por qué décimas:** las etiquetas declaran a lo sumo un decimal.
- **Por qué el piso en 50:** no describe a los vinos, **atrapa la unidad
  equivocada**. `14` escrito pensando en 14 % sería 1,4 %: con el piso, las
  reglas lo rechazan. `13.5` no es entero y `1350` se pasa del techo. Cada
  confusión de unidad posible rebota.
- **El nombre se queda en `graduacion`**, como lo nombran el glosario,
  ARQUITECTURA y EP-03. La unidad la dicen el tipo en `contratos` y el rango.

⚠️ **Un vino sin alcohol no tiene graduación que le quepa.** Hoy no hay
ninguno; si aparece, va sin el campo.

### 3. El precio se lee en formato argentino, y lo ambiguo no se adivina

Un parser en Dart puro, `leerPesos(texto)`, que devuelve centavos o un motivo:

| Escrito | Resultado | Por qué |
|---|---|---|
| `12500` · `12.500` · `$ 12.500` | `1250000` | El punto es separador de miles cuando agrupa de a tres |
| `12.500,50` · `12500,5` | `1250050` | La coma es el decimal |
| `12.50` | **ambiguo** | ¿12,50, o 12.500 con un cero que se perdió? El campo pregunta |
| `12,505` | **error** | Más de dos decimales es un dato mal cargado, no algo a redondear (mismo criterio que `desdePesos`) |
| `1.2.3` · `12,5,0` · vacío | **error** | |

Se parsea **como texto**, nunca `double.parse(x) * 100`: `1.005 * 100` da
`100.49999999999999` (lo documenta `dinero.ts`).

**Por qué no se usa `desdePesos` de `contratos`:** su contrato es otro. Acepta
`19.99` como diecinueve con noventa y nueve —el punto decimal de un archivo o
un script—, y un operador argentino escribe `12.500` para doce mil quinientos.
Nadie más que el panel lee un precio escrito por una persona, así que el parser
no es una segunda implementación de nada.

**La unidad externa:** debajo del campo se ve el precio con `enPesos`, el
espejo de `formatearARS` que ya se verifica contra las fixtures del TypeScript.
El operador compara lo que escribió con **lo que va a ver el comprador**.

La graduación usa la misma lectura con un decimal y sin miles: `leerGraduacion`.

### 4. El formulario es un borrador en Dart puro

`BorradorDeVino` es inmutable y guarda **lo que se escribió** —textos crudos y
selecciones—, no valores ya convertidos: un precio a medio escribir no es un
número todavía, y el campo tiene que poder mostrarlo tal cual.

```
BorradorDeVino ──revisar(catalogo)──▶ Revision
                                        ├─ problemas por campo  → lo que dice cada campo
                                        ├─ AltaDeVino?          → sólo si no hay problemas
                                        └─ CambiosDeVino?       → el diff contra el original
```

- `revisar` es la **única** fuente de "¿se puede guardar?". El botón, los
  mensajes al lado de cada campo y la confirmación de la caja leen lo mismo.
- `AltaDeVino` lleva valores tipados. La factory que escribe el documento vive
  en `data/` —conoce a Firestore— y es **una sola**: `publicado: false`,
  `stock: 0`, `tipo: 'simple'`, `imagenes: []` no salen del borrador.
- `CambiosDeVino` compara contra el `ProductoDelPanel` que **se abrió**, no
  contra el que llega después por el stream. Lo que otra persona cambió
  mientras tanto en otro campo no viaja, y no se pisa.

Todo eso tiene tests con `dart test`. El widget no decide nada.

### 5. Los varietales: `arrayUnion` y después `arrayRemove`, en un batch

ARQUITECTURA §5.3 prohíbe reescribir la lista. Pero un mismo `update` no puede
llevar `arrayUnion` y `arrayRemove` sobre el mismo campo —sería la misma clave
dos veces—, así que la corrección va en un `WriteBatch` con dos `update` al
mismo documento:

1. los campos simples que cambiaron + `arrayUnion(agregados)`
2. `arrayRemove(quitados)`, sólo si hay

**Se temía que el orden importara, y se midió que no.** Si las reglas
evaluaran el estado intermedio, sacar primero dejaría la lista vacía al
reemplazar el único varietal —Malbec por Syrah— y `v.size() > 0` rechazaría.
**El emulador dice que las reglas ven el estado final del batch**: los dos
órdenes se aceptan y dejan `['Syrah']`, y quitar el último varietal solo se
rechaza —que es el control que muestra que las reglas sí miraron la lista—.
El panel igual une primero, porque no cuesta nada. Los tres casos quedaron en
`scripts/reglas/productos.test.mjs`.

| Alternativa | Por qué no |
|---|---|
| Reescribir la lista | Dos personas: la segunda borra lo que agregó la primera. Es lo que §5.3 prohíbe |
| Transacción que relee y reescribe | Correcta, pero cuesta una lectura por corrección y contradice la letra de §5.3 por una ganancia que el batch ya da |

Al crear, los varietales se guardan **en el orden de la lista cerrada**: los
chips no muestran un orden de elección, así que guardar uno sería guardar un
dato que el operador nunca vio.

### 6. Página con URL, no hoja

La bodega es una hoja porque es un campo. Un vino son diez: en un teléfono no
entran en una hoja, y una corrección con URL se puede recargar y mandar por
WhatsApp a otro de la familia ("mirá este").

- Alta: `/catalogo/nuevo`. Corrección: `/catalogo/vinos/<id>`.
- **No** `/catalogo/vinos/nuevo`: un vino llamado "Nuevo" tendría el slug
  `nuevo` y quedaría inalcanzable.
- Las dos son hijas de Catálogo, igual que Bodegas: la navegación sigue
  marcando Catálogo.
- La corrección busca el vino en el catálogo **en memoria**. Si todavía carga,
  espera; si cargó y no está, dice que no existe. Cero lecturas.

### 7. El formulario se parte por campo

`widget-size-guard` corta en 200 líneas y `one-widget-per-file` en un widget
público por archivo. Cada campo con lógica propia es su archivo: la bodega, los
varietales, el color, el precio con su vista previa, la graduación, las
botellas, la dirección. La página arma; el formulario ordena las secciones y
guarda.

### 8. Las botellas: se dice siempre, se confirma sólo la caja

Criterio 3 del mapa del panel: *"se confirma sólo lo que no tiene vuelta
atrás: el tipo y las botellas"*. Las dos cosas tienen vuelta atrás igual de
poca, pero no pesan lo mismo:

- **1 botella** es el caso normal y la pantalla ya dice que no se cambia.
  Confirmarlo en cada uno de los 200 vinos del MVP son 200 toques que no evitan
  ninguna pérdida (criterio 2).
- **Una caja** cambia qué significa cada unidad de stock, la saca de la caja de
  seis y la hace viajar sola (ADR 009 §10). Se confirma, diciendo las tres.

Rango: 1 a 12. Más de 12 botellas en una unidad no es algo que venda una
vinoteca, y el tope por pedido ya es 12 unidades.

### 9. El precio se corrige sólo fuera de la tienda

Con `publicado: false`, el precio nunca llegó a un comprador: ningún carrito lo
tiene como `precioUnitarioVisto` y ninguna página lo cacheó. Cambiarlo es una
corrección de datos, como el nombre.

Con `publicado: true` ya no: es HU-03.5, Workflow D, con la baranda del dedo
gordo y los ~13 minutos de caché. El campo se ve fijo y lo dice.

⚠️ **La restricción es del panel, no de las reglas**, igual que el slug de la
bodega (ADR 012 §6). Las reglas siguen dejando cambiar el precio de un
publicado. Se escribe para que no se lea al revés.

### 10. Cargar la bodega que falta sin salir del alta

`HojaDeBodega.mostrar` pasa a devolver el id de la bodega creada. El campo de
bodega lo usa para dejarla elegida. El formulario del vino no se desmonta
mientras la hoja está abierta, así que lo escrito no se pierde.

## Presupuesto de lecturas

| Qué | Lecturas |
|---|---:|
| Abrir el formulario (alta o corrección), sugerencias, direcciones ocupadas | **0** |
| Alta | **2** — la transacción + el documento nuevo por el stream |
| Corrección | **1** — el documento que cambió, por el stream |
| Reglas nuevas | **0** — ningún `get()` |

200 altas: ~400 lecturas una vez, **0,8 %** de la cuota de un día.

## Risks / Trade-offs

- **[Nadie mira el formulario renderizado]** El panel pide sesión y la única
  cuenta con permiso es la del dueño: pasó lo mismo con el catálogo
  (ADR 012). → Pedirle al usuario que lo mire, o autorizar una cuenta de prueba
  con `rol: admin`. **Sin eso, el change no se archiva.**
- **[El deploy de reglas está denegado en este harness]** →
  `firebase deploy --only firestore:rules` lo corre el usuario, o lo autoriza
  explícitamente. Se verifica con la API de Rules, no con el mensaje del CLI.
- **[El deploy de reglas publica el archivo entero]** → El último cambio de
  `firestore.rules` es `3b217d6` (v0.18.0), ya publicado el 2026-09-14. Antes
  de publicar, comparar el ruleset vigente con `HEAD`: la diferencia tiene que
  ser sólo la de este change.
- ~~**[El batch con dos escrituras al mismo documento]**~~ → **Medido en el
  emulador el 2026-09-18**: las reglas ven el estado final, en los dos
  órdenes (§5).
- **[El slug fijo desde el alta]** → Visible mientras se escribe. Si un error
  de tipeo llega igual a la base, el vino queda sin publicar y se carga de
  nuevo con otro nombre: el panel no borra.
- **[Un vino real con el nombre de uno de muestra]** → Aviso, no bloqueo. Los
  de muestra se borran con `scripts/seed/borrar.mjs` antes del catálogo real.
- **[Offline]** → La transacción del alta **falla** sin red: el alta nunca se
  confirma a medias. El batch de la corrección, no: el SDK la confirma contra
  su caché. Es el comportamiento que ya documenta `ErrorDeCatalogo.sinConexion`.
- **[`descripcion`]** → HU-03.4 la nombra y el modelo no la tiene. Queda
  escrito en el mapa del panel como hallazgo, para que la decida el dueño.

## Migration Plan

Sin migración de datos: ningún documento existente cambia, y los de muestra
siguen validando (no tienen `graduacion` y su slug no se toca).

1. **Reglas** (`firebase deploy --only firestore:rules`), verificadas con la
   API de Rules: el ruleset publicado contiene `slug == productoId` y
   `graduacion`.
2. **Panel** por CI (`alcance=panel`), canal de preview, verificación de
   hashes y canarios, `hosting:clone` a live.

**Orden al revés es seguro, en este caso:** un panel nuevo contra reglas viejas
crea con id igual al slug —las viejas lo permiten— y rebota sólo con
`graduacion`. Igual se respeta reglas → front.

**Rollback:** el panel vuelve con `hosting:clone` de la versión anterior; las
reglas, con el archivo de `3b217d6`. Ningún dato queda en una forma que las
reglas viejas no acepten, salvo un `graduacion`, que las viejas rechazarían en
el próximo `update` de ese vino.

## Open Questions

- **`descripcion`**: ¿la ficha lleva un texto del vino? Es un campo nuevo en
  `contratos`, las reglas, el panel y la vidriera. Pregunta para el dueño.
- **El slug con la bodega**: `aSlug(nombre)` hace chocar dos "Reserva Malbec"
  de bodegas distintas; hoy se resuelve poniendo la bodega en el nombre. Si
  pasa seguido, se revisa.
