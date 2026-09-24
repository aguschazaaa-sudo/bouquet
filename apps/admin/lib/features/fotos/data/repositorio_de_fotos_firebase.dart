import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../domain/fallo_de_fotos.dart';
import '../domain/foto_del_vino.dart';
import '../domain/formato_de_foto.dart';
import '../domain/foto_principal.dart';
import '../domain/repositorio_de_fotos.dart';
import 'fallos_de_fotos.dart';

/// Lo que decidió la transacción de [RepositorioDeFotosFirebase.hacerPrincipal].
enum _CambioDePrincipal { cambiada, yaEra, yaNoEsta }

/// Las fotos de un vino, contra Storage, la callable `procesarFoto` y
/// Firestore.
///
/// **Cada paso que toca un SDK va en su propio `try`/`catch`** -- nunca un
/// `try`/`finally` sin `catch` (ARQUITECTURA §5.4 regla 4, HU-04.4): el bug
/// de PadelPunilla vivio meses sin un solo reporte porque la excepcion se
/// perdia como error async no manejado.
class RepositorioDeFotosFirebase implements RepositorioDeFotos {
  RepositorioDeFotosFirebase(this._storage, this._functions, this._db);

  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;

  static const _coleccion = 'productos';
  static const _campoDeImagenes = 'imagenes';

  @override
  Future<FotoDelVino> subir({
    required String productoId,
    required Uint8List bytes,
    required String nombreOriginal,
    bool agregarAlDocumento = true,
  }) async {
    // Los bytes deciden el formato -- NUNCA el nombre ni el path (design.md
    // decision 3, ARQUITECTURA §5.4). Rechazar aca, antes de tocar la red,
    // es lo que hace que un PDF renombrado no gaste la subida ni la callable
    // (spec "Un PDF renombrado").
    final formato = detectarFormato(bytes);
    if (formato == null) {
      throw FalloDeFotos(ErrorDeFotos.noEsImagen, nombreOriginal);
    }

    // El mismo tope que `pesaMenosDe5MB()` de `storage.rules`, medido ANTES
    // de subir: sin esto el rebote llega como `unauthorized`, que se lee
    // como un problema de permisos y es un problema de tamano (spec "El
    // panel mide el peso antes de subir").
    if (bytes.length >= topeDeBytes) {
      throw FalloDeFotos(ErrorDeFotos.pesaDeMas, nombreOriginal);
    }

    // Un solo segmento de nombre de archivo (ARQUITECTURA §5.4 regla 2): el
    // hash que va a llevar el WebP final lo decide la callable, del lado
    // del servidor (design.md decision 6). Este nombre es solo el del
    // crudo, de paso por el bucket.
    final ruta = 'productos/$productoId/${_nombreCrudoUnico(formato)}';

    try {
      await _storage
          .ref(ruta)
          .putData(
            bytes,
            SettableMetadata(contentType: contentTypeDe(formato)),
          );
    } catch (e) {
      throw comoFalloDeFotos(e, nombreOriginal);
    }

    final HttpsCallableResult<Object?> resultado;
    try {
      final callable = _functions.httpsCallable('procesarFoto');
      resultado = await callable.call<Object?>({
        'productoId': productoId,
        'ruta': ruta,
      });
    } catch (e) {
      throw comoFalloDeFotos(e, nombreOriginal);
    }

    final foto = _fotoDesde(resultado.data);

    if (agregarAlDocumento) {
      try {
        await _db.collection(_coleccion).doc(productoId).update({
          // `arrayUnion`, nunca reescribir la lista: dos personas cargando
          // fotos del mismo vino a la vez no se pisan (ARQUITECTURA §5.3,
          // design.md decision 5 -- el `arrayUnion` lo hace el panel, no la
          // callable, para que `firestore.rules` siga siendo la ultima
          // palabra sobre `imagenes[]`).
          _campoDeImagenes: FieldValue.arrayUnion([foto.url]),
        });
      } catch (e) {
        throw comoFalloDeFotos(e, nombreOriginal);
      }
    }

    return foto;
  }

  @override
  Future<void> quitar({required String productoId, required String url}) async {
    try {
      await _db.collection(_coleccion).doc(productoId).update({
        _campoDeImagenes: FieldValue.arrayRemove([url]),
      });
    } catch (e) {
      // El archivo NO se borra de Storage a proposito (proposal.md, "Lo que
      // este cambio NO hace"): borrarlo daria 404 en paginas ya cacheadas
      // en el borde hasta la proxima purga, y el tramo 4 de Cloudflare
      // todavia no existe.
      throw comoFalloDeFotos(e, url);
    }
  }

  @override
  Future<void> hacerPrincipal({
    required String productoId,
    required String url,
  }) async {
    final ref = _db.collection(_coleccion).doc(productoId);
    final _CambioDePrincipal resultado;
    try {
      resultado = await _db.runTransaction((tx) async {
        final actual = await tx.get(ref);
        final imagenes = _urlsDe(actual.data()?[_campoDeImagenes]);
        final nueva = conPrincipal(imagenes, url);
        if (nueva == null) return _CambioDePrincipal.yaNoEsta;
        if (nueva.first == imagenes.first) return _CambioDePrincipal.yaEra;
        tx.update(ref, {_campoDeImagenes: nueva});
        return _CambioDePrincipal.cambiada;
      });
    } catch (e) {
      throw comoFalloDeFotos(e, url);
    }
    // La excepción se arma AFUERA de la transacción: en web una excepción
    // propia que cruza el puente de promesas puede llegar envuelta.
    if (resultado == _CambioDePrincipal.yaNoEsta) {
      throw FalloDeFotos(ErrorDeFotos.yaNoEsta, url);
    }
  }

  List<String> _urlsDe(Object? valor) =>
      valor is List ? valor.whereType<String>().toList() : const <String>[];

  /// Lo que devuelve `procesarFoto`: `{ url, ancho, alto,
  /// porcentajeRecortado }`. `num` y no `int` en el mapa -- `cloud_functions`
  /// en web decodifica los numeros de la respuesta JSON como `double` o
  /// `int` segun el valor, nunca al reves.
  FotoDelVino _fotoDesde(Object? datos) {
    final mapa = Map<Object?, Object?>.from(datos! as Map);
    return FotoDelVino(
      url: mapa['url']! as String,
      ancho: (mapa['ancho']! as num).toInt(),
      alto: (mapa['alto']! as num).toInt(),
      porcentajeRecortado: (mapa['porcentajeRecortado']! as num).toInt(),
    );
  }

  /// Un nombre de un solo segmento para el crudo, sin depender de ningun
  /// paquete de UUID: 16 bytes de `Random.secure()` en hexadecimal alcanzan
  /// para que dos subidas del mismo vino no choquen, y este nombre nunca
  /// viaja a `imagenes[]` -- lo borra la callable apenas termina de subir el
  /// WebP final (`procesar_foto.ts`).
  String _nombreCrudoUnico(FormatoDeFoto formato) {
    final aleatorio = Random.secure();
    final bytes = List<int>.generate(16, (_) => aleatorio.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$hex.${extensionDe(formato)}';
  }
}
