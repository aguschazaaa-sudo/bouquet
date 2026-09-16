import '../features/acceso/domain/sesion.dart';
import 'rutas.dart';

/// A donde tiene que ir quien pidio [uri], segun su [sesion]. `null` es
/// "quedate donde estas".
///
/// Es Dart puro: la llama el `redirect` de go_router y la prueba `dart test`.
///
/// - Sin sesion → `/entrar`, recordando a donde queria ir en `?desde=`.
/// - Resolviendo → `/espera`, recordandolo igual: recargar en `/pedidos` no
///   tiene que tirarte a Catalogo.
/// - Sin permiso o con el token ilegible → `/sin-acceso`, y nada mas.
/// - Operador → sale de las paginas de la sesion hacia `desde` o Catalogo.
///   Una ruta que no existe se deja pasar: la contesta la pagina no
///   encontrada.
String? destinoPara(Sesion sesion, Uri uri) {
  final ruta = uri.path;
  final desde = _rutaParaVolver(uri.queryParameters['desde']);

  switch (sesion) {
    case Resolviendo():
      if (ruta == Rutas.espera) return null;
      return _conDesde(Rutas.espera, _rutaParaVolver(ruta) ?? desde);
    case SinSesion():
      if (ruta == Rutas.entrar) return null;
      return _conDesde(Rutas.entrar, _rutaParaVolver(ruta) ?? desde);
    case SinPermiso() || Inaccesible():
      return ruta == Rutas.sinAcceso ? null : Rutas.sinAcceso;
    case Operador():
      if (ruta == '/') return Rutas.catalogo;
      if (Rutas.deLaSesion.contains(ruta)) return desde ?? Rutas.catalogo;
      return null;
  }
}

/// Una ruta interna a la que tiene sentido volver, o `null`. Nada con
/// esquema ni con host: `desde` viene de la URL y la escribe cualquiera.
String? _rutaParaVolver(String? ruta) {
  if (ruta == null || !ruta.startsWith('/') || ruta.startsWith('//')) {
    return null;
  }
  final uri = Uri.tryParse(ruta);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  if (uri.path == '/' || Rutas.deLaSesion.contains(uri.path)) return null;
  return uri.path;
}

String _conDesde(String ruta, String? desde) => desde == null
    ? ruta
    : Uri(path: ruta, queryParameters: {'desde': desde}).toString();
