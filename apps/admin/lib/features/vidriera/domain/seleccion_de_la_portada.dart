/// La seleccion de la portada, en Dart puro (HU-09.1, ADR 023).
///
/// Es el espejo del lado del panel de `packages/contratos/src/seleccion.ts`:
/// una lista ORDENADA de ids que el panel reescribe entera en
/// `seleccion/publica`. La portada de la tienda la lee al publicarse y dibuja
/// los vinos elegidos que puede dibujar; este archivo le dice al dueño cuales
/// son **antes** de que la portada los saltee en silencio.
library;

import '../../../core/contratos/catalogo_publico.dart';
import '../../catalogo/domain/catalogo.dart';
import '../../catalogo/domain/en_la_tienda.dart';
import '../../catalogo/domain/producto_del_panel.dart';

/// Cuantos vinos entran en la portada. Espejo de `LUGARES_DE_LA_SELECCION`:
/// `test/features/vidriera/seleccion_de_la_portada_test.dart` lo compara
/// contra `generated/contratos.json`, y las reglas lo exigen como tope.
const lugaresDeLaSeleccion = 6;

/// Por que la portada saltea un vino elegido. `null` en [fueraDeLaPortada]
/// es que se ve.
enum FueraDeLaPortada {
  /// El id ya no esta en el catalogo. El panel no borra vinos (HU-03.6), asi
  /// que esto lo deja un script con el Admin SDK.
  noExiste,

  /// La tienda no lo muestra: no esta publicado, o algo de la ficha la hace
  /// descartarlo. El motivo fino lo dice la pagina del vino (HU-03.7).
  noEstaEnLaTienda,

  /// Viene en su propia caja, y la tarjeta de la portada dibuja UNA botella.
  enCaja,

  /// Sin stock: la tienda no ofrece un vino que no puede vender.
  agotado,
}

/// Si la portada dibuja [producto] hoy, y si no, por que.
///
/// **La misma condicion que la tienda**, en el mismo orden: primero que
/// aparezca en el catalogo publico (`resolverSeleccion` cruza contra la
/// proyeccion, y aca lo decide `revisarParaLaTienda`, la unica funcion del
/// panel que lo sabe), despues `puedeIrEnLaSeleccion` —una botella suelta,
/// no agotada—. Un vino que el panel diera por visible y la portada salteara
/// seria un lugar vacio que nadie entiende.
FueraDeLaPortada? fueraDeLaPortada(
  ProductoDelPanel? producto,
  Catalogo catalogo,
) {
  if (producto == null) return FueraDeLaPortada.noExiste;
  if (!revisarParaLaTienda(producto, catalogo).aparece) {
    return FueraDeLaPortada.noEstaEnLaTienda;
  }
  if (producto.botellas != 1) return FueraDeLaPortada.enCaja;
  final b = balde(stock: producto.stock ?? 0, botellas: producto.botellas);
  if (b == Balde.agotado) return FueraDeLaPortada.agotado;
  return null;
}

/// Un lugar de la seleccion, cruzado con el catalogo que ya esta en memoria.
class LugarDeLaPortada {
  const LugarDeLaPortada({
    required this.productoId,
    required this.producto,
    required this.fuera,
  });

  final String productoId;

  /// `null` si el id no esta en el catalogo ([FueraDeLaPortada.noExiste]).
  final ProductoDelPanel? producto;

  final FueraDeLaPortada? fuera;

  bool get seVe => fuera == null;
}

/// Los vinos que el dueño eligio para la portada.
///
/// Inmutable: cada cambio devuelve una seleccion nueva, que es la que se
/// guarda entera. Asi guardar dos veces da lo mismo.
class SeleccionDeLaPortada {
  const SeleccionDeLaPortada(this.productoIds) : elegida = true;

  /// Nunca se eligio: no hay documento. La portada usa la regla provisoria
  /// (seis por ventas y color, ADR 008 §7), y la pantalla lo tiene que decir.
  const SeleccionDeLaPortada.sinElegir() : productoIds = const [], elegida = false;

  /// El documento crudo de `seleccion/publica`, como lo lee la tienda
  /// (`validarSeleccion`): lo que no es un texto se descarta, un repetido
  /// entra una vez, y lo que pasa del tope queda afuera. `null` es que no
  /// existe.
  ///
  /// Vive en `domain/` y no en `data/` para que la prueben los tests de Dart
  /// puro: recibe un mapa, no un documento de Firestore.
  factory SeleccionDeLaPortada.desdeDocumento(Map<String, Object?>? datos) {
    final crudos = datos?['productoIds'];
    if (crudos is! List) return const SeleccionDeLaPortada.sinElegir();
    final ids = <String>[];
    for (final id in crudos) {
      if (id is! String || id.isEmpty || ids.contains(id)) continue;
      if (ids.length >= lugaresDeLaSeleccion) break;
      ids.add(id);
    }
    return SeleccionDeLaPortada(List.unmodifiable(ids));
  }

  final List<String> productoIds;

  /// `false` solo en [SeleccionDeLaPortada.sinElegir]. Una lista vacia
  /// guardada es una eleccion: el dueño saco todo.
  final bool elegida;

  bool get llena => productoIds.length >= lugaresDeLaSeleccion;

  int get lugaresLibres => lugaresDeLaSeleccion - productoIds.length;

  bool contiene(String productoId) => productoIds.contains(productoId);

  /// Al final. Si ya esta, o no hay lugar, queda igual: la pantalla no lo
  /// ofrece, y esto evita que un doble toque lo agregue dos veces.
  SeleccionDeLaPortada agregar(String productoId) {
    if (contiene(productoId) || llena) return this;
    return SeleccionDeLaPortada(List.unmodifiable([...productoIds, productoId]));
  }

  SeleccionDeLaPortada quitar(String productoId) => SeleccionDeLaPortada(
    List.unmodifiable([
      for (final id in productoIds)
        if (id != productoId) id,
    ]),
  );

  /// Lo corre [lugares] posiciones: negativo hacia arriba. Fuera de rango,
  /// queda en la punta.
  SeleccionDeLaPortada mover(String productoId, int lugares) {
    final desde = productoIds.indexOf(productoId);
    if (desde < 0) return this;
    final hasta = (desde + lugares).clamp(0, productoIds.length - 1);
    if (hasta == desde) return this;
    final ids = [...productoIds]..removeAt(desde);
    ids.insert(hasta, productoId);
    return SeleccionDeLaPortada(List.unmodifiable(ids));
  }

  /// Cada lugar con su vino y si se ve. Cero lecturas: el catalogo ya esta
  /// en memoria.
  List<LugarDeLaPortada> lugaresEn(Catalogo catalogo) => [
    for (final id in productoIds)
      LugarDeLaPortada(
        productoId: id,
        producto: catalogo.vino(id),
        fuera: fueraDeLaPortada(catalogo.vino(id), catalogo),
      ),
  ];

  /// Si la portada, hoy, muestra la regla provisoria en vez de esta
  /// seleccion: porque nunca se eligio, o porque de lo elegido no queda
  /// ninguno que se pueda dibujar. Es lo que hace `elegirSeleccion` en la
  /// tienda.
  bool usaLaReglaEn(Catalogo catalogo) =>
      !elegida || lugaresEn(catalogo).every((l) => !l.seVe);
}
