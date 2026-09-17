/// Las URLs del panel. Toda ruta que existe esta aca, y toda seccion esta en
/// la navegacion (`features/estructura/presentation/secciones.dart`): una
/// seccion con ruta y sin entrada en la navegacion es la pagina huerfana de
/// PadelPunilla.
abstract final class Rutas {
  static const entrar = '/entrar';
  static const sinAcceso = '/sin-acceso';
  static const espera = '/espera';

  static const catalogo = '/catalogo';
  static const pedidos = '/pedidos';

  /// Hija de Catalogo, y NO una seccion: no va en `secciones.dart`. Se llega
  /// desde Catalogo, y `Seccion.estaActiva` sigue marcando Catalogo mientras
  /// se esta aca, que es lo correcto — no se salio de ahi.
  static const bodegas = '$catalogo/bodegas';

  /// Las paginas que no son una seccion: a ninguna de estas se vuelve
  /// despues de entrar.
  static const deLaSesion = [entrar, sinAcceso, espera];
}
