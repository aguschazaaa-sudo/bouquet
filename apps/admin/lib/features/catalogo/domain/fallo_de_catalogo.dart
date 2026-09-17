/// Por que fallo una escritura del catalogo, en terminos de la pantalla y no
/// de Firestore.
enum ErrorDeCatalogo {
  /// Las reglas rechazaron la escritura. En el panel esto casi siempre
  /// significa que el token todavia no trae el claim `rol: admin`, o que el
  /// documento no cumple `productoValido` / la forma de `bodegas`.
  sinPermiso,

  /// No hay red y la escritura no llego. ⚠️ El SDK de Firestore **confirma
  /// una escritura offline contra su cache**, asi que este caso llega menos
  /// de lo que uno espera: lo que se ve sin red es un exito optimista.
  sinConexion,

  /// Ya hay una bodega con ese slug. No es un error de red ni de permiso:
  /// es el caso que HU-02.2 quiere evitar, ganado por la otra persona.
  yaExiste,

  desconocido,
}

/// Lo que lanza un repositorio del catalogo cuando una operacion falla.
///
/// Existe por HU-04.4, que nacio de un bug real: en PadelPunilla una subida
/// fallaba y la excepcion se perdia como error async —un `try/finally` sin
/// `catch`—, el spinner giraba y el boton volvia. Meses sin un solo reporte.
/// *Un fallo invisible no genera reportes, genera la sensacion de que "no
/// anda".* La regla se aplica a toda escritura, no solo a las fotos.
final class FalloDeCatalogo implements Exception {
  const FalloDeCatalogo(this.error, [this.codigo]);

  final ErrorDeCatalogo error;

  /// El codigo crudo de Firebase, para el log. Nunca va a la pantalla.
  final String? codigo;

  @override
  String toString() => 'FalloDeCatalogo($error, $codigo)';
}
