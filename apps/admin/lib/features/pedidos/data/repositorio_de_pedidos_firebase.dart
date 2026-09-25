import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/contratos/despacho.dart';
import '../domain/fallo_de_pedidos.dart';
import '../domain/lo_que_requiere_accion.dart';
import '../domain/orden.dart';
import '../domain/paso_de_entrega.dart';
import '../domain/pedido_a_cargar.dart';
import '../domain/repositorio_de_pedidos.dart';
import '../domain/vista_de_bandeja.dart';
import 'cambios_de_entrega.dart';
import 'cambios_de_nota.dart';
import 'codigos_de_pedidos.dart';
import 'documento_de_la_orden.dart';
import 'fallos_de_pedidos.dart';

/// Los pedidos, contra las callables `crearOrdenDelPanel` y `cancelarOrden` y la
/// coleccion `ordenes` (HU-10.1, HU-06.1, HU-06.2, ADR 018; EP-07, ADR 019;
/// HU-06.3, HU-06.4 y HU-07.7, ADR 020).
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

  /// `where` + `orderBy('creadaEn', desc)` + `limit`, con el `where` de la
  /// [vista]:
  ///
  /// - **Un estado** (HU-06.1): `estadoEntrega ==`, con el indice
  ///   `(estadoEntrega, creadaEn)`.
  /// - **Requieren accion** (HU-06.3): un `OR` de los tramos que salen de la
  ///   proyeccion (`tramosQueRequierenAccion`), cada uno `estadoEntrega ==` y, si
  ///   no son todos, `estadoPago in`. Usa el indice `(estadoEntrega, estadoPago,
  ///   creadaEn)` (ADR 020 §1).
  ///
  /// **Se verifica corriendola**, no mirando que el indice este `READY`. Un
  /// documento sin `creadaEn` no entra en el orden y no aparece: las callables la
  /// escriben siempre con la hora del servidor.
  ///
  /// **No atrapa los errores**: los deja subir, para que la pantalla los dibuje
  /// como un fallo y no como "no hay pedidos".
  @override
  Future<PaginaDePedidos> bandeja(
    VistaDeBandeja vista, {
    DateTime? despuesDe,
  }) async {
    var consulta = _db
        .collection('ordenes')
        .where(_filtroDe(vista))
        .orderBy('creadaEn', descending: true);
    if (despuesDe != null) {
      consulta = consulta.startAfter([Timestamp.fromDate(despuesDe)]);
    }
    final instantanea = await consulta.limit(tamanoDePaginaDePedidos).get();

    final ordenes = <Orden>[];
    var incompletos = 0;
    for (final d in instantanea.docs) {
      final orden = _ordenDe(d);
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

  static Filter _filtroDe(VistaDeBandeja vista) => switch (vista) {
    DeUnEstado(:final estado) => Filter(
      'estadoEntrega',
      isEqualTo: estado.name,
    ),
    // `Filter.or` es posicional (hasta 30): se pliega de a dos. Firestore
    // aplana los `OR` anidados, asi que es la misma consulta.
    RequierenAccion() =>
      tramosQueRequierenAccion().map(_filtroDelTramo).reduce(Filter.or),
  };

  static Filter _filtroDelTramo(TramoQueRequiereAccion t) {
    final entrega = Filter('estadoEntrega', isEqualTo: t.entrega.name);
    final pagos = t.pagos;
    if (pagos == null) return entrega;
    return Filter.and(
      entrega,
      Filter('estadoPago', whereIn: [for (final p in pagos) p.name]),
    );
  }

  @override
  Future<DetalleDePedido> detalle(String id) async {
    final d = await _db.collection('ordenes').doc(id).get();
    if (!d.exists) return const PedidoInexistente();
    final orden = _ordenDe(d);
    return orden == null ? const PedidoIncompleto() : PedidoEncontrado(orden);
  }

  /// `where('numero', ==)` + `limit(1)`: el indice de un solo campo que Firestore
  /// crea solo. El `limit` lo exigen las reglas (`list` hasta 50), y 1 alcanza:
  /// el numero lo asigna un contador en una transaccion, no se repite.
  @override
  Future<DetalleDePedido> porNumero(int numero) async {
    final instantanea = await _db
        .collection('ordenes')
        .where('numero', isEqualTo: numero)
        .limit(1)
        .get();
    if (instantanea.docs.isEmpty) return const PedidoInexistente();
    final orden = _ordenDe(instantanea.docs.first);
    return orden == null ? const PedidoIncompleto() : PedidoEncontrado(orden);
  }

  /// Mismo camino que [avanzar]: `update`, cero lecturas, y las reglas
  /// (`anota()`) validan que solo cambien la nota y la hora.
  @override
  Future<void> anotar(String id, String? nota) async {
    try {
      await _db
          .collection('ordenes')
          .doc(id)
          .update(
            cambiosDeNota(
              nota,
              horaDelServidor: FieldValue.serverTimestamp(),
              borrar: FieldValue.delete(),
            ),
          );
    } catch (e) {
      throw comoFalloDeEscritura(e);
    }
  }

  Orden? _ordenDe(DocumentSnapshot<Map<String, dynamic>> d) {
    final datos = d.data() ?? const <String, Object?>{};
    return ordenDesde(d.id, datos, creadaEn: _hora(datos), horaDe: _horaDe);
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
