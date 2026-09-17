/// Un producto, como lo ve el panel.
///
/// **No es `ProductoPublicado` de `contratos`.** Esa es la proyeccion que
/// llega al navegador de un comprador, y a proposito no lleva el stock ni
/// dice si el producto esta publicado — que son las dos cosas que el operador
/// necesita ver. Ver ADR 008 §2.
///
/// Tampoco es el documento crudo: el panel no pinta un mapa de Firestore.
/// Esto es lo que HU-03.1 muestra hoy. Los campos que faltan —`fichaVino`
/// entera, `imagenes`— entran con las historias que los usan (HU-03.2 en
/// adelante), no antes: un campo que nadie lee es peso en cada lectura.
class ProductoDelPanel {
  const ProductoDelPanel({
    required this.id,
    required this.slug,
    required this.nombre,
    required this.precio,
    required this.publicado,
    required this.bodegaId,
    required this.botellas,
    required this.stock,
  });

  final String id;
  final String slug;
  final String nombre;

  /// Centavos de la unidad de venta. Entero, nunca float: ADR 008 §1.
  final int precio;

  /// Si la vidriera lo muestra. `armarCatalogo` deja afuera los que no.
  final bool publicado;

  /// A que bodega apunta. Puede no existir en `bodegas`: ese es justamente
  /// el caso que la pantalla tiene que decir, porque `armarCatalogo` lo
  /// descarta **sin avisar** (ADR 008 §2).
  final String bodegaId;

  /// Botellas por unidad de venta. Mas de una significa que trae su propia
  /// caja y viaja solo (ADR 009 §10).
  final int botellas;

  /// Unidades de venta, no botellas. `null` en un compuesto, que no tiene
  /// stock propio: lo deriva de sus componentes.
  final int? stock;
}
