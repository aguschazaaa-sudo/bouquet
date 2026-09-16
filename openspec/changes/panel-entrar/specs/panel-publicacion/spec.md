## ADDED Requirements

### Requirement: El build del panel corre en CI y sólo a pedido
`ci.yml` MUST tener un alcance `panel` que corre la suite de Dart, el análisis
estático y `flutter build web --release`. MUST NOT correr en un push ni en un PR.
El resultado MUST subirse como artifact con un `SHA256SUMS` de todos los
archivos y el commit del que salió.

#### Scenario: Push a main
- **WHEN** se pushea a `main`
- **THEN** el job del build del panel sale `skipped`

#### Scenario: Pedido a mano
- **WHEN** se dispara `ci.yml` con `alcance=panel`
- **THEN** hay un artifact `panel-web` con `SHA256SUMS` y `COMMIT`

### Requirement: Se publican los bytes que se verificaron
`scripts/panel/publicar.sh` MUST bajar el artifact de una corrida, comprobar
cada hash contra `SHA256SUMS` y rechazar la publicación si alguno no coincide o
si la corrida no terminó en `success`. MUST subirlo a un canal de preview, y la
promoción a live MUST hacerse con `hosting:clone` desde ese canal, no con un
deploy nuevo.

#### Scenario: Un archivo alterado
- **WHEN** un archivo del artifact no coincide con su hash
- **THEN** el script sale con error y no sube nada

#### Scenario: Promover
- **WHEN** el canal de preview fue verificado y se promueve
- **THEN** live sirve el mismo `main.dart.js` que el canal, byte por byte
