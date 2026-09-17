import 'dart:convert';
import 'dart:io';

import 'package:admin/core/contratos/texto.dart';
import 'package:test/test.dart';

/// ARQUITECTURA §7: la normalizacion vive en `packages/contratos` y el panel
/// la espeja. **Este test es lo que hace que el espejo no sea una segunda
/// implementacion**: corre las fixtures que calculo el TypeScript.
///
/// Es teatro si el JSON esta viejo — por eso no alcanza con que este verde:
/// `scripts/ci/auditar_estados.mjs` verifica que `contratos.json` sea
/// exactamente lo que produce hoy `packages/contratos/src/texto.ts`, y ademas
/// que este archivo exista y llame a las cuatro funciones.
///
/// La ruta al JSON es relativa a la raiz de ESTE paquete (`apps/admin/`), que
/// es el directorio de trabajo cuando corre `dart test`.
void main() {
  late Map<String, dynamic> texto;

  setUpAll(() {
    final archivo = File('../../packages/contratos/generated/contratos.json');
    final contrato =
        json.decode(archivo.readAsStringSync()) as Map<String, dynamic>;
    texto = contrato['texto'] as Map<String, dynamic>;
  });

  test('el contrato trae fixtures de texto', () {
    // Control positivo de la MEDICION, no de la implementacion: una seccion
    // vacia haria pasar todos los tests de abajo sin comparar nada.
    expect((texto['casos'] as List), isNotEmpty);
    expect((texto['pares'] as List), isNotEmpty);
  });

  test('normalizar da lo mismo que el TypeScript', () {
    for (final caso in texto['casos'] as List) {
      final c = caso as Map<String, dynamic>;
      expect(
        normalizar(c['entrada'] as String),
        equals(c['normalizar']),
        reason: 'entrada: "${c['entrada']}"',
      );
    }
  });

  test('clave da lo mismo que el TypeScript', () {
    for (final caso in texto['casos'] as List) {
      final c = caso as Map<String, dynamic>;
      expect(
        clave(c['entrada'] as String),
        equals(c['clave']),
        reason: 'entrada: "${c['entrada']}"',
      );
    }
  });

  test('aSlug da lo mismo que el TypeScript', () {
    for (final caso in texto['casos'] as List) {
      final c = caso as Map<String, dynamic>;
      expect(
        aSlug(c['entrada'] as String),
        equals(c['aSlug']),
        reason: 'entrada: "${c['entrada']}"',
      );
    }
  });

  test('seParecen da lo mismo que el TypeScript', () {
    for (final par in texto['pares'] as List) {
      final p = par as Map<String, dynamic>;
      expect(
        seParecen(p['a'] as String, p['b'] as String),
        equals(p['seParecen']),
        reason: '"${p['a']}" contra "${p['b']}"',
      );
    }
  });

  test('las fixtures traen los dos controles de seParecen', () {
    // Sin un par que NO se parece, una implementacion que devuelve `true`
    // siempre pasaria los tres tests de arriba.
    final resultados = (texto['pares'] as List)
        .map((p) => (p as Map<String, dynamic>)['seParecen'] as bool)
        .toList();
    expect(resultados, contains(true));
    expect(resultados, contains(false));
  });

  test('todo slug no vacio cumple esSlug de firestore.rules', () {
    // La misma expresion que `esSlug` en firestore.rules. Si el panel deriva
    // un slug que las reglas rechazan, el alta falla recien en produccion.
    final esSlug = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
    for (final caso in texto['casos'] as List) {
      final c = caso as Map<String, dynamic>;
      final slug = aSlug(c['entrada'] as String);
      if (slug.isEmpty) continue;
      expect(
        esSlug.hasMatch(slug),
        isTrue,
        reason: '"${c['entrada']}" dio "$slug"',
      );
    }
  });

  test('donde termina el acuerdo con TypeScript queda fijado', () {
    // `removeDiacritics` expande las ligaduras y el NFD de TypeScript no.
    // Ninguna fixture las usa, asi que esta diferencia es UNSPECIFIED en el
    // contrato. Se fija aca del lado de Dart para que un cambio de version de
    // `diacritic` no la mueva en silencio.
    expect(normalizar('Æ'), equals('ae'));
    expect(clave('Straße'), equals('strase'));
  });
}
