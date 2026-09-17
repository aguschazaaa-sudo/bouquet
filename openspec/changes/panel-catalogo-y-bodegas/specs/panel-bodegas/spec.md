## ADDED Requirements

### Requirement: Ver las bodegas (HU-02.1)
El panel MUST mostrar las bodegas cargadas, ordenadas por nombre, con **cuántos
vinos tiene cada una**. MUST llegarse a ellas desde Catálogo: una pantalla sin
camino de entrada es una página huérfana.

#### Scenario: Todavía no hay ninguna
- **WHEN** el operador abre Bodegas y la colección está vacía
- **THEN** ve que no hay ninguna y el camino para cargar la primera, y no un vino inventado

#### Scenario: Cuántos vinos tiene cada una
- **WHEN** hay una bodega con tres vinos cargados
- **THEN** su renglón dice que tiene tres, sin una lectura extra de Firestore

### Requirement: Dar de alta una bodega (HU-02.1)
El alta MUST pedir sólo el **nombre** y MUST derivar el slug con `aSlug`. El
documento MUST escribirse con exactamente `{nombre, slug}`. MUST NOT guardarse
un nombre en blanco ni uno del que no salga un slug válido.

#### Scenario: Alta con un nombre normal
- **WHEN** el operador carga "Bodega Norton"
- **THEN** se crea un documento `{nombre: "Bodega Norton", slug: "bodega-norton"}`

#### Scenario: Un nombre del que no sale slug
- **WHEN** el operador escribe `"···"` y quiere guardar
- **THEN** el panel no guarda y dice que ese nombre no sirve

### Requirement: Avisar de las bodegas parecidas (HU-02.2)
Mientras se escribe el nombre de una bodega nueva, el panel MUST mostrar las que
se parecen según `seParecen`. MUST NOT impedir el alta: puede haber dos bodegas
con nombres parecidos de verdad. MUST NOT costar una lectura de Firestore.

#### Scenario: Cargar "Catena" cuando ya existe "Catena Zapata"
- **WHEN** el operador escribe "Catena" y ya existe "Catena Zapata"
- **THEN** el panel le muestra "Catena Zapata" antes de que guarde

#### Scenario: Un nombre que ya existe igual
- **WHEN** el nombre normalizado es idéntico a uno cargado
- **THEN** el panel lo dice con esas palabras, no como "parecida"

### Requirement: Corregir el nombre de una bodega (HU-02.3)
El nombre MUST poder corregirse. El **slug MUST NOT cambiar** al editar: la
bodega va a tener una página indexable y el slug de algo publicado no se mueve
(glosario). El `update` MUST escribir sólo `nombre`.

#### Scenario: Arreglar un error de tipeo
- **WHEN** el operador corrige "Bodgea Norton" a "Bodega Norton"
- **THEN** el nombre cambia, el slug sigue siendo el de antes, y los vinos de esa bodega muestran el nombre nuevo sin tocarlos

### Requirement: No borrar una bodega que tiene vinos (HU-02.4)
Con uno o más vinos apuntando a ella, el panel MUST NOT ofrecer borrar la
bodega y MUST decir por qué. Con cero vinos, el borrado MUST pedir confirmación
—no tiene vuelta atrás— y antes de borrar MUST volver a preguntarle a Firestore
si sigue sin vinos.

#### Scenario: Una bodega con vinos
- **WHEN** el operador abre una bodega que tiene dos vinos
- **THEN** no hay forma de borrarla, y el panel dice que primero hay que mover o despublicar esos vinos

#### Scenario: Una bodega vacía
- **WHEN** el operador borra una bodega sin vinos y confirma
- **THEN** la bodega desaparece de la lista

#### Scenario: Le cargaron un vino mientras tanto
- **WHEN** entre que se abrió la pantalla y se confirmó el borrado alguien le cargó un vino
- **THEN** el borrado no ocurre y el panel lo dice
