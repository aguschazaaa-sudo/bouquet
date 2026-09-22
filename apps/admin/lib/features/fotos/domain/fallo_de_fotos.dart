/// Por que fallo subir o sacar una foto, en terminos de la pantalla y no de
/// los tres SDK que puede haber atravesado (Storage, la callable, Firestore).
enum ErrorDeFotos {
  /// Las reglas o el claim `rol: admin` rechazaron la operacion. Storage
  /// devuelve `unauthorized` para esto y tambien -por diseno de
  /// `storage.rules`- para un archivo que no es imagen o que pesa de mas;
  /// el panel intenta cubrir esos dos casos ANTES de llegar a Storage
  /// (`noEsImagen`, `pesaDeMas`), asi que si igual llega hasta aca lo mas
  /// probable es el claim.
  sinPermiso,

  /// No hay red, o la red no contesta a tiempo.
  sinConexion,

  /// Los bytes no son jpeg, png ni webp reconocibles
  /// (`domain/formato_de_foto.dart`). El panel lo detecta ANTES de subir,
  /// asi que este motivo se ve sin gastar la subida ni la callable (spec
  /// "Un PDF renombrado").
  noEsImagen,

  /// El archivo pesa `topeDeBytes` (5 MB) o mas. El panel lo mide ANTES de
  /// subir (spec "El panel mide el peso antes de subir"): sin este chequeo
  /// el rebote llegaria como `unauthorized` de `storage.rules`, que se lee
  /// como un problema de permisos y es un problema de tamano.
  pesaDeMas,

  /// La callable `procesarFoto` no pudo terminar: el crudo desaparecio de
  /// Storage entre que se subio y se la llamo, o `sharp` no pudo procesar el
  /// archivo real aunque sus bytes pasaron el chequeo de formato.
  fallaLaTransformacion,

  desconocido,
}

/// Lo que lanza [RepositorioDeFotos] cuando subir o sacar una foto falla.
///
/// Existe por HU-04.4: en PadelPunilla una subida fallaba y la excepcion se
/// perdia como error async no manejado -un `try/finally` sin `catch`-, el
/// spinner giraba y el boton volvia, **meses sin un solo reporte**. *Un
/// fallo invisible no genera reportes, genera la sensacion de que "no anda"*
/// (ARQUITECTURA §5.4 regla 4).
///
/// Por eso [nombreDeArchivo] no es opcional: con varias fotos a la vez, una
/// que falla no puede dejar a la pantalla sin poder decir CUAL
/// (spec "Tres fotos, una falla"). Al sacar una foto, lleva la URL en su
/// lugar -- es lo unico que identifica cual foto era.
final class FalloDeFotos implements Exception {
  const FalloDeFotos(this.error, this.nombreDeArchivo, [this.codigo]);

  final ErrorDeFotos error;

  /// El nombre que eligio el operador al subir, o la URL de la foto que se
  /// intento sacar. Nunca vacio: sin un nombre, el requisito "dice cual
  /// fallo" no se cumple.
  final String nombreDeArchivo;

  /// El codigo crudo del SDK, para el log. Nunca va a la pantalla.
  final String? codigo;

  @override
  String toString() => 'FalloDeFotos($error, $nombreDeArchivo, $codigo)';
}
