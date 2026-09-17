import 'package:diacritic/diacritic.dart';

/// El espejo en Dart de `packages/contratos/src/texto.ts`. ARQUITECTURA §7:
/// la normalizacion vive en UN lugar, y el panel no tiene la suya.
///
/// **Lo que hace que esto no sea una segunda implementacion disfrazada** es
/// `test/core/contratos/texto_test.dart`, que corre cada fixture de
/// `packages/contratos/generated/contratos.json` contra estas funciones. Las
/// fixtures las calcula el TypeScript, y `scripts/ci/auditar_estados.mjs`
/// verifica que no envejezcan. Sin esa pieza el test compara contra un
/// contrato que ya no existe y pasa por nada.
///
/// **Por que hace falta `diacritic`:** Dart no trae normalizacion Unicode en
/// el SDK —no hay `String.normalize`—, asi que el `NFD` + sacar las marcas
/// combinantes del lado de TypeScript no se puede escribir igual aca. La
/// alternativa era una tabla de caracteres a mano, y una tabla a mano falla
/// **en silencio** con el caracter que nadie penso: `Château` quedaria
/// `ch-teau` y el operador veria ese slug sin entender por que.
///
/// ⚠️ **Donde termina el acuerdo, dicho a proposito.** `removeDiacritics`
/// traduce las ligaduras a ASCII —`Æ` da `ae`, `ß` da `s`— y el `NFD` de
/// TypeScript no: alla `æ` sobrevive a `normalizar` y lo tira el filtro de
/// `clave`. **El contrato son las fixtures**, no la igualdad para toda
/// entrada posible, y ninguna fixture usa una ligadura. Hoy eso no tiene
/// consumidor: el unico que deriva el slug de una bodega es este panel. El
/// dia que TypeScript tambien lo derive, la ligadura entra como fixture y
/// esto se decide.
///
/// El test fija las dos —`ae` y `s`— porque son lo que se MIDIO, no lo que se
/// supuso: la primera version de ese test decia `ss` para `ß` y fallo.

final _espacios = RegExp(r'\s+');
final _noAlfanumerico = RegExp(r'[^a-z0-9]+');
final _guionesDeLosBordes = RegExp(r'^-+|-+$');

/// Minusculas, sin acentos, sin espacios en los extremos y con los internos
/// colapsados en uno. **Conserva los espacios**: alimenta un `contains`.
String normalizar(String texto) =>
    removeDiacritics(texto).toLowerCase().trim().replaceAll(_espacios, ' ');

/// [normalizar] y ademas sin nada que no sea letra latina o numero, para
/// comparar nombres enteros. Puede dar la cadena vacia.
String clave(String texto) => normalizar(texto).replaceAll(_noAlfanumerico, '');

/// El slug que sale de un nombre, o `''` si del nombre no sale ninguno.
///
/// `''` NO cumple `esSlug` de `firestore.rules`, que es exactamente lo que
/// tiene que pasar: quien llama lo lee como "este nombre no sirve" y no
/// guarda. Devolver vacio en vez de lanzar es a proposito — el panel lo
/// muestra mientras se escribe, y un campo a medio llenar no es un error.
String aSlug(String texto) => normalizar(
  texto,
).replaceAll(_noAlfanumerico, '-').replaceAll(_guionesDeLosBordes, '');

/// `true` si la clave de uno contiene a la del otro: "Catena" contra
/// "Catena Zapata" (HU-02.2).
///
/// ⚠️ **Dos claves vacias, o una, dan `false`.** La cadena vacia esta
/// contenida en todas: sin este corte, toda bodega nueva pareceria un
/// duplicado de todo.
bool seParecen(String a, String b) {
  final x = clave(a);
  final y = clave(b);
  if (x.isEmpty || y.isEmpty) return false;
  return x.contains(y) || y.contains(x);
}
