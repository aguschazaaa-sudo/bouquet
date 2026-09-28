import '../../../core/contratos/estado_entrega.dart';
import 'orden.dart';

// El aviso de que un pedido salio (HU-07.3): un enlace `wa.me` con el chat del
// comprador y el texto ya escrito. La persona lo abre, lo lee y aprieta enviar
// desde SU WhatsApp. Cero infraestructura, cero lecturas, cero escrituras: no
// queda registro de que se aviso, y el registro es el chat.
//
// ⚠️ Recortada: el link a `/pedido/<numero>` (ADR 010 §6) no va, porque esa ruta
// de la vidriera no existe. Lo suma la sesion de `crearOrden`.

/// `true` si a este pedido se le puede avisar que salio: esta despachado y
/// sabe por donde. Tambien despues de volver a despachar una entrega fallida:
/// el correo o el seguimiento pueden ser otros.
bool sePuedeAvisar(Orden orden) =>
    orden.estadoEntrega == EstadoEntrega.despachada && orden.despacho != null;

final _e164 = RegExp(r'^\+[1-9]\d{7,14}$');

/// El enlace que abre WhatsApp en el chat de [telefonoE164] con [texto] escrito,
/// o `null` si el telefono no es E.164.
///
/// `wa.me` lee los digitos como el numero COMPLETO: uno mal armado abre un chat
/// con otra persona sin fallar (glosario). Por eso no se arregla nada aca: el
/// telefono ya se guardo normalizado y, si no lo esta, no se avisa.
///
/// El texto va con `encodeComponent`: el espacio como `%20` y no como `+`, que
/// en un query de formulario es un espacio pero `wa.me` puede dejar literal, y
/// el `#` del numero como `%23`, que sin escapar cortaria el texto ahi.
Uri? enlaceDeWhatsapp(String telefonoE164, String texto) {
  if (!_e164.hasMatch(telefonoE164)) return null;
  final digitos = telefonoE164.substring(1);
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
