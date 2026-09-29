import 'lo_del_dia.dart';
import 'lo_que_mas_se_vende.dart';

/// Lo que el resumen le pregunta a la base (EP-11, ADR 025). La
/// implementacion vive en `data/`; las pantallas la piden por
/// `resumen_providers.dart`.
///
/// **Ninguno atrapa los errores**: los deja subir, para que la pantalla los
/// dibuje como un fallo y no como un cero. *"No hay pedidos por preparar"* y
/// *"no pude contarlos"* son opuestos.
abstract interface class RepositorioDelResumen {
  /// Los pedidos que falta preparar (HU-11.2): un `count()`, una lectura.
  Future<Conteo> porPreparar();

  /// Los pagos que Mercado Pago todavia no confirmo (HU-11.2): un `count()`,
  /// una lectura.
  Future<Conteo> pagosEnProceso();

  /// `metricas/popularidad` (HU-11.3): un documento, una lectura.
  Future<LoQueMasSeVende> loQueMasSeVende();
}
