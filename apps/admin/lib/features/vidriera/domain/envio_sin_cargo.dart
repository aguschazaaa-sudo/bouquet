import '../../catalogo/domain/numeros_escritos.dart';

/// Desde que monto la entrega sale sin cargo (HU-11.1, ADR 026).
///
/// `config/envios` lo escribe **solo** la callable `fijarEnvioSinCargo`
/// —`config` esta cerrado incluso para el admin, y la baranda contra el dedo
/// gordo corre en el servidor—; el panel lo lee directo para mostrarlo.
class EnvioSinCargo {
  const EnvioSinCargo({required this.desde, this.roto = false});

  /// Centavos. `null`: apagado, la entrega se cobra siempre.
  final int? desde;

  /// El documento existe y no se pudo leer. La tienda lo trata como apagado
  /// —cobrar la entrega es lo seguro—, y el panel lo dice.
  final bool roto;

  static const apagado = EnvioSinCargo(desde: null);

  /// Espejo de `leerConfigDeEnvios` de contratos: sin documento es apagado, y
  /// **roto es apagado**, nunca "sin cargo desde 0". Un umbral valido son
  /// pesos enteros entre [umbralMinimo] y [umbralMaximo].
  factory EnvioSinCargo.desdeDocumento(Map<String, Object?>? datos) {
    if (datos == null) return apagado;
    final desde = datos['sinCargoDesde'];
    if (desde == null && datos.containsKey('sinCargoDesde')) return apagado;
    if (desde is int && esUmbralValido(desde)) {
      return EnvioSinCargo(desde: desde);
    }
    return const EnvioSinCargo(desde: null, roto: true);
  }
}

/// Espejo de `SIN_CARGO_MINIMO`: un peso, en centavos.
const umbralMinimo = 100;

/// Espejo de `SIN_CARGO_MAXIMO`: cien millones de pesos, en centavos.
const umbralMaximo = 100000000 * 100;

bool esUmbralValido(int centavos) =>
    centavos % 100 == 0 && centavos >= umbralMinimo && centavos <= umbralMaximo;

/// Lee el monto que escribe el dueño. Reusa `leerPesos` —el mismo formato que
/// el precio de un vino: `150.000`, `$ 150.000`— y le suma lo que el umbral
/// exige: **pesos enteros** y mayor que cero. El techo lo dice el servidor.
Lectura leerUmbral(String escrito) {
  final lectura = leerPesos(escrito);
  final valor = lectura.valor;
  if (valor == null) return lectura;
  if (valor <= 0) {
    return const Lectura.problema('Tiene que ser mayor que cero.');
  }
  if (valor % 100 != 0) {
    return const Lectura.problema('Va en pesos enteros, sin centavos.');
  }
  return lectura;
}

/// Por que la callable pregunta antes de guardar. Espejo de
/// `MotivoParaConfirmar` de contratos.
enum MotivoParaConfirmar {
  /// Queda por debajo de una caja a precio tipico: casi todo sale sin cargo.
  debajoDeUnaCaja,

  /// Baja a menos de la mitad del que habia.
  menosDeLaMitad,
}

/// Lo que devuelve `fijarEnvioSinCargo`.
sealed class ResultadoDeFijar {
  const ResultadoDeFijar();

  /// Lee la respuesta cruda de la callable. `null` si no tiene ninguna forma
  /// conocida: el repositorio lo convierte en un fallo `desconocido`, porque
  /// el umbral PUDO haberse guardado y la pantalla no lo puede afirmar.
  static ResultadoDeFijar? desde(Object? datos) {
    if (datos is! Map) return null;
    final guardado = datos['guardado'];
    if (guardado == true) {
      final desde = datos['sinCargoDesde'];
      if (desde == null) return const Fijado(null);
      return desde is num ? Fijado(desde.toInt()) : null;
    }
    if (guardado != false) return null;
    return switch (datos['motivo']) {
      'debajo-de-una-caja' => _pide(
        MotivoParaConfirmar.debajoDeUnaCaja,
        datos['cajaTipica'],
      ),
      'menos-de-la-mitad' => _pide(
        MotivoParaConfirmar.menosDeLaMitad,
        datos['anterior'],
      ),
      _ => null,
    };
  }

  static ResultadoDeFijar? _pide(MotivoParaConfirmar motivo, Object? monto) =>
      monto is num ? PideConfirmar(motivo, referencia: monto.toInt()) : null;
}

/// Quedo guardado. [desde] es el umbral nuevo, en centavos, o `null` si se
/// apago.
final class Fijado extends ResultadoDeFijar {
  const Fijado(this.desde);

  final int? desde;
}

/// No se guardo: hay que confirmar. [referencia] es el monto que lo explica
/// —la caja tipica, o el umbral anterior—, en centavos.
final class PideConfirmar extends ResultadoDeFijar {
  const PideConfirmar(this.motivo, {required this.referencia});

  final MotivoParaConfirmar motivo;
  final int referencia;
}

/// Por que no se pudo fijar, en terminos de la pantalla.
enum ErrorDelEnvio { sinPermiso, sinConexion, noValido, desconocido }

/// Lo que lanza el repositorio cuando la callable falla. HU-04.4: un fallo
/// que no se ve genera la sensacion de que "no anda".
final class FalloDelEnvio implements Exception {
  const FalloDelEnvio(this.error, {this.codigo});

  final ErrorDelEnvio error;

  /// El codigo crudo, para el log. Nunca va a la pantalla.
  final String? codigo;

  @override
  String toString() => 'FalloDelEnvio($error, $codigo)';
}
