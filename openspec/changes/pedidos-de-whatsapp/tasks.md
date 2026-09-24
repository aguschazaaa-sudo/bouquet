## 1. Contratos: el estado, la proyección y el pedido

- [x] 1.1 `orden.ts`: `por_fuera` en `ESTADOS_PAGO`, en `NACE_PAGO` y en `TRANSICIONES_PAGO` (vacía); `ORIGENES` y `estadoDePagoInicial`
- [x] 1.2 `proyeccion.ts`: estado público `por_preparar`, los 36 pares, su rótulo y su lugar en `REQUIEREN_ACCION`
- [x] 1.3 `pedido.ts`: `PedidoDelPanel`, `parsearPedidoDelPanel`, `ItemDeOrden`, `TOPE_DE_LINEAS`; rechaza línea repetida, `origen`/`estadoPago` y datos de entrega inválidos
- [x] 1.4 Fixtures de teléfono calculadas (`ENTRADAS_DE_TELEFONO`) y `generar.mjs` emite los 36 pares, el origen, el pedido y los teléfonos
- [x] 1.5 Tests de `contratos` (`orden`, `proyeccion`, `pedido`): los 36 pares, `por_fuera` sin entrada ni salida, `entroEnPagada` falso; **mutar** un par y ver que falla
- [x] 1.6 Bump de versión, **después** `node packages/contratos/scripts/generar.mjs`, y `scripts/ci/auditar_estados.mjs` en verde

## 2. Contratos en el panel (Dart)

- [x] 2.1 `estado_pago.dart` con `por_fuera`; `estado_publico.dart` con `por_preparar` y los 36 pares
- [x] 2.2 `core/contratos/telefono.dart`, espejo de `normalizarTelefonoAR`
- [x] 2.3 Los tests de Dart contra el JSON (`estados_orden_test`, `telefono_test`); `dart analyze lib test` limpio

## 3. Reglas de `ordenes`

- [ ] 3.1 `list` con `request.query.limit <= 50`; `get` sin cambios; `create`/`delete` siguen en `false`
- [ ] 3.2 `scripts/reglas/ordenes.test.mjs`: admin lee con `limit(25)` y `limit(50)`; falla con 51 y sin límite; comprador y anónimo no leen; nadie crea ni borra; el admin **no** puede escribir `origen`, `estadoPago`, `items`, `numero` ni `total`; `contadores` cerrado
- [ ] 3.3 Correr la suite contra el emulador y **mutar** la regla del límite para ver que falla exactamente el caso que la prueba

## 4. `functions`: la transacción

- [ ] 4.1 `functions/src/pedidos/armar.ts`: núcleo puro (existe/simple/no-muestra, precio visto, stock, snapshot, total)
- [ ] 4.2 `functions/test/pedidos/armar.test.ts` con `node --test`, un caso que aplica y uno que rechaza por cada requisito de `crear-orden-del-panel`
- [ ] 4.3 `functions/src/pedidos/crear.ts`: la transacción con el documento como marcador, `maxAttempts: 10` y `ReglasDeOrigen`
- [ ] 4.4 `functions/test/pedidos/crear.emulador.mjs`: atomicidad, concurrencia real, números consecutivos, reintento con y sin las mismas líneas, reintento tras vaciar el stock. **Mutar** la rama del marcador y la baranda de stock: fallan exactamente los casos que las prueban
- [ ] 4.5 `functions/src/pedidos/crear_orden_del_panel.ts` (`exigirAdmin` → parseo → núcleo) y su export en `index.ts`
- [ ] 4.6 `npm run tipos` y `npm run construir` en `functions/`; `bash scripts/hooks/probar_hooks.sh`

## 5. Revisión y deploy del backend

- [ ] 5.1 `revisor-pagos` sobre reglas + `functions` + `contratos`, **antes del commit**. Corregir lo ALTO y MEDIO; anotar el resto con su disparador
- [ ] 5.2 Commit del backend (`commit`), `gh workflow run ci.yml -f alcance=tests` y leer la resta contra la corrida anterior
- [ ] 5.3 Deploy de reglas; verificar con la API de Rules (idéntico byte a byte, control positivo y negativo)
- [ ] 5.4 Deploy de `functions --only functions:crearOrdenDelPanel`; verificar con la API de Cloud Functions (`ACTIVE`, v2, callable) y los tres controles: preflight 204, `POST` anónimo 401 JSON, función inventada 404
- [ ] 5.5 **Correr la consulta de la bandeja** contra producción y confirmar que los dos índices de `ordenes` existen y resuelven

## 6. El panel: dominio y datos

- [ ] 6.1 `domain/`: `Orden`, `ItemDeOrden`, `PedidoACargar`, `LineaACargar`, `FalloDePedidos`, `RepositorioDePedidos`
- [ ] 6.2 `data/documento_de_la_orden.dart`: mapeo Firestore → `Orden`, `null` en un documento roto
- [ ] 6.3 `data/repositorio_de_pedidos_firebase.dart`: la callable, la bandeja (`limit(25)`, sin `snapshots()`), el detalle por id
- [ ] 6.4 Tests de Dart puros: el mapeo con documentos rotos, la traducción de cada código de error, `LineaACargar` que no pasa el stock, un `idPedido` que no cambia
- [ ] 6.5 `pedidos_providers.dart`

## 7. El panel: presentación, de la hoja a la página

- [ ] 7.1 `textos_de_pedidos.dart` (pasar por `voz` los que ve la familia)
- [ ] 7.2 Bandeja: `fila_de_pedido`, `selector_de_estado`, `lista_de_pedidos`, `pantalla_de_pedidos` (reemplaza la vacía)
- [ ] 7.3 Detalle: `seccion_de_items`, `seccion_de_contacto`, `pagina_del_pedido`
- [ ] 7.4 Cargar: `renglon_de_linea`, `elegir_vinos`, `datos_de_entrega`, `pagina_de_cargar_pedido`
- [ ] 7.5 Rutas en `rutas.dart` y `enrutador.dart`; el acceso «Cargar un pedido» desde la bandeja
- [ ] 7.6 Los 4 hooks del panel sobre cada archivo nuevo con **ruta absoluta**; el canario con `Colors.red` bloquea; `dart format` y `dart analyze lib test` limpios

## 8. Cierre

- [ ] 8.1 Borrar `textoOcultarMovimientos`
- [ ] 8.2 `cazador-de-puertas`: cada símbolo nuevo con quien lo abra, control negativo con uno inventado
- [ ] 8.3 `presupuesto-lecturas` sobre la bandeja y el detalle
- [ ] 8.4 Vault: ADR 018 (sección *Verificación*), `_index.md` (tope 5), `EP-06`/`EP-10`, `overview.md`, `changelog`
- [ ] 8.5 Commit, CI `alcance=panel`, `publicar.sh preview` → canario discriminante → `promover` → `verificar`
- [ ] 8.6 Decir qué **no** se verificó: la carga real por un usuario, y que nadie lo miró renderizado
