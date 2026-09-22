import 'ficha_del_vino.dart';

/// Un producto, como lo ve el panel.
///
/// **No es `ProductoPublicado` de `contratos`.** Esa es la proyeccion que
/// llega al navegador de un comprador, y a proposito no lleva el stock ni
/// dice si el producto esta publicado — que son las dos cosas que el operador
/// necesita ver. Ver ADR 008 §2.
///
/// Tampoco es el documento crudo: el panel no pinta un mapa de Firestore.
/// La ficha entera entro con HU-03.4, que la corrige.
class ProductoDelPanel {
  const ProductoDelPanel({
    required this.id,
    required this.slug,
    required this.nombre,
    required this.precio,
    required this.publicado,
    required this.ficha,
    required this.botellas,
    required this.stock,
    this.muestra = false,
    this.imagenes = const [],
  });

  final String id;
  final String slug;
  final String nombre;

  /// Centavos de la unidad de venta. Entero, nunca float: ADR 008 §1.
  final int precio;

  /// Si la vidriera lo muestra. `armarCatalogo` deja afuera los que no.
  final bool publicado;

  final FichaDelVino ficha;

  /// A que bodega apunta. Puede no existir en `bodegas`: ese es justamente
  /// el caso que la pantalla tiene que decir, porque `armarCatalogo` lo
  /// descarta **sin avisar** (ADR 008 §2).
  String get bodegaId => ficha.bodegaId;

  /// Los datos de prueba del seed. Un vino real con el mismo slug que uno de
  /// muestra no choca en la base —el de muestra tiene id `muestra-<slug>`—,
  /// y el formulario avisa en vez de frenar (ADR 013 §1).
  final bool muestra;

  /// Botellas por unidad de venta. Mas de una significa que trae su propia
  /// caja y viaja solo (ADR 009 §10).
  final int botellas;

  /// Unidades de venta, no botellas. `null` en un compuesto, que no tiene
  /// stock propio: lo deriva de sus componentes.
  final int? stock;

  /// Las fotos, en el orden guardado. Vacia si no se cargo ninguna todavia
  /// -- la vidriera muestra una silueta y el texto "sin foto" en ese caso
  /// (`panel-publicar-un-vino`, design.md Decision #1): no bloquea publicar.
  /// Mapeo seguro: lista vacia si el documento no trae el campo o trae otra
  /// cosa (`textosDe` en `data/campos.dart`).
  final List<String> imagenes;
}
