/// Lo que cruza del formulario al repositorio. Valores ya leidos y tipados:
/// solo existen si `BorradorDeVino.revisar` no encontro ningun problema.
library;

import '../../../core/contratos/producto.dart';
import 'ficha_del_vino.dart';

/// Un vino nuevo (HU-03.2 y HU-03.3).
///
/// ⚠️ **`stock` y `tipo` siguen sin salir de aca, a proposito.** Esos los
/// fija la unica factory del documento, en
/// `RepositorioDeProductosFirestore.crear`: que un vino nazca sin stock no
/// puede depender de lo que se toco en un formulario -- el primero siempre
/// llega por la reposicion, del servidor (ADR 008 §1).
///
/// `imagenes` y `publicar` SI salen de aca desde el 2026-09-23 (ADR 015 §5):
/// cargar el vino, sumarle una foto y ponerlo a la venta eran tres viajes
/// separados -- guardar, abrir de nuevo para subir la foto, abrir de nuevo
/// para publicar -- y el dueño midio que no tiene sentido. `documentoNuevo`
/// escribe los dos tal cual llegan aca.
class AltaDeVino {
  const AltaDeVino({
    required this.slug,
    required this.nombre,
    required this.ficha,
    required this.precio,
    required this.botellas,
    this.imagenes = const [],
    this.publicar = false,
  });

  /// Tambien el id del documento (ADR 013 §1).
  final String slug;
  final String nombre;

  /// Con color, varietales en el orden de la lista cerrada y la bodega
  /// elegida: `revisar` no deja pasar una ficha incompleta.
  final FichaDelVino ficha;

  /// Centavos de la unidad de venta, mayor que cero.
  final int precio;

  /// Botellas por unidad de venta. Inmutable despues del alta.
  final int botellas;

  /// Lo que ya se subio y proceso mientras el formulario todavia era un
  /// borrador -- `SeccionDeFotos` las junta con la ruta de Storage
  /// `productos/{slug}/...` antes de que el documento exista, y las suelta
  /// aca recien cuando se confirma el alta.
  final List<String> imagenes;

  /// Si el dueño tildo "Publicar apenas se cargue". `stock` sigue en `0`
  /// igual: publicar sin stock lo muestra "agotado" en la tienda, no lo
  /// inventa.
  final bool publicar;

  ColorDelVino get color => ficha.color!;
}

/// Un cambio a un campo que puede quedar vacio: la añada o la graduacion.
///
/// Hace falta porque en [CambiosDeVino] `null` significa "no cambio", y
/// borrar la añada tambien es un cambio. `Cambio(null)` es "quedo vacia".
class Cambio<T> {
  const Cambio(this.valor);

  final T valor;
}

/// La correccion de un vino (HU-03.4): **solo lo que cambio**, comparado
/// contra el vino que se abrio. Un campo en `null` no viaja, y lo que otra
/// persona cambio mientras tanto en otro campo no se pisa.
class CambiosDeVino {
  const CambiosDeVino({
    this.nombre,
    this.bodegaId,
    this.color,
    this.organico,
    this.region,
    this.volumenMl,
    this.anada,
    this.graduacion,
    this.descripcion,
    this.precio,
    this.varietalesAgregados = const [],
    this.varietalesQuitados = const [],
  });

  final String? nombre;
  final String? bodegaId;
  final ColorDelVino? color;
  final bool? organico;
  final String? region;
  final int? volumenMl;
  final Cambio<int?>? anada;
  final Cambio<int?>? graduacion;

  /// La prosa del dueño. Se corrige **tambien en un vino publicado**: no es
  /// plata, no dispara ninguna baranda, y arreglar una falta de ortografia no
  /// puede exigir sacar el vino de la tienda.
  final Cambio<String?>? descripcion;

  /// Solo si el vino no esta en la tienda (ADR 013 §9).
  final int? precio;

  /// Van con `arrayUnion` y `arrayRemove`, nunca reescribiendo la lista
  /// (ARQUITECTURA §5.3).
  final List<String> varietalesAgregados;
  final List<String> varietalesQuitados;

  bool get hayAlgo =>
      nombre != null ||
      bodegaId != null ||
      color != null ||
      organico != null ||
      region != null ||
      volumenMl != null ||
      anada != null ||
      graduacion != null ||
      descripcion != null ||
      precio != null ||
      varietalesAgregados.isNotEmpty ||
      varietalesQuitados.isNotEmpty;
}
