import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/contratos/estado_pago.dart';
import '../domain/lo_del_dia.dart';
import '../domain/lo_que_mas_se_vende.dart';
import '../domain/repositorio_del_resumen.dart';

/// El resumen contra Firestore (HU-11.2, HU-11.3, ADR 025): dos conteos sobre
/// `ordenes` y un documento, `metricas/popularidad`. **Tres lecturas** por
/// apertura.
class RepositorioDelResumenFirestore implements RepositorioDelResumen {
  RepositorioDelResumenFirestore(this._db);

  final FirebaseFirestore _db;

  /// Un `OR` de los tramos que salen de la proyeccion (`tramosPorPreparar`),
  /// cada uno `estadoEntrega ==` y `estadoPago in`. Hoy es un tramo solo, y
  /// `reduce` sobre uno devuelve ese mismo filtro.
  @override
  Future<Conteo> porPreparar() => _contar(
    tramosPorPreparar()
        .map(
          (t) => Filter.and(
            Filter('estadoEntrega', isEqualTo: t.entrega.name),
            Filter('estadoPago', whereIn: [for (final p in t.pagos) p.name]),
          ),
        )
        .reduce(Filter.or),
  );

  @override
  Future<Conteo> pagosEnProceso() =>
      _contar(Filter('estadoPago', isEqualTo: EstadoPago.en_proceso.name));

  /// `count()` con `limit`: sin el `limit` las reglas rechazan el conteo igual
  /// que una lista (`list` exige `limit <= 50`, ADR 018 §7). Solo igualdades,
  /// sin `orderBy`: no pide indice compuesto. **Se verifica corriendolo**
  /// contra produccion, no mirando indices (ADR 025).
  Future<Conteo> _contar(Filter filtro) async {
    final r = await _db
        .collection('ordenes')
        .where(filtro)
        .limit(topeDelConteo)
        .count()
        .get();
    return Conteo(r.count ?? 0);
  }

  @override
  Future<LoQueMasSeVende> loQueMasSeVende() async {
    final d = await _db.doc('metricas/popularidad').get();
    final datos = d.data();
    final hora = datos?['calculadaEn'];
    return LoQueMasSeVende.desde(
      datos,
      calculadaEn: hora is Timestamp ? hora.toDate() : null,
    );
  }
}
