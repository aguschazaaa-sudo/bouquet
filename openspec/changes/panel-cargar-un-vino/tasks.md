# Tareas

Workflow A. Orden de implementación = orden de deploy: `contratos` y reglas
primero, el panel después. **Sin `functions/` y sin tienda.**

## 1. `contratos` — la graduación

- [x] 1.1 `packages/contratos/src/producto.ts`: `FichaVino.graduacion`
      (`number | null`, décimas), las constantes del rango (50–250) y su
      validación en `validarFicha`. Entero, ausente o `null`.
- [x] 1.2 `packages/contratos/test/producto.test.ts`: acepta `135`, ausente y
      `null`; rechaza `13.5`, `14`, `1350` y un texto.
- [x] 1.3 `npm run -w @bouquet/contratos test` y `npx tsc --noEmit` en
      `contratos` y en `apps/tienda` (la tienda importa `FichaVino`).

## 2. Reglas — el slug es el id, y la graduación

- [x] 2.1 `firestore.rules`: `fichaValida` acepta `graduacion` (ausente,
      `null` o entero 50–250); `productos` exige `slug == productoId` al crear
      y `slug` sin cambios al actualizar.
- [x] 2.2 `scripts/reglas/productos.test.mjs`: los casos nuevos, cada uno con
      su aceptado y su rechazado — id igual y distinto al slug, cambiar el
      slug, corregir uno de muestra, las cuatro graduaciones del spec.
- [x] 2.3 **El batch de varietales, en el emulador:** dos `update` al mismo
      documento —`arrayUnion` y después `arrayRemove`— reemplazando el
      **único** varietal. Si las reglas lo rechazan, se para y se decide la
      alternativa de `design.md §5` antes de seguir.
- [x] 2.4 Correr la suite entera contra el emulador
      (`firebase emulators:exec --only firestore --project demo-bouquet`).
      Contar los casos antes y después: la resta tiene que ser los nuevos.

## 3. Los varietales del panel, auditados

- [x] 3.1 `apps/admin/lib/core/contratos/producto.dart`: `varietales` entre
      las marcas `// varietales:inicio` y `// varietales:fin`, los colores, y el
      rango de la graduación.
- [x] 3.2 `scripts/ci/auditar_varietales.mjs`: compara también el archivo de
      Dart. **Control negativo:** una copia con una uva de más sale con 1.

## 4. `apps/admin` — domain (Dart puro, con tests)

- [x] 4.1 `domain/numeros_escritos.dart`: `leerPesos` y `leerGraduacion`, con
      el motivo de cada rechazo.
- [x] 4.2 `test/features/catalogo/numeros_escritos_test.dart`: la tabla de
      `design.md §3` entera, más la graduación.
- [x] 4.3 `domain/ficha_del_vino.dart` y `ProductoDelPanel` con la ficha
      entera y `muestra`. `catalogo.dart` sigue andando (`bodegaId`).
- [x] 4.4 `domain/borrador_de_vino.dart`: el borrador, `revisar(catalogo)` →
      problemas por campo, `AltaDeVino` y `CambiosDeVino`.
- [x] 4.5 `Catalogo`: el vino por id, el dueño de un slug (real o de muestra) y
      las regiones en uso. Cero lecturas.
- [x] 4.6 `test/features/catalogo/borrador_de_vino_test.dart`: obligatorios,
      slug vacío, choque con real y con muestra, el diff sólo con lo que
      cambió, varietales agregados y quitados, precio fijo si está publicado.
- [x] 4.7 `RepositorioDeProductos`: `crear(AltaDeVino)` y
      `corregir(id, CambiosDeVino)`.

## 5. `apps/admin` — data

- [x] 5.1 El mapeo lee la ficha entera y `muestra`, con los valores por
      omisión seguros.
- [x] 5.2 `crear`: transacción sobre `productos/{slug}` que se niega si existe,
      y **la única factory** del documento nuevo.
- [x] 5.3 `corregir`: `WriteBatch` con los campos que cambiaron (rutas con
      punto adentro de `fichaVino`) + `arrayUnion`, y después `arrayRemove`.
- [x] 5.4 `HojaDeBodega.mostrar` devuelve el id de la bodega creada.

## 6. `apps/admin` — presentation, de la hoja a la página

- [x] 6.1 `campo_de_precio.dart` — el texto y la vista previa con `enPesos`.
- [x] 6.2 `campo_de_graduacion.dart`.
- [x] 6.3 `eleccion_de_varietales.dart` — chips de la lista cerrada.
- [x] 6.4 `eleccion_de_color.dart`.
- [x] 6.5 `campo_de_bodega.dart` — elegir de la lista, o cargar la que falta.
- [x] 6.6 `campo_de_region.dart` — con sugerencias de las regiones en uso.
- [x] 6.7 `botellas_por_unidad.dart` y `confirmacion_de_caja.dart` (HU-03.3).
- [x] 6.8 `direccion_del_vino.dart` — el slug a la vista, el choque, y fijo al
      corregir.
- [x] 6.9 `formulario_del_vino.dart` — ordena las secciones, lee `revisar` y
      guarda con `try/catch`.
- [x] 6.10 `pagina_del_vino.dart` — alta o corrección, cargando, y "no existe".
- [x] 6.11 `rutas.dart` + `enrutador.dart`: `/catalogo/nuevo` y
      `/catalogo/vinos/:id`. Casos en `destino_test.dart`.
- [x] 6.12 Las puertas: "Cargar un vino" en Catálogo y el renglón tocable.

## 7. Verificar lo escrito, antes de commitear

- [x] 7.1 `dart format` sobre todo lo tocado.
- [x] 7.2 `dart analyze lib test` en el panel.
- [x] 7.3 `dart test` del panel; `npm test` y `npx tsc --noEmit`.
- [x] 7.4 `node scripts/ci/auditar_varietales.mjs` y
      `node scripts/ci/auditar_estados.mjs`.
- [x] 7.5 `bash scripts/hooks/probar_hooks.sh`, y los hooks del panel sobre
      los archivos nuevos **con ruta absoluta** y un canario positivo.
- [x] 7.6 `node scripts/ci/verificar_enlaces.mjs .`
- [x] 7.7 **`cazador-de-puertas`**: nadie huérfano, con control negativo.

## 8. Documentar y commitear

- [x] 8.1 ADR 013 con el presupuesto de lecturas adentro; ADR 008 apunta a él
      por la reserva de slugs que reemplaza.
- [x] 8.2 Glosario (`graduacion`, el slug fijo desde el alta), EP-03 (el
      hallazgo de `descripcion`), mapa del panel y `_index.md` (tope 5).
- [x] 8.3 `/commit` leyendo el diff.

## 9. Desplegar y verificar — reglas → panel

- [x] 9.1 Comparar el ruleset publicado con `HEAD`: la diferencia es sólo la de
      este change.
- [ ] 9.2 **Reglas** — `firebase deploy --only firestore:rules`, lo corre el
      usuario o lo autoriza. Verificar con la API de Rules: el ruleset nuevo
      contiene `slug == productoId` y `graduacion` (control negativo: un texto
      inventado da 0).
- [ ] 9.3 CI `alcance=panel`. **Leer la corrida, no el color.**
- [ ] 9.4 `publicar.sh preview` → hashes, canarios (uno nuevo y uno que
      desaparece, sin tildes: `dart2js` los escapa) y que la app arranca sin
      errores de consola.
- [ ] 9.5 `publicar.sh promover` y `publicar.sh verificar` sobre live.
- [ ] 9.6 **Que alguien cargue un vino de verdad y lo mire renderizado.** Sin
      esto el change no se archiva.
- [ ] 9.7 `/opsx:archive`, recién después de 9.6.
