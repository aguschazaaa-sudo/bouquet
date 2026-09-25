import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import 'data/repositorio_de_pedidos_firebase.dart';
import 'domain/orden.dart';
import 'domain/repositorio_de_pedidos.dart';
import 'domain/vista_de_bandeja.dart';

/// El unico archivo de la feature que conoce la implementacion.
///
/// Sin `autoDispose`: es un repositorio, no una lectura.
final repositorioDePedidosProvider = Provider<RepositorioDePedidos>(
  (ref) => RepositorioDePedidosFirebase(
    ref.watch(firestoreProvider),
    ref.watch(functionsProvider),
  ),
);

/// Lo que la bandeja muestra de un estado: las ordenes cargadas hasta ahora y
/// como pedir mas.
class Bandeja {
  const Bandeja({
    required this.ordenes,
    required this.incompletos,
    this.siguiente,
  });

  factory Bandeja.desde(PaginaDePedidos p) => Bandeja(
    ordenes: p.ordenes,
    incompletos: p.incompletos,
    siguiente: p.siguiente,
  );

  final List<Orden> ordenes;

  /// Documentos que no se pudieron leer como Orden, entre todas las paginas.
  final int incompletos;
  final DateTime? siguiente;

  bool get hayMas => siguiente != null;
  bool get estaVacia => ordenes.isEmpty && incompletos == 0;

  Bandeja sumar(PaginaDePedidos p) => Bandeja(
    ordenes: [...ordenes, ...p.ordenes],
    incompletos: incompletos + p.incompletos,
    siguiente: p.siguiente,
  );
}

/// La bandeja de una vista: un estado de entrega (HU-06.1) o lo que requiere
/// accion (HU-06.3). **Una consulta por apertura**, y otra por cada *"Ver mas"* o
/// *"Actualizar"*: nunca un stream abierto (ARQUITECTURA §6.3, ADR 018 §7).
///
/// `autoDispose`: al salir de la pantalla se suelta, y volver a entrar lee de
/// nuevo, asi que un pedido cargado recien aparece.
class BandejaDePedidos
    extends AutoDisposeFamilyAsyncNotifier<Bandeja, VistaDeBandeja> {
  @override
  Future<Bandeja> build(VistaDeBandeja arg) async {
    final pagina = await ref.read(repositorioDePedidosProvider).bandeja(arg);
    return Bandeja.desde(pagina);
  }

  /// La pagina que sigue, sumada a lo que ya hay. Si falla lanza: la pantalla
  /// lo dice sin perder lo cargado.
  Future<void> verMas() async {
    final actual = state.valueOrNull;
    if (actual == null || !actual.hayMas) return;
    final pagina = await ref
        .read(repositorioDePedidosProvider)
        .bandeja(arg, despuesDe: actual.siguiente);
    state = AsyncData(actual.sumar(pagina));
  }
}

final bandejaProvider = AsyncNotifierProvider.autoDispose
    .family<BandejaDePedidos, Bandeja, VistaDeBandeja>(BandejaDePedidos.new);

/// El detalle de un pedido por id (HU-06.2): **una lectura**. Solo se usa
/// cuando la pantalla no recibio la Orden ya cargada de la bandeja.
final pedidoProvider = FutureProvider.autoDispose
    .family<DetalleDePedido, String>(
      (ref, id) => ref.watch(repositorioDePedidosProvider).detalle(id),
    );
