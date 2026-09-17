# Tareas

Workflow A. Orden de implementación = orden de deploy. Este cambio **no toca
`firestore.rules` ni `functions/`**: el deploy es sólo el panel.

## 1. `contratos` — la normalización

- [x] 1.1 `packages/contratos/src/texto.ts`: `normalizar`, `clave`, `aSlug`,
      `seParecen`. Exportar desde `index.ts`.
- [x] 1.2 `FIXTURES_DE_TEXTO`: los pares entrada→salida que viajan al JSON.
      Incluye `ñ`, `Torrontés`, espacios dobles y una cadena sin slug.
- [x] 1.3 `packages/contratos/test/texto.test.ts` con `node --test`.
- [x] 1.4 `scripts/generar.mjs` emite la sección `texto` y se regenera
      `generated/contratos.json`.
- [x] 1.5 `scripts/ci/auditar_estados.mjs`: que la sección `texto` exista y que
      el espejo de Dart la cubra. Control negativo incluido.

## 2. `apps/admin` — domain

- [x] 2.1 `core/contratos/texto.dart`: el espejo. Sin Firebase, sin Flutter.
- [x] 2.2 `test/core/contratos/texto_test.dart` contra las fixtures del JSON.
- [x] 2.3 `features/catalogo/domain/bodega.dart` — `{id, nombre, slug}`.
- [x] 2.4 `features/catalogo/domain/producto_del_panel.dart` — lo que el panel
      muestra hoy, y el nombre de la bodega resuelto o su ausencia.
- [x] 2.5 `features/catalogo/domain/repositorio_de_bodegas.dart` (puerto).
- [x] 2.6 `features/catalogo/domain/repositorio_de_productos.dart` (puerto).
- [x] 2.7 `features/catalogo/domain/catalogo.dart` — el cruce productos×bodegas,
      el filtro y el conteo por bodega. Dart puro: tiene test.
- [x] 2.8 `test/features/catalogo/catalogo_test.dart`.

## 3. `apps/admin` — data

- [x] 3.1 `data/repositorio_de_bodegas_firestore.dart`: `snapshots()`, `crear`,
      `corregirNombre`, `tieneVinos`, `borrar`.
- [x] 3.2 `data/repositorio_de_productos_firestore.dart`: `snapshots()` y el
      mapeo desde el documento crudo.
- [x] 3.3 `catalogo_providers.dart` — sin `autoDispose`.

## 4. `apps/admin` — presentation, de la hoja a la página

- [x] 4.1 `core/presentation/campo_de_busqueda.dart`.
- [x] 4.2 `core/presentation/estado_de_carga.dart` — cargando, error con
      reintento, y vacío con su explicación.
- [x] 4.3 `renglon_de_producto.dart` — nombre, bodega, precio, si está en la
      tienda, y el aviso de bodega inexistente.
- [x] 4.4 `lista_del_catalogo.dart`.
- [x] 4.5 `pantalla_del_catalogo.dart` — reemplaza el placeholder. Búsqueda
      arriba y el camino a Bodegas.
- [x] 4.6 `bodegas_parecidas.dart` — el aviso de HU-02.2.
- [x] 4.7 `hoja_de_bodega.dart` — alta y corrección, con el slug derivado a la
      vista y bloqueado en la edición.
- [x] 4.8 `renglon_de_bodega.dart` — nombre, slug, cuántos vinos, y el borrado
      sólo si tiene cero.
- [x] 4.9 `pantalla_de_bodegas.dart`.
- [x] 4.10 `rutas.dart` + `enrutador.dart`: `/catalogo/bodegas`.

## 5. Verificar lo escrito, antes de commitear

- [x] 5.1 `dart format` sobre todo lo tocado.
- [x] 5.2 `npx tsc --noEmit` y `npm run -w @bouquet/contratos test`.
- [x] 5.3 `node scripts/ci/auditar_estados.mjs`.
- [x] 5.4 `dart test` del panel (corre en segundos; `flutter test` está
      prohibido en esta máquina).
- [x] 5.5 `bash scripts/hooks/probar_hooks.sh` — 35/35.
- [x] 5.6 `node scripts/ci/verificar_enlaces.mjs .`
- [x] 5.7 **`cazador-de-puertas`**: que nadie quede huérfano. Con control
      negativo — un símbolo inventado tiene que dar 0.

## 6. Documentar, commitear, desplegar, verificar

- [x] 6.1 ADR 012 con el presupuesto de lecturas adentro.
- [x] 6.2 `_index.md` (tope 5) y el mapa del panel.
- [ ] 6.3 `/commit` leyendo el diff.
- [ ] 6.4 CI `alcance=panel`. **Leer la corrida, no el color.**
- [ ] 6.5 Deploy: bajar el artifact, canal de preview, `hosting:clone` a live.
      **Sin recompilar.**
- [ ] 6.6 Verificar en `bouquet-vinos.web.app` con el árbol de semántica:
      control positivo = un vino del seed que se sabe que está; control
      negativo = una búsqueda inventada que tiene que dar vacío.
- [ ] 6.7 `/opsx:archive` — último, después de verificar.
