// El espejo en Dart de `packages/contratos/src/despacho.ts`. EP-07, ADR 019.
//
// Lo que el panel escribe al mover una Orden por el eje de entrega: por donde
// salio, por que no se entrego, por que se cancelo. Y las dos reglas que deciden
// que botones se ofrecen: que pasos escribe el panel (todos los de la tabla menos
// cancelar, que devuelve stock y lo hace el servidor) y cuando un pedido se puede
// despachar.
//
// `test/core/contratos/despacho_test.dart` compara contra
// `generated/contratos.json` (seccion `despacho`), donde las dos reglas viajan
// CALCULADAS por el TypeScript de hoy: el test no compara este archivo contra si
// mismo.

import 'estado_entrega.dart';
import 'estado_pago.dart';
import 'pedido.dart';

/// Por donde salio un pedido. Espejo de `CORREOS`: [clave] **es** el string que
/// queda en `despacho.correo`, y las reglas lo validan contra su propia copia.
enum Correo {
  andreani('andreani'),
  correoArgentino('correo_argentino'),
  oca('oca'),
  enMano('en_mano'),
  otro('otro');

  const Correo(this.clave);

  final String clave;

  static Correo? desde(Object? valor) {
    for (final c in values) {
      if (c.clave == valor) return c;
    }
    return null;
  }
}

/// Cuantos caracteres puede tener un numero de seguimiento. Espejo de
/// `LARGO_DEL_SEGUIMIENTO`. Es opcional: una entrega en mano no tiene.
const largoDelSeguimiento = 60;

/// Por que no se pudo entregar. Espejo de `MOTIVOS_DE_FALLA`. `sinMayor` es el
/// caso legal: `entregada` quiere decir que firmo un mayor de 18.
enum MotivoDeFalla {
  sinMayor('sin_mayor'),
  nadie('nadie'),
  direccion('direccion'),
  rechazo('rechazo'),
  otro('otro');

  const MotivoDeFalla(this.clave);

  final String clave;

  static MotivoDeFalla? desde(Object? valor) {
    for (final m in values) {
      if (m.clave == valor) return m;
    }
    return null;
  }
}

/// Por que se cancelo. Espejo de `MOTIVOS_DE_CANCELACION`.
enum MotivoDeCancelacion {
  malCargado('mal_cargado'),
  cliente('cliente'),
  faltaVino('falta_vino'),
  otro('otro');

  const MotivoDeCancelacion(this.clave);

  final String clave;

  static MotivoDeCancelacion? desde(Object? valor) {
    for (final m in values) {
      if (m.clave == valor) return m;
    }
    return null;
  }
}

/// Por que una linea de un pedido cancelado NO volvio al stock. Espejo de
/// `MOTIVOS_SIN_REPONER`.
enum MotivoSinReponer {
  noExiste('no_existe'),
  otraPresentacion('otra_presentacion'),
  compuesto('compuesto'),
  productoRoto('producto_roto');

  const MotivoSinReponer(this.clave);

  final String clave;

  static MotivoSinReponer? desde(Object? valor) {
    for (final m in values) {
      if (m.clave == valor) return m;
    }
    return null;
  }
}

/// Lo que el panel NUNCA escribe en `estadoEntrega`: cancelar devuelve el
/// stock, y eso lo hace la callable `cancelarOrden`. Espejo de
/// `SOLO_LO_ESCRIBE_EL_SERVIDOR`.
const soloLoEscribeElServidor = {EstadoEntrega.cancelada};

/// Si el panel escribe directo el paso de [antes] a [despues]. Espejo de
/// `laEscribeElPanel`: la tabla de ADR 002, menos lo del servidor, y sin
/// reescribir el mismo estado.
bool laEscribeElPanel(EstadoEntrega antes, EstadoEntrega despues) =>
    antes != despues &&
    !soloLoEscribeElServidor.contains(despues) &&
    transicionesEntrega[antes]!.contains(despues);

/// Un pedido de la vidriera impago no se despacha; uno de WhatsApp se despacha
/// sin mirar el pago, porque se cobra por fuera. Espejo de `sePuedeDespachar`.
bool sePuedeDespachar(Origen origen, EstadoPago estadoPago) =>
    origen == Origen.whatsapp || estadoPago == EstadoPago.pagada;
