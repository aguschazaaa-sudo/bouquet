import 'dart:typed_data';

import 'foto_del_vino.dart';

/// Lo que el panel sabe hacer con las fotos de un vino: subirlas y sacarlas
/// (HU-04.1, HU-04.3). **No reordena** -HU-04.2 queda afuera de este change,
/// con disparador: el primer vino con dos fotos (proposal.md)- y **no borra
/// el archivo de Storage** al sacar una foto: la URL sale de `imagenes[]`
/// nada mas (proposal.md, "Lo que este cambio NO hace").
abstract interface class RepositorioDeFotos {
  /// Sube el crudo [bytes] a Storage, llama a la callable `procesarFoto` y
  /// agrega la URL que devuelve a `imagenes` de `productos/{productoId}` con
  /// `arrayUnion` -- **nunca** reescribiendo el array
  /// (ARQUITECTURA §5.3, design.md decision 5).
  ///
  /// [nombreOriginal] es solo el nombre que eligio el operador: sirve para
  /// que un fallo diga QUE foto fallo (`FalloDeFotos`, spec "Una subida que
  /// falla se ve, y dice cual fallo"). **Nunca** se usa para derivar la
  /// extension ni la ruta -- eso sale siempre de los bytes
  /// (`domain/formato_de_foto.dart`), porque en web `XFile.path` es un blob
  /// URL (design.md decision 3, ARQUITECTURA §5.4).
  Future<FotoDelVino> subir({
    required String productoId,
    required Uint8List bytes,
    required String nombreOriginal,
  });

  /// Saca [url] de `imagenes` de `productos/{productoId}` con
  /// `arrayRemove`. El archivo sigue existiendo en Storage: borrarlo daria
  /// 404 en las paginas ya cacheadas en el borde hasta la proxima purga, y
  /// el tramo 4 de Cloudflare no esta construido (proposal.md).
  Future<void> quitar({required String productoId, required String url});
}
