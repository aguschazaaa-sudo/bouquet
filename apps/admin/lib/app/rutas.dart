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

  /// Las paginas que no son una seccion: a ninguna de estas se vuelve
  /// despues de entrar.
  static const deLaSesion = [entrar, sinAcceso, espera];
}
