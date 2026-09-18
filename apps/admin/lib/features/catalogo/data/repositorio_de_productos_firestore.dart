import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/contratos/producto.dart';
import '../domain/escrituras_del_vino.dart';
import '../domain/fallo_de_catalogo.dart';
import '../domain/ficha_del_vino.dart';
import '../domain/producto_del_panel.dart';
import '../domain/repositorio_de_productos.dart';
import 'campos.dart';
import 'documento_del_vino.dart';
import 'fallos_de_firestore.dart';

/// Los productos, contra Firestore: leer, dar de alta y corregir. El stock
/// no va a pasar por aca nunca — lo escribe una callable del servidor
/// (ADR 008 §1).
class RepositorioDeProductosFirestore implements RepositorioDeProductos {
  const RepositorioDeProductosFirestore(this._db);

  final FirebaseFirestore _db;

  static const _coleccion = 'productos';

  @override
  Stream<List<ProductoDelPanel>> cambios() => _db
      .collection(_coleccion)
      .snapshots()
      .map((s) => s.docs.map(_desdeElDocumento).toList());

  /// El id del documento **es el slug**, y las reglas lo exigen (ADR 013 §1):
  /// la unicidad la da la base, sin lecturas de mas.
  ///
  /// ⚠️ **En una transaccion y no con un `set()` suelto.** Para las reglas,
  /// un `set()` sobre un documento que existe es un `update`, y sobre un vino
  /// sin stock es uno legitimo: **sobrescribiria en silencio** el vino que
  /// otra persona de la familia cargo un segundo antes. Lo prueba un caso de
  /// `scripts/reglas/productos.test.mjs`, escrito como tripwire. Y sin red la
  /// transaccion **falla**: un alta nunca queda confirmada a medias.
  @override
  Future<void> crear(AltaDeVino alta) async {
    final ref = _db.collection(_coleccion).doc(alta.slug);
    try {
      await _db.runTransaction((tx) async {
        final actual = await tx.get(ref);
        if (actual.exists) {
          throw const FalloDeCatalogo(ErrorDeCatalogo.yaExiste);
        }
        tx.set(ref, documentoNuevo(alta));
      });
    } catch (e) {
      throw comoFalloDeCatalogo(e);
    }
  }

  /// Un `WriteBatch` con dos `update` al mismo documento: los campos que
  /// cambiaron **mas** el `arrayUnion`, y despues el `arrayRemove`. Un mismo
  /// `update` no puede llevar los dos sobre el mismo campo.
  ///
  /// Se midio en el emulador que las reglas ven el estado FINAL del batch
  /// (ADR 013 §5), asi que reemplazar el unico varietal pasa. Unir primero
  /// igual, porque no cuesta nada.
  @override
  Future<void> corregir(String id, CambiosDeVino cambios) async {
    final ref = _db.collection(_coleccion).doc(id);
    final primero = {
      ...camposQueCambiaron(cambios),
      if (cambios.varietalesAgregados.isNotEmpty)
        campoDeLosVarietales: FieldValue.arrayUnion(
          cambios.varietalesAgregados,
        ),
    };
    final quitados = cambios.varietalesQuitados;
    if (primero.isEmpty && quitados.isEmpty) return;

    final batch = _db.batch();
    if (primero.isNotEmpty) batch.update(ref, primero);
    if (quitados.isNotEmpty) {
      batch.update(ref, {
        campoDeLosVarietales: FieldValue.arrayRemove(quitados),
      });
    }
    try {
      await batch.commit();
    } catch (e) {
      throw comoFalloDeCatalogo(e);
    }
  }

  /// ⚠️ **Ningun documento se descarta, ni el roto.** La vidriera si los
  /// descarta y los reporta en `descartes` (ADR 008 §2), y eso hoy **solo se
  /// lee en el log del build**: un vino publicado que no aparece en la tienda
  /// es invisible para el operador. El panel lo muestra con lo que se pudo
  /// leer, y HU-03.7 va a decir ademas por que la vidriera lo dejo afuera.
  ///
  /// Los valores por omision son los **seguros**: `publicado` en `false`
  /// —nunca afirmar que algo esta a la venta— y `precio` en 0, que ya es lo
  /// que el hallazgo 2 de `revisor-pagos` no deja publicar.
  static ProductoDelPanel _desdeElDocumento(
    QueryDocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final datos = d.data();
    final presentacion = mapaDe(datos['presentacion']);

    return ProductoDelPanel(
      id: d.id,
      slug: textoDe(datos['slug']),
      nombre: textoDe(datos['nombre']),
      precio: enteroDe(datos['precio']) ?? 0,
      publicado: boolDe(datos['publicado']),
      ficha: _fichaDesde(mapaDe(datos['fichaVino'])),
      botellas: enteroDe(presentacion['botellas']) ?? 1,
      // `null` es "no tiene stock propio", que es lo correcto para un
      // compuesto y tambien para un documento al que le falta el campo: el
      // panel dice "sin dato", no "cero", que significaria agotado.
      stock: enteroDe(datos['stock']),
      muestra: boolDe(datos['muestra']),
    );
  }

  /// Lo que falta queda vacio o en `null`, **nunca inventado**: un color que
  /// no es de la lista queda sin elegir y el formulario lo pide; una añada
  /// ilegible queda vacia y no se confunde con un año.
  static FichaDelVino _fichaDesde(Map<String, Object?> f) => FichaDelVino(
    bodegaId: textoDe(f['bodegaId']),
    varietales: textosDe(f['varietales']),
    color: ColorDelVino.desde(textoDe(f['color'])),
    organico: boolDe(f['organico']),
    anada: enteroDe(f['anada']),
    region: textoDe(f['region']),
    volumenMl: enteroDe(f['volumenMl']),
    graduacion: enteroDe(f['graduacion']),
  );
}
