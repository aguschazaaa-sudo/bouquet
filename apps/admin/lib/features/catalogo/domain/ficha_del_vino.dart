import '../../../core/contratos/producto.dart';

/// La ficha de un vino, como la lee el panel. El mapa `fichaVino` del
/// documento (ADR 008 §1), mas `graduacion` (ADR 013).
///
/// **Todo lo que puede faltar en un documento roto es opcional aca**, con el
/// mismo criterio que `campos.dart`: el Admin SDK no pasa por las reglas, y el
/// panel muestra el vino con lo que se pudo leer para que se pueda arreglar
/// (ADR 012 §7). Que falte un dato lo dice el formulario, no un crash.
class FichaDelVino {
  const FichaDelVino({
    required this.bodegaId,
    this.varietales = const [],
    this.color,
    this.organico = false,
    this.anada,
    this.region = '',
    this.volumenMl,
    this.graduacion,
    this.descripcion,
  });

  final String bodegaId;

  /// En el orden en que estan guardados.
  final List<String> varietales;

  /// `null` si el documento trae un color que no es de la lista.
  final ColorDelVino? color;

  final bool organico;

  /// `null` para los sin añada (un espumante NV).
  final int? anada;

  final String region;

  final int? volumenMl;

  /// Decimas de grado: 13,5 % es `135`. `null` si no se cargo.
  final int? graduacion;

  /// La prosa del dueño sobre el vino. `null` si no se cargo — y `null` es la
  /// UNICA forma de decir eso: una cadena en blanco la rechazan las reglas,
  /// porque dos maneras de decir nada son dos maneras de leerla.
  ///
  /// La lee el comprador en la ficha de la vidriera, no solo el panel. Tope
  /// en `descripcionMaxima`.
  final String? descripcion;
}
