import '../../../core/contratos/despacho.dart';
import '../../../core/contratos/estado_entrega.dart';
import 'orden.dart';

/// Un paso del eje de entrega que el panel escribe **directo** en la Orden
/// (EP-07, ADR 019): las reglas lo validan contra el estado de ahora, sin una
/// lectura extra. Cancelar NO es un paso de estos: devuelve stock y lo hace la
/// callable (`RepositorioDePedidos.cancelar`).
sealed class PasoDeEntrega {
  const PasoDeEntrega();

  /// El estado en el que queda la Orden.
  EstadoEntrega get destino;
}

/// HU-07.1. Para que nadie mas lo arme dos veces.
final class Preparar extends PasoDeEntrega {
  const Preparar();

  @override
  EstadoEntrega get destino => EstadoEntrega.preparando;
}

/// HU-07.2, y volver a despachar tras una entrega fallida (HU-07.5).
final class Despachar extends PasoDeEntrega {
  const Despachar({required this.correo, this.seguimiento});

  final Correo correo;

  /// Ya limpio (`seguimientoDe`): sin espacios de mas, y `null` si no hay.
  final String? seguimiento;

  @override
  EstadoEntrega get destino => EstadoEntrega.despachada;
}

/// HU-07.4. Quiere decir que **lo recibio un mayor de 18** (ADR 002).
final class Entregar extends PasoDeEntrega {
  const Entregar();

  @override
  EstadoEntrega get destino => EstadoEntrega.entregada;
}

/// HU-07.5. El motivo es obligatorio.
final class NoSeEntrego extends PasoDeEntrega {
  const NoSeEntrego(this.motivo);

  final MotivoDeFalla motivo;

  @override
  EstadoEntrega get destino => EstadoEntrega.fallida;
}

/// Lo que el detalle de un pedido ofrece hacer. Cada una es un boton.
enum AccionDelPedido { preparar, despachar, entregar, noSeEntrego, cancelar }

EstadoEntrega _destinoDe(AccionDelPedido a) => switch (a) {
  AccionDelPedido.preparar => EstadoEntrega.preparando,
  AccionDelPedido.despachar => EstadoEntrega.despachada,
  AccionDelPedido.entregar => EstadoEntrega.entregada,
  AccionDelPedido.noSeEntrego => EstadoEntrega.fallida,
  AccionDelPedido.cancelar => EstadoEntrega.cancelada,
};

/// Lo que se le puede hacer a [orden] **ahora**, en el orden de los botones.
///
/// Sale de la tabla del contrato, no de una lista por estado escrita aca: los
/// pasos del panel son `laEscribeElPanel`, y cancelar es lo que la tabla
/// permite y hace el servidor. Despachar ademas pide [sePuedeDespachar]: un
/// pedido de la tienda impago no sale.
List<AccionDelPedido> accionesDe(Orden orden) {
  final estado = orden.estadoEntrega;
  return [
    for (final a in AccionDelPedido.values)
      if (_sePuede(a, orden, estado)) a,
  ];
}

bool _sePuede(AccionDelPedido a, Orden orden, EstadoEntrega estado) {
  final destino = _destinoDe(a);
  if (a == AccionDelPedido.cancelar) {
    return estado != destino && transicionEntregaValida(estado, destino);
  }
  if (!laEscribeElPanel(estado, destino)) return false;
  if (a == AccionDelPedido.despachar) {
    return sePuedeDespachar(orden.origen, orden.estadoPago);
  }
  return true;
}

/// `true` si el despacho es el paso que sigue pero **falta el pago**: la
/// pantalla lo dice en vez de esconder el boton sin explicar por que.
bool despachoEsperaElPago(Orden orden) =>
    laEscribeElPanel(orden.estadoEntrega, EstadoEntrega.despachada) &&
    !sePuedeDespachar(orden.origen, orden.estadoPago);

/// El seguimiento como se guarda: sin espacios en las puntas, y `null` si
/// quedo vacio. `null` tambien si pasa de [largoDelSeguimiento]: la hoja no
/// deja confirmar en ese caso ([seguimientoEsValido]).
String? seguimientoDe(String escrito) {
  final limpio = escrito.trim();
  if (limpio.isEmpty || limpio.length > largoDelSeguimiento) return null;
  return limpio;
}

bool seguimientoEsValido(String escrito) =>
    escrito.trim().length <= largoDelSeguimiento;
