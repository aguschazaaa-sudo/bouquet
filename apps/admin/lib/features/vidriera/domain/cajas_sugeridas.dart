/// Las cajas sugeridas, en Dart puro (HU-09.2, HU-09.3, ADR 024).
///
/// Una caja sugerida **no es un producto**: es un nombre y seis ids que
/// llenan el carrito (ADR 009). Viven todas en `cajasSugeridas/publicas`, que
/// el panel lee directo y guarda **por la callable** `guardarCajasSugeridas`:
/// las reglas cierran la escritura incluso al admin, porque que una caja cierre
/// pide mirar cada vino (ADR 009 §8).
library;

import '../../../core/contratos/catalogo_publico.dart';
import '../../catalogo/domain/catalogo.dart';
import '../../catalogo/domain/en_la_tienda.dart';
import '../../catalogo/domain/producto_del_panel.dart';

/// Espejos de `packages/contratos`: `BOTELLAS_POR_CAJA`,
/// `TOPE_DE_CAJAS_SUGERIDAS` y `LARGO_DEL_NOMBRE_DE_CAJA`.
/// `test/features/vidriera/cajas_sugeridas_test.dart` los compara contra
/// `generated/contratos.json`.
const botellasPorCaja = 6;
const topeDeCajas = 6;
const largoDelNombreDeCaja = 40;

class CajaSugerida {
  const CajaSugerida({
    required this.slug,
    required this.nombre,
    required this.productoIds,
  });

  /// Lo deriva el servidor del nombre. El panel lo usa solo para saber si
  /// dos cajas se llaman igual para la tienda.
  final String slug;
  final String nombre;

  /// Un id por BOTELLA: repetido son dos botellas de ese vino.
  final List<String> productoIds;
}

/// Todas las cajas, en el orden en que se ofrecen.
class CajasSugeridas {
  const CajasSugeridas(this.cajas);

  /// El documento crudo. Una caja que no tiene la forma —sin nombre, sin
  /// seis ids— queda afuera, como en la tienda (`validarCajasSugeridas`): el
  /// panel muestra lo que la tienda ofrece, y el proximo guardado la limpia.
  factory CajasSugeridas.desdeDocumento(Map<String, Object?>? datos) {
    final crudas = datos?['cajas'];
    if (crudas is! List) return const CajasSugeridas([]);
    return CajasSugeridas(
      List.unmodifiable([
        for (final c in crudas)
          if (c is Map &&
              c['nombre'] is String &&
              (c['nombre'] as String).trim().isNotEmpty &&
              c['productoIds'] is List &&
              (c['productoIds'] as List).length == botellasPorCaja &&
              (c['productoIds'] as List).every((id) => id is String))
            CajaSugerida(
              slug: c['slug'] is String ? c['slug'] as String : '',
              nombre: c['nombre'] as String,
              productoIds: List.unmodifiable(
                (c['productoIds'] as List).cast<String>(),
              ),
            ),
      ]),
    );
  }

  final List<CajaSugerida> cajas;

  bool get llena => cajas.length >= topeDeCajas;

  /// Reemplaza la caja [indice], o la suma al final si es `null`.
  CajasSugeridas con(CajaSugerida caja, {int? indice}) {
    final lista = [...cajas];
    if (indice == null) {
      lista.add(caja);
    } else {
      lista[indice] = caja;
    }
    return CajasSugeridas(List.unmodifiable(lista));
  }

  CajasSugeridas sin(int indice) =>
      CajasSugeridas(List.unmodifiable([...cajas]..removeAt(indice)));

  /// La corre [lugares] posiciones: negativo hacia arriba. Fuera de rango,
  /// queda en la punta.
  CajasSugeridas mover(int indice, int lugares) {
    final hasta = (indice + lugares).clamp(0, cajas.length - 1);
    if (hasta == indice) return this;
    final lista = [...cajas];
    final caja = lista.removeAt(indice);
    lista.insert(hasta, caja);
    return CajasSugeridas(List.unmodifiable(lista));
  }

  /// Lo que recibe `guardarCajasSugeridas`: la lista ENTERA, sin slugs —los
  /// deriva el servidor—.
  Map<String, Object> get pedido => {
    'cajas': [
      for (final c in cajas) {'nombre': c.nombre, 'productoIds': c.productoIds},
    ],
  };
}

/// Por que un lugar de una caja no se llena en la tienda. Espejo de los
/// estados de `resolverCajasSugeridas`, mas [enCaja], que en la tienda
/// descarta la caja entera.
enum FueraDeLaCaja {
  /// El id no esta en el catalogo.
  noExiste,

  /// La tienda no lo muestra (no publicado, o la ficha la hace descartarlo).
  /// En la tienda es `no-disponible`: el lugar se ve marcado.
  noEstaEnLaTienda,

  /// Viene en su propia caja: no arma caja con nadie, y la tienda **no
  /// muestra la caja** (ADR 009 §10). La callable tampoco la guarda.
  enCaja,

  /// Sin stock.
  agotado,

  /// Hay, pero no para otra copia de este mismo vino en esta caja: el tope
  /// por pedido o el stock no alcanzan. No es `agotado` —el vino se vende—.
  sinSuficiente,
}

class LugarDeLaCaja {
  const LugarDeLaCaja({
    required this.productoId,
    required this.producto,
    required this.fuera,
  });

  final String productoId;
  final ProductoDelPanel? producto;
  final FueraDeLaCaja? fuera;

  bool get seLlena => fuera == null;
}

/// Cada lugar de [caja] y si la tienda lo llena, en el orden de
/// `resolverCajasSugeridas`: que aparezca, que sea una botella suelta, que
/// tenga stock, y que alcance para OTRA copia del mismo vino.
List<LugarDeLaCaja> lugaresDeLaCaja(CajaSugerida caja, Catalogo catalogo) {
  final comprometidas = <String, int>{};
  return [
    for (final id in caja.productoIds)
      LugarDeLaCaja(
        productoId: id,
        producto: catalogo.vino(id),
        fuera: _fuera(catalogo.vino(id), catalogo, comprometidas),
      ),
  ];
}

FueraDeLaCaja? _fuera(
  ProductoDelPanel? p,
  Catalogo catalogo,
  Map<String, int> comprometidas,
) {
  if (p == null) return FueraDeLaCaja.noExiste;
  if (!revisarParaLaTienda(p, catalogo).aparece) {
    return FueraDeLaCaja.noEstaEnLaTienda;
  }
  if (p.botellas != 1) return FueraDeLaCaja.enCaja;
  final stock = p.stock ?? 0;
  final elTope = tope(stock: stock);
  if (balde(stock: stock, botellas: p.botellas) == Balde.agotado ||
      elTope <= 0) {
    return FueraDeLaCaja.agotado;
  }
  final yaPedidas = comprometidas[p.id] ?? 0;
  if (yaPedidas >= elTope) return FueraDeLaCaja.sinSuficiente;
  comprometidas[p.id] = yaPedidas + 1;
  return null;
}

/// Si [p] se puede elegir para un lugar NUEVO. Mas estricto que lo que se
/// muestra: un vino despublicado o agotado que ya estaba en una caja se sigue
/// mostrando marcado (HU-09.3), pero no se ofrece para armar una.
FueraDeLaCaja? fueraAlElegir(ProductoDelPanel p, Catalogo catalogo) =>
    _fuera(p, catalogo, {});
