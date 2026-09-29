import '../../../core/contratos/despacho.dart';
import '../../../core/contratos/estado_entrega.dart';
import 'despacho_de_orden.dart';
import 'orden.dart';

// Escribirle al comprador por WhatsApp desde un pedido: un enlace `wa.me` con su
// chat y el mensaje que le toca al estado del pedido, ya escrito (HU-07.3). La
// persona lo abre, lo lee y aprieta enviar desde SU WhatsApp. Cero
// infraestructura, cero lecturas, cero escrituras: no queda registro de que se
// escribio, y el registro es el chat.
//
// Lo ve todo el que entra al panel, en cualquier estado del pedido: la marca
// por persona se saco a pedido del dueño, y el dueño pidio un mensaje por
// estado (2026-09-29, ADR 021, *Revision*).
//
// ⚠️ Recortada: el link a `/pedido/<numero>` (ADR 010 §6) no va, porque esa ruta
// de la vidriera no existe. Lo suma la sesion de `crearOrden`.

/// Que mensaje se le deja escrito al comprador, con lo que ese mensaje necesita.
/// Los textos son de `presentation/` (los lee el comprador: pasan por `voz`).
sealed class MensajeAlComprador {
  const MensajeAlComprador();
}

/// Por preparar o preparandose: que lo anotamos, y que lleva.
final class PedidoAnotado extends MensajeAlComprador {
  const PedidoAnotado();
}

/// Despachado: por donde salio y el seguimiento. Tambien despues de volver a
/// despachar una entrega fallida: el correo o el seguimiento pueden ser otros.
final class PedidoSalio extends MensajeAlComprador {
  const PedidoSalio(this.despacho);
  final DespachoDeOrden despacho;
}

/// La entrega fallo. [motivo] es `null` si la Orden no lo tiene legible: el
/// mensaje va sin el motivo, no se inventa uno.
final class PedidoNoSeEntrego extends MensajeAlComprador {
  const PedidoNoSeEntrego(this.motivo);
  final MotivoDeFalla? motivo;
}

/// Entregado: si llego todo bien.
final class PedidoLlego extends MensajeAlComprador {
  const PedidoLlego();
}

/// El mensaje que le toca a [orden] por su estado de entrega, o `null` si el
/// chat se abre vacio: un pedido cancelado, o uno despachado sin el dato de por
/// donde salio (no se avisa algo que no se sabe).
MensajeAlComprador? mensajeSegun(Orden orden) {
  final despacho = orden.despacho;
  return switch (orden.estadoEntrega) {
    EstadoEntrega.sin_preparar || EstadoEntrega.preparando =>
      const PedidoAnotado(),
    EstadoEntrega.despachada => despacho == null ? null : PedidoSalio(despacho),
    EstadoEntrega.fallida => PedidoNoSeEntrego(orden.entregaFallida?.motivo),
    EstadoEntrega.entregada => const PedidoLlego(),
    EstadoEntrega.cancelada => null,
  };
}

final _e164 = RegExp(r'^\+[1-9]\d{7,14}$');

/// El enlace que abre WhatsApp en el chat de [telefonoE164] con [texto] escrito,
/// o con el chat vacio si [texto] es `null`. `null` si el telefono no es E.164.
///
/// `wa.me` lee los digitos como el numero COMPLETO: uno mal armado abre un chat
/// con otra persona sin fallar (glosario). Por eso no se arregla nada aca: el
/// telefono ya se guardo normalizado y, si no lo esta, no se escribe.
///
/// El texto va con `encodeComponent`: el espacio como `%20` y no como `+`, que
/// en un query de formulario es un espacio pero `wa.me` puede dejar literal, y
/// el `#` del numero como `%23`, que sin escapar cortaria el texto ahi.
Uri? enlaceDeWhatsapp(String telefonoE164, String? texto) {
  if (!_e164.hasMatch(telefonoE164)) return null;
  final digitos = telefonoE164.substring(1);
  if (texto == null) return Uri.parse('https://wa.me/$digitos');
  return Uri.parse(
    'https://wa.me/$digitos?text=${Uri.encodeComponent(texto)}',
  );
}

/// El nombre de pila con el que se saluda: la primera palabra de lo que se
/// cargo. `null` si no hay nada, y el saludo va sin nombre (voz.md §4.2:
/// *"Nombre, o nada"*).
String? nombreDePila(String nombre) {
  final palabras = nombre.trim().split(RegExp(r'\s+'));
  return palabras.first.isEmpty ? null : palabras.first;
}
