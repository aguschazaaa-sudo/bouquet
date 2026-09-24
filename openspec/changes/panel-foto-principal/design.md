## Context

- `imagenes[]` es **la única ruta** a las fotos de un producto
  ([ARQUITECTURA §5.2](../../../ARQUITECTURA.md#52-los-campos-que-tienen-trampa-y-cuál-es)),
  y la vidriera usa sólo la primera.
- Hoy el panel escribe `imagenes` de tres formas, ninguna reescribe el array:
  `arrayUnion` al subir y `arrayRemove` al sacar
  (`repositorio_de_fotos_firebase.dart`), y la lista entera sólo en el alta,
  cuando el documento nace (ADR 015 §5).
- `firestore.rules` ya acepta un `update` que reescribe `imagenes`, si la lista
  pasa `imagenesValidas` (hasta 10 URLs `https://`) y el resto del documento
  sigue siendo válido. **No hace falta tocar reglas.**
- La página del vino recibe `imagenes` del catálogo en memoria, y
  `productosProvider` es un `snapshots()`: cuando la lista cambia en la base, la
  sección se redibuja sola. **No hace falta ninguna lectura nueva en la página.**
- Los tests del panel son de dominio puro (`dart test`, sin fakes de Firestore).
  Lo que se puede probar en esta máquina tiene que vivir en `domain/`.

## Goals / Non-Goals

**Goals:**

- Elegir la principal con un toque, en un vino guardado y en un alta sin guardar.
- Que ese toque no pueda perder una foto que otra persona subió en el medio.
- Que la regla del reordenamiento se escriba **una sola vez** y la usen las dos
  rutas.

**Non-Goals:**

- Ordenar la segunda foto en adelante: la vidriera no las muestra (proposal).
- Arrastrar para ordenar: con una sola decisión posible, alcanza con un botón.
- Cambiar la vidriera, las reglas, `functions/` o `contratos`.
- Borrar de Storage la foto que deja de ser principal: no se borra nada, sólo
  cambia el orden.

## Decisions

### 1. Una transacción de cliente que relee, y no un campo aparte

Se cambia la principal con `runTransaction`: se lee el documento, se calcula la
lista nueva **a partir de lo leído** y se escribe con `tx.update`. Las
transacciones de los SDK de cliente son optimistas: si el documento cambió entre
la lectura y el commit, el SDK reintenta con una lectura fresca. La lista que se
escribe es siempre una permutación de la que se leyó en ese intento.

**Alternativas descartadas:**

| Alternativa | Por qué no |
|---|---|
| Un campo `principal` aparte, y `imagenes` intacto | Son **dos fuentes** para la misma pregunta, contra §5.2. Toca cuatro lugares (contratos, reglas, vidriera, panel), y un `principal` que apunta a una foto que ya se sacó es un estado nuevo que la vidriera tendría que saber leer |
| `arrayRemove` + `arrayUnion` de las fotos que están antes de la elegida, en un batch, sin leer | Mueve la elegida al frente sin transacción, pero las fotos que se sacan y se vuelven a poner **salen de la pantalla**, que puede estar vieja: si otra persona sacó `A` recién, el `arrayUnion(A)` **la resucita**. Es exactamente el tipo de pisada que §5.3 existe para evitar |
| Una callable | Un deploy de `functions`, un arranque en frío y un permiso más, para una escritura que las reglas ya permiten al cliente. No agrega ninguna garantía que la transacción no dé |
| Escribir la lista que tiene la pantalla | Es lo que §5.3 prohíbe: la pantalla puede no tener la foto que otra persona subió hace un segundo |

**Sin red, la transacción falla** y no queda nada a medias. Es el mismo
comportamiento en el que ya se apoya `RepositorioDeProductosFirestore.crear`.

### 2. La transacción devuelve un resultado, y no lanza desde adentro

El handler devuelve uno de tres resultados: se cambió, ya era la principal o ya
no está. La excepción se arma **afuera** de `runTransaction`. Así no se depende
de cómo `cloud_firestore_web` hace cruzar una excepción propia por el puente de
promesas de JS, que en web puede llegar envuelta. `ya era la principal` **no
escribe**: cero escrituras si el operador toca algo que no cambia nada.

### 3. Una función pura, `conPrincipal`, para las dos rutas

`domain/foto_principal.dart`:
`List<String>? conPrincipal(List<String> imagenes, String url)`. Devuelve la
lista con `url` al frente y el resto en su orden relativo, o `null` si `url` no
está. La usan:

- el repositorio de Firebase, **adentro** de la transacción, sobre lo que acaba
  de leer;
- `SeccionDeFotos` en un alta sin guardar, sobre `_agregadasLocalmente`.

Es la única pieza con lógica de este cambio, y la que se prueba con
`dart test`, incluidos los casos borde: vacía, una sola, ya primera, ausente y
URLs repetidas. El `arrayUnion` impide que haya repetidas, pero la función no
lo supone.

### 4. `ErrorDeFotos.yaNoEsta`, y dos textos que dejan de decir "subir"

`yaNoEsta` es el único motivo nuevo: *otra persona sacó esa foto*. Lo arma el
repositorio cuando `conPrincipal` devuelve `null` sobre la lectura fresca, y
nunca llega desde un SDK.

`sinPermiso` y `desconocido` hoy dicen "subir", porque cuando se escribieron
sólo servían a la subida. Pasan a decir "cambiar las fotos" y "algo falló con la
foto". El aviso de un fallo al elegir la principal lleva adelante la operación
("No se pudo cambiar la principal: …"): hoy un fallo al sacar muestra la URL
como nombre, y una URL no le dice nada a quien carga el catálogo.

### 5. La pantalla: una marca y un botón por renglón

`RenglonDeFoto` recibe tres cosas nuevas. `esPrincipal` dibuja la marca
"Principal · la que se ve en la tienda". `alUsarComoPrincipal` es un
`VoidCallback?`: si es `null`, no hay botón. `cambiandoPrincipal` pone el botón
en "Cambiando…". `SeccionDeFotos` decide:

- con menos de dos fotos, ni marca ni botón (spec "La principal se marca sólo
  cuando hay para elegir");
- mientras un cambio está en curso, todos los botones de principal quedan
  apagados. Dos toques seguidos no disparan dos transacciones que compiten
  entre sí.

Un botón de texto y no un ícono: lo usa gente no técnica, y una estrella sin
rótulo es una adivinanza. Sin confirmación: se deshace con otro toque
(criterio 3 del overview).

`widget-size-guard` corta en 200 líneas y `SeccionDeFotos` tiene 153. Si el
manejo nuevo la pasa, la marca sale a su propio archivo antes que partir la
sección.

## Risks / Trade-offs

- **[Nadie lo mira renderizado antes de producción]**: el panel no compila en
  esta máquina, y entrar pide una cuenta real. → El canal de preview y el
  pedido explícito al dueño: probarlo con un vino de dos fotos. El change **no
  se archiva** hasta que alguien lo haya usado.
- **[Cambiar la principal de un vino publicado cambia la tienda]**: es lo que
  se quiere, pero con el tramo 4 cada cambio va a costar una purga (ADR 016).
  → Anotado en el ADR: elegir la foto antes de publicar.
- **[La transacción reintenta, hasta cinco veces, con mucha concurrencia]**: con
  una familia cargando el catálogo, dos personas sobre el mismo vino en el
  mismo segundo es raro. Si se agotan los reintentos, el SDK da un código que
  ya se traduce a `sinConexion` (`retry-limit-exceeded`). El texto dice "probá
  de nuevo", y es lo correcto.
- **[Las reglas no exigen que la lista nueva sea una permutación de la
  vieja]**: un panel con un error podría escribir cualquier lista válida. Es la
  misma confianza que ya existe en el alta. → La invariante vive en
  `conPrincipal` y en sus tests. Llevarla a las reglas pediría comparar dos
  listas elemento a elemento, que las reglas no tienen cómo hacer sin
  desenrollar diez posiciones por lado.

## Migration Plan

1. Sin reglas ni functions: el deploy es **sólo `admin`**.
2. Antes de publicar: `git diff aff14bb..HEAD -- apps/admin` (lo que sirve live
   hoy) tiene que mostrar **sólo** este cambio. El deploy reconstruye desde el
   HEAD pusheado.
3. CI `alcance=panel`, después canal de preview y el canario (ver `tasks.md`),
   `promover` y `verificar`.
4. **Rollback**: `hosting:clone` de la versión anterior del sitio. El cambio no
   deja datos en otra forma: una `imagenes` reordenada sigue siendo válida para
   el panel viejo y para la vidriera.

## Open Questions

- Ninguna bloquea. **El default sin confirmación es decisión mía**, con el
  criterio 3 del overview. Queda para que el dueño lo confirme usándolo.
