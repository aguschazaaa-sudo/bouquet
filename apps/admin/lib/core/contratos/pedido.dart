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

/// El precio de una unidad de venta no pasa de esto, en centavos. Espejo de
/// `PRECIO_MAXIMO`: es el mayor que, por el maximo de unidades y de lineas, da
/// un entero seguro. Un vino con un precio mayor no se vende y se dice.
const precioMaximo = 60047995031;

/// El largo maximo de cada texto libre de la entrega. Espejo de
/// `LARGOS_DE_ENTREGA`: sin tope, una `referencia` de 900.000 caracteres deja
/// la Orden cerca del MiB de Firestore (ADR 018, hallazgo 8 de `revisor-pagos`).
const largosDeEntrega = <String, int>{
  'nombre': 120,
  'email': 254,
  'calle': 120,
  'numero': 20,
  'piso': 20,
  'referencia': 300,
  'localidad': 120,
};
