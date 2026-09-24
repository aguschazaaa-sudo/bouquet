import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/contratos/estado_entrega.dart';
import '../domain/ventas_sin_despachar.dart';
import 'documento_de_ventas.dart';

/// Las unidades vendidas y sin despachar de un vino (ADR 018 §9), leidas de los
/// pedidos abiertos de `ordenes`.
///
/// **Sin campo nuevo en la Orden ni indice compuesto.** `whereIn` sobre un solo
/// campo lo resuelve el indice que Firestore arma solo, y no hay `orderBy`: el
/// orden no importa para sumar. Un `productoIds[]` con `array-contains` lo haria
/// exacto, pero es un esquema y un indice que hoy no se justifican (ADR 018 §9).
///
/// **Cuesta hasta [topeDePedidosAbiertos] lecturas por apertura de la hoja**, que
/// es una operacion rara (contar el deposito). No suma al catalogo ni a la
/// bandeja.
///
/// **No atrapa los errores**: los deja subir, para que la hoja diga "no pudimos
/// ver" en vez de "no hay".
class RepositorioDeVentasSinDespacharFirestore
    implements RepositorioDeVentasSinDespachar {
  RepositorioDeVentasSinDespacharFirestore(this._db);

  final FirebaseFirestore _db;

  /// Los dos estados de entrega en los que la botella **sigue en la estanteria**:
  /// todavia no salio. `despachada` y siguientes ya no cuentan.
  static final _abiertos = [
    EstadoEntrega.sin_preparar.name,
    EstadoEntrega.preparando.name,
  ];

  @override
  Future<VentasSinDespachar> de(String productoId) async {
    final instantanea = await _db
        .collection('ordenes')
        .where('estadoEntrega', whereIn: _abiertos)
        .limit(topeDePedidosAbiertos)
        .get();
    return ventasSinDespacharDe(productoId, [
      for (final d in instantanea.docs) d.data(),
    ]);
  }
}
