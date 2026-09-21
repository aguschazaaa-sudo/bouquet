## ADDED Requirements

### Requirement: Poner un vino en la tienda y sacarlo (HU-03.6)
El panel MUST poder publicar un vino y despublicarlo, desde la página del vino
y desde el renglón del catálogo. El panel MUST NOT ofrecer borrar un producto
en ningún lado: un vino que no se vende más se despublica y conserva su id, su
slug y su historia.

Despublicar MUST ser inmediato y sin confirmación —tiene vuelta atrás con un
toque—. Publicar MUST pasar antes por la revisión previa.

#### Scenario: Publicar desde la página del vino
- **WHEN** el operador toca "Poner en la tienda" en un vino que pasa la revisión
- **THEN** el vino queda con `publicado: true` y el catálogo lo muestra "En la tienda" sin recargar

#### Scenario: Despublicar
- **WHEN** el operador toca "Sacar de la tienda" en un vino publicado
- **THEN** el vino queda con `publicado: false`, sin pedir confirmación, y se puede volver a publicar

#### Scenario: El panel no borra
- **WHEN** el operador busca cómo eliminar un vino
- **THEN** no existe esa acción en ninguna pantalla, y el panel explica que se saca de la tienda en vez de borrarse

#### Scenario: Un vino de muestra
- **WHEN** el operador abre un vino que tiene `muestra: true`
- **THEN** el interruptor no está disponible y el panel dice que los vinos de muestra los maneja el servidor

#### Scenario: La escritura rebota
- **WHEN** la escritura falla (sin red, permisos, reglas)
- **THEN** el vino vuelve a mostrarse como estaba y el panel dice qué pasó, sin dejar el interruptor a medio camino

### Requirement: Antes de publicar, el panel revisa lo mismo que la vidriera (HU-03.6)
Publicar MUST NOT estar disponible mientras el vino no pase **la misma
validación que usa la vidriera**. El panel MUST decir, campo por campo, qué
falta. Los motivos SHALL salir del espejo de `panel-espejo-vidriera`, nunca de
una lista escrita a mano en la pantalla.

Como mínimo MUST frenar: precio en cero, nombre vacío o sólo espacios, bodega
que no existe, una imagen que no es una URL `https://`, y un slug que ya usa
otro vino publicado.

La falta de fotos MUST NOT frenar la publicación: MUST avisar que el vino se
va a ver sin foto y dejar publicar igual.

#### Scenario: Precio en cero
- **WHEN** el operador intenta publicar un vino con precio 0
- **THEN** no puede, y el panel dice que un vino en la tienda necesita un precio mayor que cero

#### Scenario: La bodega no existe
- **WHEN** el vino apunta a un `bodegaId` que no está en `bodegas`
- **THEN** publicar no está disponible y el panel dice que la tienda lo dejaría afuera sin avisar

#### Scenario: Sin fotos
- **WHEN** el operador publica un vino sin ninguna foto
- **THEN** el panel avisa que se va a ver sin foto, y publicar sigue disponible

#### Scenario: Choque de slug con otro publicado
- **WHEN** el operador intenta publicar un vino cuyo slug ya lo usa otro vino publicado
- **THEN** no puede, y el panel dice que la tienda dejaría afuera a los dos

#### Scenario: Se arregla el motivo
- **WHEN** el operador corrige lo que faltaba
- **THEN** publicar queda disponible sin salir de la pantalla ni recargar

### Requirement: Cambiar el precio de un vino que está en la tienda (HU-03.5)
El formulario de corrección MUST seguir mostrando el precio fijo mientras el
vino está publicado. Cambiar ese precio MUST ser una acción propia y
deliberada, separada de corregir la ficha.

El panel MUST pedir confirmación cuando el precio nuevo se aparta mucho del
anterior, y la baranda SHALL evaluarse **sobre el valor nuevo**, no sólo sobre
el anterior. Un precio que no se aparta MUST guardarse sin confirmación.

#### Scenario: Un cambio chico
- **WHEN** el operador sube el precio de un vino publicado un 10 %
- **THEN** se guarda sin pedir confirmación

#### Scenario: El dedo gordo
- **WHEN** el operador escribe un precio que baja más del umbral respecto del anterior
- **THEN** el panel pide confirmación mostrando los dos precios en pesos, y sólo guarda si se confirma

#### Scenario: El precio de un vino que no está en la tienda
- **WHEN** el vino no está publicado
- **THEN** el precio se corrige en el formulario como cualquier otro campo, sin confirmación

#### Scenario: El formulario no lo toca
- **WHEN** el operador abre la corrección de un vino publicado
- **THEN** el campo del precio se ve y no se edita, con el acceso a "Cambiar el precio" al lado

### Requirement: La pantalla dice cuánto tarda en verse un precio (HU-03.5)
Después de cambiar el precio de un vino publicado, el panel MUST decir que el
precio nuevo puede tardar varios minutos en verse en la tienda. El texto MUST
nombrar un tiempo concreto, no "un rato".

#### Scenario: Después de confirmar
- **WHEN** el cambio de precio se guarda
- **THEN** el panel dice que la tienda puede tardar hasta unos 13 minutos en mostrarlo

#### Scenario: Un vino que no está en la tienda
- **WHEN** se corrige el precio de un vino no publicado
- **THEN** no aparece ese aviso, porque no hay nada publicado que se atrase
