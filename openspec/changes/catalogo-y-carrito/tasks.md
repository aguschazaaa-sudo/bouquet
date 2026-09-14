## 1. Contratos (`packages/contratos`, agente `contratos`)

- [x] 1.1 Crear `producto.ts` con los tipos `Producto` y `ProductoPublicado`, las
      listas `VARIETALES` y `COLORES`, y las funciones `esCorte`, `balde`
      (umbral de 6 botellas), `tope` (`max(0, min(stock, 12))`) y
      `textoDelBalde` (*Quedan pocas*, *Se agotó*).
- [x] 1.2 Escribir `armarCatalogo(productos, bodegas, popularidad)`: proyecta
      sin `stock` ni unidades, convierte las unidades en puesto, excluye y
      loguea los documentos que no validan y los slugs duplicados.
- [x] 1.3 Crear `carrito.ts` con el tipo `Carrito` v1
      (`{version, idCompra, lineas}`), `parsearCarrito` (rechaza ids
      repetidos, cantidades no enteras o menores que 1 y versiones
      desconocidas) y el tipo `PedidoDeCompra` con `precioUnitarioVisto`.
- [x] 1.4 Tests en el estilo del paquete, un caso por escenario de
      `specs/catalogo-producto`, con control positivo y negativo.
- [x] 1.5 Exportar desde `index.ts`. Verificar con `tsc --noEmit` y con los
      tests del paquete.

## 2. Reglas (agente `reglas`)

- [x] 2.1 Endurecer `productos` en `firestore.rules`: `tipo` inmutable,
      `stock` y `muestra` sólo del servidor (alta con `stock == 0`),
      `presentacion` inmutable, obligatorios en todo `update`,
      `keys().hasOnly`, y `varietales` con `hasOnly` sobre la lista cerrada.
- [x] 2.2 Agregar el bloque explícito de `metricas` (lectura sólo admin,
      escritura sólo del servidor) y cerrar la forma de `bodegas`
      (`nombre` y `slug`, con `muestra` del servidor). `bodegas` conserva la
      escritura del admin que ya tenía: el panel las da de alta, y sacársela
      no lo decidió ningún documento (corregido en apply).
- [x] 2.3 Escribir `scripts/ci/auditar_varietales.mjs`, que compara la lista
      de las reglas con la de `contratos` y sale con 1 si difieren, y
      sumarlo al alcance `rapido` de `ci.yml`. Control negativo: agregar un
      varietal sólo de un lado y ver que falla.
- [x] 2.4 Probar las reglas contra el emulador: un caso aceptado y uno
      rechazado por cada requisito de `specs/catalogo-producto`.
- [ ] 2.5 Desplegar las reglas de Firestore y de Storage a `bouquet-vinos`, y
      verificar comparando el ruleset publicado con el archivo, no por el
      mensaje del CLI.

## 3. Datos de muestra (`scripts/seed/`)

- [x] 3.1 Pasar el catálogo de `scratchpad/maquetas/catalogo.base.json` a
      `scripts/seed/catalogo.json` (20 vinos, bodegas y unidades
      simuladas), y las fotos elegidas a `scripts/seed/fotos/`, que se suma
      a `.gitignore`.
- [x] 3.2 Escribir `seed.mjs`: ADC con `projectId: 'bouquet-vinos'`, que se
      niega a correr contra otro proyecto; ids deterministas con `set`;
      fotos a WebP con `sharp`, nombradas por hash, rechazando lo que no sea
      imagen y el placeholder de "no disponible"; escribe
      `metricas/popularidad` con `simulada: true` y la lista de ids que
      sembró.
- [x] 3.3 Escribir `borrar.mjs`, que borra por esa lista de ids y nunca por
      `where('muestra', '==', true)`.
- [x] 3.4 Correr el seed dos veces y verificar por REST: 20 productos, un
      archivo por carpeta. Control positivo: un vino por nombre. Control
      negativo: un id inventado da 404.

## 4. La vidriera: datos (agente `tienda`)

- [x] 4.1 `server/firebase-admin.ts`: ADC cuando no hay claves en el entorno,
      siempre con `projectId` explícito.
- [x] 4.2 Leer `node_modules/next/dist/docs` (`08-caching`,
      `09-revalidating`, `use-cache`) y elegir el mecanismo de caché de
      datos con el criterio de `design.md` §1. Anotar la elección en el ADR.
- [x] 4.3 `server/catalogo.ts`: las tres lecturas, `armarCatalogo` y la caché
      de 60 s con el tag `catalogo`.
- [x] 4.4 Las cabeceras `Cache-Control` y `Cache-Tag` de `/vinos`,
      `/vinos/[slug]` y `/carrito`.
- [x] 4.5 Sacar `REVALIDACION_SECRET` y `/api/revalidar` de `.env.example`.

## 5. Lo visual: mostrador (elegida por el dueño el 2026-09-11, `design.md` §9)

- [x] 5.1 Escribir `docs/vault/design/tokens.md` y sumar a `tokens.css` los
      tokens del papel y la escala de marfil de la maqueta, con los contrastes
      calculados; `--tipo-cifras` con Libre Franklin por `next/font`, y
      `COLORES.papel` en `colores.ts`.
- [x] 5.2 `features/catalogo/`, de la hoja a la página: `VentanaDeBotella`
      (con el estado sin foto), `DatosDelVino`, `EstadoDelVino`,
      `TarjetaDeVino`, `filtros.ts` (puro, con tests: una cepa no incluye los
      cortes, lo agotado va al final), las pestañas de color, el panel de
      filtros, la barra del pulgar, el orden, `SinResultados`,
      `ListadoDeVinos` (con el estado en la URL por `replaceState`), la hoja
      de datos y `FichaDeVino`.
- [x] 5.3 `features/carrito/`: el almacén en `localStorage` con
      `parsearCarrito` e `idCompra` (en memoria si no hay `localStorage`),
      `ControlDeCompra` (el botón que se vuelve selector, con tope),
      `ContadorDelCarrito`, `AvisoDelCarrito`, la línea y la página.
- [x] 5.4 `Precio` en `shared/ui/` desde el día uno, porque lo importan las dos
      features, en un commit propio.
- [x] 5.5 `EnlaceCarrito` recibe el contador como slot, y `app/layout.tsx` se
      lo pasa y monta el aviso. Los controles de compra llegan a las tarjetas
      y a la ficha como elementos armados en `app/`. Sin imports entre
      features.
- [x] 5.6 Las rutas `app/vinos/page.tsx`, `app/vinos/[slug]/page.tsx` (con
      `notFound()`) y `app/carrito/page.tsx`. Borrar `PaginaEnObra` y
      `en-obra.css` si se quedan sin consumidores.
- [x] 5.7 El gate `data-catalogo-de-muestra`, con spread condicional (no
      `? 'true' : undefined`, que se filtra al payload RSC), medido en los
      dos estados.

## 6. Copy (agente `voz`)

- [x] 6.1 Pasar por `voz` todas las cadenas nuevas: filtros, órdenes, *caja de
      2*, el aviso de tope, el estado sin resultados y el carrito. Resolver
      *blends* o *cortes*.
- [x] 6.2 Contar los topes de `voz.md §8` sobre las cadenas, con el control
      positivo primero (`LC_ALL=C.UTF-8`, porque `grep -i` sin locale da cero).

## 7. Verificación

- [x] 7.1 `tsc --noEmit` en `contratos` y en `tienda`; el arnés de hooks; los
      enlaces de la documentación.
- [x] 7.2 `next build` + `next start` contra stage: `/vinos`, una ficha y
      `/carrito` dan 200; `/vinos/slug-inventado-de-control` da 404;
      `curl -I` muestra las cabeceras; el HTML tiene los nombres publicados y
      `data-catalogo-de-muestra`.
- [ ] 7.3 (Mirado a 1440 y 390 px emulados el 2026-09-11, con todos los estados;
      falta ver las FOTOS, que dan 400 hasta que se publiquen las reglas de
      Storage de 2.5.) Mirarlo renderizado a 1440 y a 390 px: el listado, una ficha, una
      caja de 2, un agotado, el vino sin foto y el carrito con sus estados
      feos. Abrir los PNG, no sólo medir.
- [x] 7.4 `revisor-pagos` sobre el diff de stock, precio y carrito
      (obligatorio en D).
- [x] 7.5 `cazador-de-puertas`: cada ruta nueva tiene enlace entrante, y cada
      componente nuevo tiene quién lo abra.

## 8. Documentación y cierre

- [x] 8.1 ADR 008 (catálogo, stock y carrito), con el presupuesto de lecturas
      y los hallazgos de `revisor-pagos` que quedan para `crearOrden`.
- [x] 8.2 Glosario: `tipo`, unidad de venta, caja de 2, compuesto, `idCompra`
      y popularidad.
- [x] 8.3 `_index.md`, con tope de 5: la entrada del cambio y los pendientes
      (tramo 4 antes del deploy público; las seis tarjetas de la home).
- [ ] 8.4 `/commit`, leyendo el diff, y preguntando si los cambios del dueño en
      `EnlaceCarrito` van en el mismo commit.
- [ ] 8.5 Deploy: las reglas ya están (2.5). La tienda sigue bloqueada por
      los gates existentes: decir cuáles y verificar stage por REST.
