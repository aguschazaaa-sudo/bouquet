## ADDED Requirements

### Requirement: El operador elige cuál foto es la principal

El panel MUST permitir elegir, entre las fotos de un vino, cuál es la principal, la primera de `imagenes`, que es la única que dibuja la vidriera.

Es un toque, sin confirmación: no se pierde nada y se deshace con otro toque.
Las demás fotos **conservan el orden relativo** que tenían: la elegida pasa al
frente y el resto se corre un lugar, sin reordenarse entre sí.

**No se ordenan las demás.** La vidriera lee sólo `imagenes[0]`
(`VentanaDeBotella.tsx:30`, `seleccion.ts:49`), así que el orden de la segunda
en adelante no le cambia nada a un comprador. Disparador: el día que la ficha
muestre más de una foto.

#### Scenario: Elegir la segunda como principal
- **WHEN** un vino tiene `[A, B, C]` y el operador toca "Usar como principal" en `B`
- **THEN** `imagenes` queda `[B, A, C]`
- **AND** la sección muestra `B` primera, marcada como principal

#### Scenario: Elegir la última
- **WHEN** un vino tiene `[A, B, C]` y el operador elige `C`
- **THEN** `imagenes` queda `[C, A, B]`: `A` y `B` no cambian de orden entre sí

#### Scenario: Deshacer
- **WHEN** el operador eligió `B` por error sobre `[A, B, C]`
- **THEN** elegir `A` deja otra vez `[A, B, C]`

#### Scenario: La que ya es principal
- **WHEN** la foto ya es la primera de `imagenes`
- **THEN** no ofrece "Usar como principal", y el panel no escribe nada

### Requirement: La principal se marca sólo cuando hay para elegir

Con dos fotos o más, la sección MUST marcar la primera como la principal y decir que es la que se ve en la tienda.

Con una sola foto, o ninguna, no aparece ni la marca ni el botón: no hay nada
que elegir, y una etiqueta sin alternativa es ruido para quien carga el
catálogo.

#### Scenario: Un vino con una foto
- **WHEN** el vino tiene una sola foto
- **THEN** la sección no muestra "Principal" ni "Usar como principal"

#### Scenario: Llega la segunda foto
- **WHEN** el operador sube una segunda foto a un vino que tenía una
- **THEN** la primera aparece marcada como principal y la nueva ofrece "Usar como principal"

### Requirement: Cambiar la principal no pierde la foto que subió otra persona

En un vino guardado, el panel MUST cambiar la principal con una transacción que relee `imagenes` y escribe la lista reordenada sólo si nadie la cambió desde esa lectura.

Es la única escritura del panel que reescribe `imagenes` entero, y por eso
choca con [ARQUITECTURA §5.3](../../../../../ARQUITECTURA.md#53-escrituras-concurrentes-en-arrays).
Lo que esa regla protege, que la segunda persona en guardar no borre la foto
que subió la primera, lo cuida la transacción: la lista que se escribe es una
permutación de la que se acaba de leer, y si otra escritura la cambió en el
medio, la transacción vuelve a leer y a calcular.

**Nunca** se reordena una lista que venga de la pantalla: la pantalla puede
estar vieja.

#### Scenario: Otra persona sube una foto en el medio
- **WHEN** el operador elige `B` en `[A, B]` y, entre la lectura y la escritura, otra persona agrega `C` con `arrayUnion`
- **THEN** `imagenes` queda `[B, A, C]`: la foto de la otra persona no se pierde

#### Scenario: Otra persona sacó la foto elegida
- **WHEN** el operador elige `B`, pero otra persona ya la sacó de `imagenes`
- **THEN** el panel no escribe nada
- **AND** avisa que no se pudo cambiar la principal porque esa foto ya no está

#### Scenario: Sin conexión
- **WHEN** el operador elige una principal sin red
- **THEN** el cambio no queda a medias: `imagenes` sigue como estaba y el panel dice que no hay conexión

### Requirement: En un alta sin guardar, la principal se elige en memoria

Mientras el vino todavía no está guardado, el panel MUST reordenar la lista local de fotos subidas, sin leer ni escribir Firestore, con la misma regla que en un vino guardado.

La lista reordenada es la que viaja en el alta (ADR 015 §5), así que el vino
nace con la principal que eligió el operador.

#### Scenario: Elegir la principal antes de guardar
- **WHEN** en un alta el operador sube `A` y `B`, elige `B` y después guarda
- **THEN** el documento nace con `imagenes: [B, A]`
- **AND** elegir la principal no hizo ninguna lectura ni escritura antes de guardar

### Requirement: Los fallos de fotos no hablan sólo de subir

Los textos de error de la sección de fotos MUST ser verdaderos para las tres operaciones que los usan: subir, sacar y elegir la principal.

Un fallo al elegir la principal **dice qué operación falló y por qué**, y no
muestra la URL de la foto: una URL no le dice nada a quien carga el catálogo.

#### Scenario: Sin permiso al elegir la principal
- **WHEN** las reglas rechazan el cambio de principal
- **THEN** el aviso dice que la cuenta no tiene permiso para cambiar las fotos, no "para subir fotos"
