## 1. La regla, en contratos

- [x] 1.1 Agregar `BOTELLAS_POR_CAJA = 6` a `packages/contratos/src/carrito.ts`, con el comentario de por qué el número vive en un solo lugar
- [x] 1.2 Escribir `botellasEnCarrito(resuelto)`: `Σ cantidad × presentacion.botellas` sobre las líneas **vigentes** solamente
- [x] 1.3 Escribir `estadoDeLaCaja(resuelto)` → `{ botellas, cajasCompletas, faltan, sobran }`
- [x] 1.4 Tests de `venta-por-caja`: los dos casos de presentaciones mezcladas, la línea agotada que no llena, y los cuatro estados (4, 6, 7, 12 botellas) más el carrito vacío
- [x] 1.5 Test que prueba que **`parsearCarrito` NO cambió**: un carrito de 4 botellas se acepta y sobrevive al round-trip
- [x] 1.6 Test del cambio de tamaño: con `BOTELLAS_POR_CAJA` en 3, los estados dan los valores de cajas de 3

## 2. Las cajas sugeridas, en contratos

- [x] 2.1 Crear `packages/contratos/src/cajas.ts` con el tipo del documento y `validarCajasSugeridas`
- [x] 2.2 Exigir que cada sugerencia sume **exactamente** `BOTELLAS_POR_CAJA` botellas, contando `presentacion.botellas`
- [x] 2.3 Descartar e informar: sugerencia corta, slug duplicado (las dos afuera), documento entero inválido
- [x] 2.4 Escribir `resolverCajasSugeridas(cajas, catalogo)`: el join **en memoria** contra la proyección, marcando los lugares sin producto y los agotados (design §9)
- [x] 2.5 Tolerar que el documento **no exista**: devuelve cero cajas, no un error — como `leerUnidades` con `metricas/popularidad`
- [x] 2.6 Tests de `cajas-sugeridas`: los dos casos válidos, la sugerencia corta, el slug duplicado, el componente despublicado y el agotado
- [x] 2.7 Exportar todo lo nuevo desde `packages/contratos/src/index.ts`
- [x] 2.8 `npx tsc --noEmit` en el paquete, con control positivo (`--listFiles` muestra `cajas.ts`)

## 3. Las reglas y los datos

- [x] 3.1 Agregar la colección a `firestore.rules`: lectura pública, **escritura de nadie** desde el cliente
- [x] 3.2 Casos en `scripts/reglas/`: uno aceptado (lectura anónima) y uno rechazado (escritura anónima), contra el emulador
- [x] 3.3 Agregar cajas sugeridas de muestra a `scripts/seed/catalogo.json`, marcadas `muestra: true`, armadas con ids que ya existen
- [x] 3.4 Extender `seed.mjs` para sembrarlas con `set()`, re-ejecutable; y `borrar.mjs` para borrarlas por id
- [x] 3.5 Correr el seed **dos veces** y verificar por REST que el resultado es idéntico

## 4. La lectura, en la tienda

- [x] 4.1 Escribir `leerCajasSugeridas()` en `apps/tienda/src/server/catalogo.ts`, como función propia
- [x] 4.2 Componerla dentro del `Promise.all` de `obtenerCatalogo`, **no** en un `unstable_cache` nuevo y **no** dentro de `leerCatalogoSinCache` (design §8)
- [x] 4.3 Extender `test/revalidacion.test.ts` para que falle si la home importa la lectura de cajas
- [x] 4.4 Verificar en el `next build` que `/` sigue saliendo `○` (estática) y `/vinos` con `1m` como control

## 5. El dibujo, antes del primer componente

- [x] 5.1 Correr `/disenio` para el carril, la tarjeta de caja sugerida y el contador de avance de la barra
- [x] 5.2 Maquetar y **mirar el PNG** a 1440 y 390 px emulados antes de escribir el primer `.tsx`
- [x] 5.3 Pasar todos los textos nuevos por `voz` — el aviso, el faltante, el sobrante y el nombre del carril

## 6. Los componentes, de la hoja a la página

- [x] 6.1 `TarjetaDeCajaSugerida.tsx` — la hoja: seis nombres, los lugares marcados, el botón
- [x] 6.2 `CarrilDeCajas.tsx` — la fila; **no se renderiza si no hay ninguna sugerencia válida**
- [x] 6.3 Enchufar el carril en `/vinos` pasando el control por props desde `app/`, sin que `catalogo/` importe `carrito/` (ADR 006)
- [x] 6.4 El aviso de venta por caja en el listado y en la ficha, **una vez por listado**, en el HTML servido
- [x] 6.5 `ContadorDelCarrito`: el avance sobre el tamaño de la caja, desde `localStorage`
- [x] 6.6 `PaginaDelCarrito`: faltan **o** sobran, el camino más corto, nunca los dos; el vacío no reclama
- [x] 6.7 Verificar que **no** aparece ningún control de terminar la compra, ni con la caja completa
- [x] 6.8 Tests de la tienda para el carril vacío, el tope que corta el agregado y el agregar-sin-reemplazar

## 7. Verificación — con control positivo y negativo

- [x] 7.1 `dart format` no aplica; correr `npx tsc --noEmit` en contratos y en la tienda, los dos exit 0
- [x] 7.2 Contar las lecturas de una reconstrucción de `/vinos`: tiene que dar **33** con el catálogo de muestra. **Control:** una reconstrucción sin carril da 32
- [x] 7.3 El aviso llega sin JavaScript: `curl` de `/vinos` y de una ficha. **Control negativo:** el string no aparece en `/oficio`
- [x] 7.4 Verificar que el canario del aviso es **nuevo**: grepear el repo antes de usarlo como control
- [x] 7.5 Mirar renderizado a 1440 y 390 px: el carril con cajas, sin cajas, con un lugar agotado, y el carrito en 4, 6 y 7 botellas
- [x] 7.6 `bash scripts/hooks/probar_hooks.sh` sigue en verde, y `node scripts/ci/verificar_enlaces.mjs .`
- [x] 7.7 `gh workflow run ci.yml -f alcance=tests` — **es lógica, no UI**, así que no alcanza con el `rapido` del push

## 8. Cerrar

- [x] 8.1 Correr `cazador-de-puertas`: que el carril tenga call site y que nada quede escrito sin quien lo abra
- [x] 8.2 Correr `revisor-pagos` — **obligatorio en Workflow D**, aunque acá no se cobre todavía
- [x] 8.3 `post-task-doc`: ADR nuevo con el presupuesto de lecturas adentro; `_index.md` al tope de 5; el pendiente de `crearOrden` con su noveno punto
- [x] 8.4 Agregar al glosario: `Caja sugerida`, y corregir `Compuesto` para que diga que sigue sin usarse y por qué
- [x] 8.5 `/commit`, leyendo el diff en conversación

## 9. Desplegar y verificar producción

- [x] 9.1 Desplegar `reglas` — primero, siempre
- [x] 9.2 Verificar las reglas con la **API de Rules**, no con el mensaje del CLI
- [x] 9.3 Correr la lectura real del documento contra stage por REST, con control negativo (una ruta inventada da 404)
- [x] 9.4 ⚠️ **La tienda NO se despliega todavía**: siguen abiertos los cinco gates (reglas de Storage, puerta de edad, contacto provisorio, licencias de assets, 391 KB de fuentes). Anotar el cambio como **polizón pendiente** con fecha y disparador, y preguntarse **qué más se mergeó** el día que se publique
- [ ] 9.5 Cuando la tienda se despliegue: verificar el aviso y el carril con `curl` sobre producción, con control positivo y negativo, y recién ahí `/opsx:archive`
