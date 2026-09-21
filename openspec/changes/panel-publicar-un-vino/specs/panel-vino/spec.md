## ADDED Requirements

### Requirement: El formulario del vino carga y corrige la descripción
El formulario de carga y el de corrección MUST tener un campo de texto largo
para la `descripcion`, con el tope de 600 caracteres visible y un contador de
lo que queda. Dejarlo vacío MUST guardar `null`, no una cadena vacía.

A diferencia del precio, la descripción MUST poder corregirse **también en un
vino publicado**: no es plata, no dispara la baranda, y corregir una falta de
ortografía no puede exigir sacar el vino de la tienda.

El campo MUST NOT frenar la publicación. Un vino sin descripción se publica; el
panel lo dice en la revisión previa, igual que dice lo de la foto.

#### Scenario: Cargar un vino con descripción
- **WHEN** el operador escribe una descripción y guarda
- **THEN** el documento queda con `fichaVino.descripcion` y el texto se ve al reabrir la ficha

#### Scenario: Dejarla vacía
- **WHEN** el operador guarda sin escribir nada en el campo
- **THEN** el documento queda con `descripcion: null`, no con `''`

#### Scenario: Pasarse del tope
- **WHEN** el operador escribe más de 600 caracteres
- **THEN** el formulario no deja guardar y dice cuántos sobran, antes de que las reglas lo reboten

#### Scenario: Corregirla en un vino publicado
- **WHEN** el operador corrige la descripción de un vino que está en la tienda
- **THEN** se guarda como cualquier otro campo, sin confirmación y sin despublicar

#### Scenario: Publicar sin descripción
- **WHEN** el operador publica un vino que no tiene descripción
- **THEN** el panel avisa que se va a ver sin texto, y publicar sigue disponible
