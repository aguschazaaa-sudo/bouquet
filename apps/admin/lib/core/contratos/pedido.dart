// El espejo en Dart de lo que el panel necesita de
// `packages/contratos/src/{orden,pedido}.ts` para cargar y leer pedidos.
// HU-10.1, ADR 018.
//
// Lo que NO se espeja: `parsearPedidoDelPanel`. Ese valida un objeto de tipo
// desconocido que llega por la red; aca el pedido ya es un tipo. Lo que queda
// por validar es el RANGO, y los topes viajan en el JSON generado.

import 'estado_pago.dart';

/// De donde vino una Orden. Espejo de `ORIGENES`: [clave] **es** el string
/// que Firestore guarda en `origen`.
///
/// El origen decide una regla de plata --la caja de seis no aplica a WhatsApp--
/// asi que **lo fija el servidor** segun que callable se llamo. El panel lo
/// LEE; nunca lo manda (ADR 018 §1).
enum Origen {
  vidriera('vidriera'),
  whatsapp('whatsapp');

  const Origen(this.clave);

  final String clave;

  /// `null` si [valor] no es uno de los dos origenes conocidos.
  static Origen? desde(Object? valor) {
    for (final o in values) {
      if (o.clave == valor) return o;
    }
    return null;
  }
}

/// El estado de pago con el que NACE una Orden de cada origen. Espejo de
/// `estadoDePagoInicial`: `whatsapp` nace `por_fuera` y `vidriera`, `pendiente`.
EstadoPago estadoDePagoInicial(Origen origen) =>
    origen == Origen.whatsapp ? EstadoPago.por_fuera : EstadoPago.pendiente;

/// Cuantas lineas distintas puede tener un pedido. Espejo de `TOPE_DE_LINEAS`.
const topeDeLineasDelPedido = 30;
