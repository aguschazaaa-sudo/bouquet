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

  /// Cargar un vino (HU-03.2, HU-03.3). Hija de Catalogo, como Bodegas.
  ///
  /// ⚠️ **No es `/catalogo/vinos/nuevo`**: un vino llamado "Nuevo" tendria el
  /// slug `nuevo` —y desde ADR 013 el slug es el id— y su correccion quedaria
  /// tapada por esta pagina.
  static const nuevoVino = '$catalogo/nuevo';

  /// Corregir un vino (HU-03.4). El id es el del documento, que en un vino
  /// cargado desde el panel es su slug y en uno de muestra, `muestra-<slug>`.
  static String vino(String id) => '$catalogo/vinos/${Uri.encodeComponent(id)}';

  /// Cargar un pedido de WhatsApp (HU-10.1). Hija de Pedidos, como Bodegas lo es
  /// de Catalogo: la navegacion sigue marcando Pedidos.
  ///
  /// No choca con `pedido(id)`: el id de un pedido son 32 hexadecimales, nunca la
  /// palabra `nuevo` (el orden de las rutas en el enrutador igual la pone
  /// primero).
  static const nuevoPedido = '$pedidos/nuevo';

  /// Un pedido (HU-06.2). El id es el del documento, que es el `idPedido`; **no
  /// se le muestra a nadie**: lo que se dice es el numero.
  static String pedido(String id) => '$pedidos/${Uri.encodeComponent(id)}';

  /// Las paginas que no son una seccion: a ninguna de estas se vuelve
  /// despues de entrar.
  static const deLaSesion = [entrar, sinAcceso, espera];
}
