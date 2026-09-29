import 'cajas_sugeridas.dart';
import 'envio_sin_cargo.dart';
import 'seleccion_de_la_portada.dart';

/// Lo que el panel sabe hacer con lo que la tienda elige mostrar (EP-09). La
/// implementacion vive en `data/`; las pantallas la piden por
/// `vidriera_providers.dart`.
abstract interface class RepositorioDeLaVidriera {
  /// La seleccion de la portada, cada vez que cambia. Un documento: una
  /// lectura al abrir y una por cambio.
  Stream<SeleccionDeLaPortada> seleccion();

  /// Reescribe la seleccion entera. Guardar dos veces da lo mismo.
  ///
  /// Lanza `FalloDeCatalogo`: es el mismo tipo de escritura que el catalogo,
  /// con los mismos tres desenlaces (sin permiso, sin conexion, desconocido).
  Future<void> guardarSeleccion(SeleccionDeLaPortada seleccion);

  /// Las cajas sugeridas, cada vez que cambian. Un documento, que las reglas
  /// dejan LEER al admin.
  Stream<CajasSugeridas> cajas();

  /// Reescribe TODAS las cajas por la callable `guardarCajasSugeridas`, que
  /// verifica que cada una cierre (ADR 024). Lanza `FalloDeLasCajas`.
  Future<void> guardarCajas(CajasSugeridas cajas);

  /// El umbral de la entrega sin cargo, cada vez que cambia (HU-11.1). Un
  /// documento, `config/envios`, que las reglas dejan LEER al admin.
  Stream<EnvioSinCargo> envioSinCargo();

  /// Fija el umbral —en centavos, o `null` para apagarlo— por la callable
  /// `fijarEnvioSinCargo`, la unica puerta de `config` (ADR 026). Si la
  /// baranda pregunta, devuelve [PideConfirmar] y NO guarda: se vuelve a
  /// llamar con [confirmado]. Lanza [FalloDelEnvio].
  Future<ResultadoDeFijar> fijarEnvioSinCargo(
    int? desde, {
    bool confirmado = false,
  });
}
