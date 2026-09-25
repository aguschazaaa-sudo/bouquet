import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/contratos/despacho.dart';
import '../../../core/contratos/estado_entrega.dart';
import '../domain/fallo_de_pedidos.dart';
import '../domain/orden.dart';
import '../domain/paso_de_entrega.dart';
import '../domain/pedido_a_cargar.dart';
import '../domain/repositorio_de_pedidos.dart';
import 'cambios_de_entrega.dart';
import 'codigos_de_pedidos.dart';
import 'documento_de_la_orden.dart';
import 'fallos_de_pedidos.dart';

/// Los pedidos, contra las callables `crearOrdenDelPanel` y `cancelarOrden` y la
/// coleccion `ordenes` (HU-10.1, HU-06.1, HU-06.2, ADR 018; EP-07, ADR 019).
class RepositorioDePedidosFirebase implements RepositorioDePedidos {
  RepositorioDePedidosFirebase(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  /// **Un solo `try`/`catch` alrededor de la llamada, nunca un `try`/`finally`
  /// sin `catch`** (ARQUITECTURA §5.4 regla 4, HU-04.4): el bug de PadelPunilla
  /// vivio meses sin un solo reporte porque la excepcion se perdia como error
  /// async no manejado.
  @override
  Future<ResultadoDeCarga> cargar(PedidoACargar pedido) async {
    final HttpsCallableResult<Object?> resultado;
    try {
      resultado = await _functions
          .httpsCallable('crearOrdenDelPanel')
          .call<Object?>(pedido.aJson);
    } catch (e) {
      throw comoFalloDePedidos(e);
    }
    return _leer(resultado.data);
  }

  /// Lo que devuelve la callable: `{ ordenId, numero, repetido }`.
  ///
  /// Una respuesta con otra forma es un [FalloDePedidos] `desconocido`, no un
  /// crash: el pedido PUDO haberse creado, y la pantalla lo dice en vez de
  /// mostrar una excepcion de tipos.
  ResultadoDeCarga _leer(Object? datos) {
    if (datos is Map) {
      final ordenId = datos['ordenId'];
      final numero = datos['numero'];
      final repetido = datos['repetido'];
      if (ordenId is String && numero is num && repetido is bool) {
        return ResultadoDeCarga(
          ordenId: ordenId,
          numero: numero.toInt(),
          repetido: repetido,
        );
      }
    }
    throw const FalloDePedidos(
      ErrorDePedido.desconocido,
      codigo: 'respuesta-inesperada',
    );
  }

  /// `where('estadoEntrega', ==)` + `orderBy('creadaEn', desc)` + `limit`: la
  /// consulta del indice ya declarado en `firestore.indexes.json`. **Se
  /// verifica corriendola**, no mirando que el indice este `READY`.
  ///
  /// Un documento sin `creadaEn` no entra en el orden y no aparece: la callable
  /// lo escribe siempre con la hora del servidor.
  ///
  /// **No atrapa los errores**: los deja subir, para que la pantalla los dibuje
  /// como un fallo y no como "no hay pedidos".
  @override
  Future<PaginaDePedidos> bandeja(
    EstadoEntrega estado, {
    DateTime? despuesDe,
  }) async {
    var consulta = _db
        .collection('ordenes')
        .where('estadoEntrega', isEqualTo: estado.name)
        .orderBy('creadaEn', descending: true);
    if (despuesDe != null) {
      consulta = consulta.startAfter([Timestamp.fromDate(despuesDe)]);
    }
    final instantanea = await consulta.limit(tamanoDePaginaDePedidos).get();

    final ordenes = <Orden>[];
    var incompletos = 0;
    for (final d in instantanea.docs) {
      final orden = ordenDesde(
        d.id,
        d.data(),
        creadaEn: _hora(d.data()),
        horaDe: _horaDe,
      );
      if (orden == null) {
        incompletos += 1;
      } else {
        ordenes.add(orden);
      }
    }

    // Hay mas solo si la pagina vino llena. La marca es la `creadaEn` del
    // ultimo DOCUMENTO de la pagina, se pueda leer como Orden o no.
    final ultima = instantanea.docs.isEmpty ? null : instantanea.docs.last;
    final hayMas = instantanea.docs.length == tamanoDePaginaDePedidos;
    return PaginaDePedidos(
      ordenes: ordenes,
      incompletos: incompletos,
      siguiente: hayMas && ultima != null ? _hora(ultima.data()) : null,
    );
  }

  @override
  Future<DetalleDePedido> detalle(String id) async {
    final d = await _db.collection('ordenes').doc(id).get();
    if (!d.exists) return const PedidoInexistente();
    final datos = d.data() ?? const <String, Object?>{};
    final orden = ordenDesde(
      d.id,
      datos,
      creadaEn: _hora(datos),
      horaDe: _horaDe,
    );
    return orden == null ? const PedidoIncompleto() : PedidoEncontrado(orden);
  }

  /// `update`, no `set`: si la Orden no existe, falla en vez de crear una. Y
  /// **no lee antes**: las reglas miran el estado de ahora (`resource.data`) y
  /// rechazan un paso que ya no vale. Cero lecturas.
  @override
  Future<void> avanzar(String id, PasoDeEntrega paso) async {
    try {
      await _db
          .collection('ordenes')
          .doc(id)
          .update(
            cambiosDe(paso, horaDelServidor: FieldValue.serverTimestamp()),
          );
    } catch (e) {
      throw comoFalloDeEscritura(e);
    }
  }

  @override
  Future<ResultadoDeCancelacion> cancelar(
    String id,
    MotivoDeCancelacion motivo,
  ) async {
    final HttpsCallableResult<Object?> resultado;
    try {
      resultado = await _functions.httpsCallable('cancelarOrden').call<Object?>(
        {'ordenId': id, 'motivo': motivo.clave},
      );
    } catch (e) {
      throw comoFalloDePedidos(e, deLaCallable: falloDeCancelar);
    }
    final datos = resultado.data;
    if (datos is Map) {
      final numero = datos['numero'];
      final repetido = datos['repetido'];
      if (numero is num && repetido is bool) {
        return ResultadoDeCancelacion(
          numero: numero.toInt(),
          repetido: repetido,
          sinReponer: lineasSinReponerDesde(datos['sinReponer']),
        );
      }
    }
    // El pedido PUDO haberse cancelado: la pantalla lo vuelve a leer.
    throw const FalloDePedidos(
      ErrorDePedido.desconocido,
      codigo: 'respuesta-inesperada',
    );
  }

  /// `is`, no `as`: una `creadaEn` que no sea Timestamp (un script, un futuro
  /// escritor con un bug) no puede esconder la lista entera.
  DateTime? _hora(Map<String, Object?> datos) => _horaDe(datos['creadaEn']);

  static DateTime? _horaDe(Object? valor) => switch (valor) {
    final Timestamp t => t.toDate(),
    _ => null,
  };
}
