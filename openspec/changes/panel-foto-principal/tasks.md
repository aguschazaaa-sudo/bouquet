## 1. Dominio: la regla, una sola vez

- [x] 1.1 Test primero, `apps/admin/test/features/fotos/foto_principal_test.dart`:
      `[A,B,C]` con `B` da `[B,A,C]`; con `C` da `[C,A,B]`; con `A` da la
      misma lista; una URL ausente da `null`; lista vacía da `null`; una sola
      foto con esa URL da la misma lista; repetidas: mueve la primera
      aparición y conserva el resto. **Deshacer**: elegir `B` y después `A`
      vuelve a `[A,B,C]`.
- [x] 1.2 `apps/admin/lib/features/fotos/domain/foto_principal.dart`:
      `List<String>? conPrincipal(List<String> imagenes, String url)`, pura, sin
      Flutter ni Firebase. Mutarla una vez (p. ej. `insert` al final) y ver que
      el test la agarra; después, revertir la mutación.
- [x] 1.3 `ErrorDeFotos.yaNoEsta` en `domain/fallo_de_fotos.dart`, con el
      comentario de que nunca llega desde un SDK.

## 2. Datos: la transacción

- [x] 2.1 `RepositorioDeFotos.hacerPrincipal({productoId, url})` en la
      interfaz, con el porqué de la transacción (§5.3) en el doc.
- [x] 2.2 `RepositorioDeFotosFirebase.hacerPrincipal`: `runTransaction` que
      lee `productos/{productoId}`, aplica `conPrincipal` sobre **lo leído** y
      **devuelve** uno de tres resultados (cambiada · ya era principal · ya no
      está). Escribe `tx.update` sólo si cambió. La excepción se arma
      **afuera** de la transacción (design, decisión 2). Los errores del SDK,
      por `comoFalloDeFotos`.
- [x] 2.3 Confirmar con grep que ninguna otra escritura del panel reescribe
      `imagenes` fuera del alta: `grep -rn "_campoDeImagenes\|'imagenes'"
      apps/admin/lib`.

## 3. Pantalla

- [x] 3.1 Textos en `textos_de_fotos.dart`: "Principal", "la que se ve en la
      tienda", "Usar como principal", "Cambiando…", el prefijo "No se pudo
      cambiar la principal", el texto de `yaNoEsta`, y `sinPermiso` y
      `desconocido` sin la palabra "subir" (design, decisión 4).
- [x] 3.2 `RenglonDeFoto`: `esPrincipal`, `alUsarComoPrincipal` (nullable: sin
      botón), `cambiandoPrincipal`. Un botón de texto, no un ícono.
- [x] 3.3 `SeccionDeFotos`: `_hacerPrincipal`. En un alta sin guardar,
      `conPrincipal` sobre `_agregadasLocalmente` y `alCambiarImagenesLocales`,
      sin tocar el repositorio. En un vino guardado, el repositorio. Con menos
      de dos fotos, ni marca ni botón. Durante un cambio, todos los botones de
      principal apagados.
- [x] 3.4 `widget-size-guard`: si `SeccionDeFotos` o `RenglonDeFoto` pasan
      200 líneas, la marca sale a su propio archivo.

## 4. Verificar local (lo que sí corre acá)

- [x] 4.1 `dart format` sobre los archivos tocados.
- [x] 4.2 `dart analyze lib test` en `apps/admin`: **No issues found**.
- [x] 4.3 `dart test test/features/fotos/foto_principal_test.dart`: sólo el
      archivo nuevo. La suite entera va a CI. **10/10**; mutada (`.reversed`
      sobre las anteriores) falla 1 y se revirtió. La mutación es débil: sólo
      la agarra el caso de tres fotos, no los de dos.
- [x] 4.4 Los hooks del panel con **ruta absoluta** sobre cada archivo tocado:
      0 bloqueos. Control positivo: un canario con `Colors.red` bloquea.
      **Medido así:** los hooks corrieron solos en cada `Write`/`Edit` del
      panel (el único bloqueo fue `vault-precheck`, antes de leer el ADR 015)
      y `probar_hooks.sh` da 35/35 con sus controles. No corrí el canario
      `Colors.red` aparte: lo cubre el arnés, no una prueba mía.

## 5. Nadie lo escribe sin que alguien lo abra

- [x] 5.1 Grepear el call site de cada símbolo nuevo (`conPrincipal`,
      `hacerPrincipal`, `yaNoEsta`, cada texto nuevo, los parámetros nuevos
      del renglón), con un control negativo inventado que dé 0. Ruta de
      entrada: `enrutador.dart` → `PaginaDelVino` → `FormularioDelVino` →
      `SeccionDeFotos` → `RenglonDeFoto`.

## 6. Documentar

- [x] 6.1 ADR 015, sección nueva para HU-04.2: la transacción contra §5.3, las
      alternativas descartadas, el **presupuesto de lecturas** (1 por cambio +
      1 por sesión abierta; 150/día = 0,3 %) y el disparador de lo que queda
      afuera (ordenar las demás: el día que la ficha muestre más de una foto).
- [x] 6.2 EP-04 (HU-04.2 recortada), `overview.md` (línea de construidas) y
      `_index.md` (tope 5), con el estado del hito 1 medido el 2026-09-24.
- [x] 6.3 Sacar HU-04.2 de *Lo que está pendiente* del `_index.md`; el
      pendiente pasa a ser "ordenar las demás", con su disparador.

## 7. Commit y CI

- [ ] 7.1 `/commit` leyendo el diff.
- [ ] 7.2 `git diff aff14bb..HEAD --stat -- apps/admin`: sólo este cambio.
      `aff14bb` es lo que sirve live, así que es lo que el deploy arrastra.
- [ ] 7.3 `gh workflow run ci.yml -f alcance=panel`. **Leer la corrida, no el
      color**: `suite_dart` tiene que subir exactamente los casos nuevos contra
      la corrida `35932577780` (244).

## 8. Desplegar el panel y verificar

- [ ] 8.1 `bash scripts/panel/publicar.sh preview <corrida>`: hashes y commit
      coinciden.
- [ ] 8.2 **Canario discriminante, sin tildes**, chequeado **nuevo** antes de
      usarlo (`grep` en el repo y 0 en el `main.dart.js` vivo): aparece
      `"Usar como principal"` y **desaparece** `"Tu cuenta no tiene permiso
      para subir fotos."`. Uno de cada lado, más un control inventado.
- [ ] 8.3 `publicar.sh promover panel`. No pushear nada entre 8.2 y 8.3.
- [ ] 8.4 `publicar.sh verificar https://bouquet-vinos.web.app`: los 4 hashes
      iguales al canal, `noindex`, y el canario de 8.2 dado vuelta en vivo.
- [ ] 8.5 Que la app arranca: Chrome headless por CDP sobre live, 0 errores de
      consola.

## 9. Lo que sólo puede hacer el dueño

- [ ] 9.1 **Subir dos fotos a un vino, elegir la segunda como principal y
      mirarla en la tienda.** Es también el disparador original de HU-04.2.
- [ ] 9.2 Confirmar o cambiar que el cambio va **sin confirmación**.
- [ ] 9.3 `/opsx:archive`, recién después de 9.1.
