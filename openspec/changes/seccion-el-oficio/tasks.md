## 1. El contenido, antes que cualquier componente

- [x] 1.1 Crear `apps/tienda/src/features/oficio/oficio.ts` con los tres tramos
      —`I Elegir`, `II Guardar`, `III Abrir`—, cada uno con su nombre, su título
      y sus párrafos, más el texto del sello. El copy sale de la maqueta.
- [x] 1.2 Marcar el tramo `III` en los datos con una bandera `firmado: false`,
      para que la distinción viva en el contenido y no en el CSS: es la tesis de
      la página, no un detalle de estilo.
- [x] 1.3 Exportar `EL_CONTACTO_ES_PROVISORIO = true`, el WhatsApp
      `+54 9 3548 60-0375` y la forma del mail, con el comentario que dice cómo
      se chequea el gate (grep en el repo, `curl` en producción).
- [x] 1.4 Correr el agente `voz` sobre `oficio.ts` y aplicar lo que devuelva.
      Es el único archivo con copy, así que es el único que hace falta pasar.
- [x] 1.5 Verificar los topes contables de `voz.md §8` sobre el archivo:
      exclamaciones **0**, emoji **0**, `tú`/`usted`/`tienes`/`puedes` **0**, y
      cero expresiones del dialecto de cata de `§7.1`. **Con control positivo:**
      insertar una expresión prohibida, confirmar que el grep la encuentra, y
      sacarla.

## 2. La hoja de estilo de la feature

- [x] 2.1 Crear `apps/tienda/src/features/oficio/oficio.css` con la plancha
      (`min(1080px, 100%)`), el eje central y la escala de la sección.
- [x] 2.2 Escribir los dos brazos de filete modulado (`.filete--izq`,
      `.filete--der`) con la modulación invertida en cada uno, para que el peso
      grueso caiga del lado del numeral. Nacen acá, no en `shared/deco/`.
- [x] 2.3 Escribir la capitular del primer párrafo de cada tramo, sólo el
      primero.
- [x] 2.4 Escribir el numeral hueco del tramo sin firmar **adentro de**
      `@supports (-webkit-text-stroke: 1px red)`, con `color: transparent` en la
      misma regla que el stroke. Sin soporte tiene que quedar macizo, nunca
      invisible.
- [x] 2.5 Escribir el corte de dos columnas con `@media (min-width: 1000px)` —
      **no** `@container`: eso era del andamio de la maqueta, no del diseño.
- [x] 2.6 Escribir el movimiento dentro de
      `@supports (animation-timeline: view())` +
      `@media (prefers-reduced-motion: no-preference)`, con el estado base
      dibujado entero.
- [x] 2.7 Enganchar el `@import` de `oficio.css` en `app/globals.css`
      **último**, que es donde va una feature en la cascada del ADR 006 §4.
- [x] 2.8 Verificar que `no-hardcoded-colors` no bloquea la hoja nueva: cero
      hex, `rgb()` y `hsl()` fuera de `tokens.css`.

## 3. Los componentes, del hoja a la página

- [x] 3.1 `ReglaNumerada.tsx` — el filete partido por el numeral romano. Es la
      hoja: no sabe qué tramo es, sólo recibe el número y si está firmado.
- [x] 3.2 `Tramo.tsx` — un tramo entero. Usa `ReglaNumerada` y recibe un tramo
      de `oficio.ts`.
- [x] 3.3 `SelloDeContacto.tsx` — el cierre, con `id="mostrador"`, sin
      formulario, y emitiendo `data-contacto-provisorio` cuando la constante da
      `true`.
- [x] 3.4 `SeccionOficio.tsx` — compone la apertura, los tres tramos y el sello.
- [x] 3.5 Verificar que ningún componente pasa de 200 líneas
      (`widget-size-guard`) y que cada archivo publica un solo widget
      (`one-widget-per-file`).

## 4. La ruta, y las dos que se van

- [x] 4.1 Crear `apps/tienda/src/app/oficio/page.tsx` con su `metadata` y el
      call site de `SeccionOficio`.
- [x] 4.2 En **un solo commit**: cambiar `secciones.ts` a dos entradas
      (`/vinos`, `/oficio`), borrar `app/custodia/page.tsx` y
      `app/contacto/page.tsx`, y agregar el `redirects()` de `/contacto` →
      `/oficio#mostrador` en `next.config.ts`. Separarlos deja una ventana con
      la barra apuntando a un 404.
- [x] 4.3 Verificar que `PaginaEnObra` conserva sus dos consumidores restantes
      (`/vinos` y `/carrito`) y que `call-site-guard` no la marca huérfana.
- [x] 4.4 Verificar que `frontera-features.sh` no bloquea: `grep -rn
      "features/landing" apps/tienda/src/features/oficio/` sin coincidencias.
- [x] 4.5 Verificar que la feature no toca Firestore:
      `grep -rniE "firebase|firestore" apps/tienda/src/features/oficio/` sin
      coincidencias.

## 5. Verificar mirando, que es lo que este proyecto aprendió a los golpes

- [x] 5.1 `npx tsc --noEmit --project apps/tienda`, exit 0, **con control
      positivo**: `--listFiles` tiene que mostrar los archivos nuevos.
- [x] 5.2 `next build`, y confirmar que `/oficio` sale **estática** en la lista
      de rutas y que `/custodia` ya no aparece.
- [x] 5.3 `next start` y **abrir el PNG de una captura** a 390 px y a 1440 px.
      No `next dev`: en esta máquina sólo hidrata en `localhost`, no en
      `127.0.0.1`.
- [x] 5.4 A 390 px: una sola columna de prosa por tramo, sin regla vertical, y
      `scrollWidth` del `body` que no supera al `clientWidth`.
- [x] 5.5 A 1440 px: dos columnas con regla dorada, y **medir el alto de cada
      tramo**. Si alguno pasa el viewport, ese tramo va a una columna.
- [x] 5.6 **Mirar el numeral hueco del tramo III** y decidir si se lee como
      decisión o como defecto. Si falla, aplicar el plan B del design.md.
- [x] 5.7 Verificar las rutas sobre la build de producción: `/oficio` da 200,
      `/custodia` da 404, `/contacto` da 308 hacia `/oficio#mostrador`.
      **Control negativo:** `/ruta-inventada-de-control` da 404.
- [x] 5.8 Verificar el gate del contacto en el HTML servido:
      `curl -s localhost:3000/oficio | grep -c data-contacto-provisorio` da 1.
- [x] 5.9 Con `prefers-reduced-motion: reduce`: ninguna animación corre y el
      `scrollHeight` es idéntico al de la corrida sin la preferencia.
- [x] 5.10 Correr `cazador-de-puertas` sobre la feature: que todo lo escrito
      tenga quién lo abra, y que `/oficio` esté en el sitemap.

## 6. Los hooks, la doc y el commit

- [x] 6.1 `bash scripts/hooks/probar_hooks.sh` — 35/35, **más** controles
      directos sobre los globs que este cambio toca.
- [x] 6.2 `node scripts/ci/verificar_enlaces.mjs .` — todos los enlaces
      resuelven, incluidos los que este cambio agrega al vault.
- [x] 6.3 ADR nuevo en `docs/vault/architecture/decisions/`: el nombre de la
      sección, por qué `Custodia` bajó a nombrar un tramo, la fusión de
      `/contacto`, y por qué el vocabulario decó nuevo no viola
      `direccion.md §5.3`. Con el presupuesto de lecturas —**cero**— como campo.
- [x] 6.4 Actualizar `docs/vault/_index.md` respetando el tope de cinco
      entradas, y anotar el gate del contacto en "lo que quedó abierto" con
      fecha y disparador.
- [x] 6.5 `/commit`, leyendo el diff en conversación.

## 7. El deploy, y por qué no se hace todavía

- [x] 7.1 Dejar escrito, en el `_index.md`, que este cambio **no se despliega**:
      `EL_CONTACTO_ES_PROVISORIO` es el quinto gate abierto, junto con la puerta
      de edad, las seis fichas en 404, las licencias de los assets y los 391 KB
      de fuentes de la primera pantalla.
- [ ] 7.2 Cuando el dueño entregue el WhatsApp del cliente y el dominio: bajar
      la constante, volver a correr 5.7 y 5.8, y recién ahí desplegar `tienda`.
      **El deploy de front arrastra todo lo mergeado**, así que antes hay que
      preguntarse qué más entró.
