## ADDED Requirements

### Requirement: El panel dice por qué un vino no aparece en la tienda (HU-03.7)
Para cualquier vino del catálogo, el panel MUST poder decir si la tienda lo
muestra y, si no lo muestra, **por qué**. Los motivos MUST ser los mismos que
`armarCatalogo` usa para descartar un documento, y MUST cubrir el caso de un
vino que está publicado y aun así no aparece.

Hoy esos motivos existen y **sólo se leen en el log del build**: un vino
publicado puede no aparecer nunca sin que nadie se entere.

#### Scenario: Un vino publicado que sí aparece
- **WHEN** el operador abre un vino publicado que valida
- **THEN** el panel dice que está en la tienda y ofrece el enlace a su ficha

#### Scenario: Publicado pero con la bodega borrada
- **WHEN** el vino está publicado y su `bodegaId` no existe en `bodegas`
- **THEN** el panel dice que la tienda lo deja afuera porque su bodega no existe

#### Scenario: Publicado con un slug duplicado
- **WHEN** dos vinos publicados comparten el slug
- **THEN** el panel dice, **en los dos**, que la tienda deja afuera a los dos

#### Scenario: Sin publicar
- **WHEN** el vino no está publicado
- **THEN** el panel dice que no está en la tienda porque no se publicó, y ofrece publicarlo

#### Scenario: Publicado y sin fotos
- **WHEN** el vino está publicado y no tiene fotos
- **THEN** el panel dice que aparece, pero sin foto

### Requirement: El balde y el tope salen del contrato, no de una cuenta del panel (HU-03.7)
El balde (`disponible` · `quedan-pocas` · `agotado`) y el tope por pedido MUST
calcularse con la misma regla que `contratos`. El panel MUST NOT reimplementar
los umbrales ni compararlos a ojo en un widget.

El panel MUST mostrar además **el número exacto de stock**, que es un dato
interno: la tienda muestra el balde, el panel muestra los dos.

#### Scenario: El balde de un vino con poco stock
- **WHEN** un vino suelto tiene 6 botellas o menos en total
- **THEN** el panel lo muestra como "quedan pocas", igual que la tienda

#### Scenario: Una caja
- **WHEN** un producto viene en cajas y su stock en unidades por sus botellas da 6 o menos
- **THEN** el balde es "quedan pocas", contando botellas y no unidades

#### Scenario: Agotado
- **WHEN** el stock es 0 o menos
- **THEN** el balde es "agotado" y el tope por pedido es 0

#### Scenario: El operador ve el número
- **WHEN** el operador mira un vino con 3 unidades
- **THEN** ve "3" y el balde al lado, no sólo el balde

### Requirement: El espejo se verifica contra el contrato generado, no contra sí mismo
El balde, el tope y los motivos de descarte MUST viajar como **fixtures
calculadas por el TypeScript** dentro de `packages/contratos/generated/contratos.json`,
y el espejo en Dart MUST tener un test que lo compare contra ese archivo.

La frescura del archivo MUST verificarla `scripts/ci/auditar_estados.mjs`, y
esa auditoría MUST exigir en el bloque nuevo un **control positivo** y un
**control negativo**: si todas las fixtures dieran el mismo resultado, un
espejo que devuelve siempre lo mismo pasaría.

#### Scenario: El contrato quedó viejo
- **WHEN** alguien cambia el umbral del balde en TypeScript y no regenera el JSON
- **THEN** `auditar_estados.mjs` sale con 1 diciendo que el contrato está desactualizado

#### Scenario: El espejo se desvía
- **WHEN** el umbral del balde en Dart deja de coincidir con la fixture
- **THEN** el test de Dart falla nombrando la fixture que no coincide

#### Scenario: Fixtures sin discriminación
- **WHEN** las fixtures del balde no incluyen al menos un caso de cada balde
- **THEN** `auditar_estados.mjs` sale con 1 diciendo que falta el control

#### Scenario: Fixtures de descarte con los dos lados
- **WHEN** las fixtures de descarte no incluyen al menos un documento que SÍ entra al catálogo
- **THEN** `auditar_estados.mjs` sale con 1: sin el caso que pasa, no se distingue un validador de uno que rechaza todo
