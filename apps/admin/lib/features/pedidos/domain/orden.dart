import '../../../core/contratos/estado_entrega.dart';
import '../../../core/contratos/estado_pago.dart';
import '../../../core/contratos/estado_publico.dart';
import '../../../core/contratos/pedido.dart';
import 'despacho_de_orden.dart';

/// Una linea de la Orden: un **snapshot**, no el producto de hoy. El precio del
/// vino cambia; el que se anoto, no (ARQUITECTURA §5.2).
class ItemDeOrden {
  const ItemDeOrden({
    required this.productoId,
    required this.nombre,
    required this.precioUnitario,
    required this.cantidad,
    required this.botellas,
  });

  final String productoId;
  final String nombre;

  /// Centavos de la unidad de venta. Entero, nunca float.
  final int precioUnitario;

  /// Unidades de venta, no botellas.
  final int cantidad;

  /// Botellas por unidad de venta, **al momento de crear**.
  final int botellas;

  int get subtotal => precioUnitario * cantidad;
  int get botellasEnTotal => cantidad * botellas;
}

/// Quien recibe. La Orden no guarda una cuenta ni una entidad `Cliente`: el
/// contacto viaja adentro (glosario, "Cliente").
class ContactoDeOrden {
  const ContactoDeOrden({
    required this.nombre,
    required this.telefonoE164,
    this.email,
  });

  final String nombre;

  /// Ya normalizado: es lo que lee `wa.me`.
  final String telefonoE164;
  final String? email;
}

/// A donde va. `provincia` es el codigo ISO; el nombre se saca de
/// `nombreDeProvincia`.
class EntregaDeOrden {
  const EntregaDeOrden({
    required this.calle,
    required this.numero,
    required this.codigoPostal,
    required this.localidad,
    required this.provincia,
    this.piso,
    this.referencia,
  });

  final String calle;
  final String numero;
  final String? piso;
  final String? referencia;
  final String codigoPostal;
  final String localidad;
  final String provincia;
}

/// Una Orden, como la ve el panel (HU-06.1, HU-06.2).
///
/// **No trae el estado como un solo campo**: hay dos ejes (ADR 002), y el
/// rotulo sale de [estadoPublico], que llama a la proyeccion. Nadie en
/// `presentation/` arma un rotulo mirando los dos campos por separado.
class Orden {
  const Orden({
    required this.id,
    required this.numero,
    required this.origen,
    required this.estadoPago,
    required this.estadoEntrega,
    required this.items,
    required this.subtotal,
    required this.total,
    required this.contacto,
    required this.entrega,
    this.creadaEn,
    this.notasOperador,
    this.despacho,
    this.entregaFallida,
    this.cancelacion,
  });

  /// El id del documento. **Nunca se le muestra a nadie**: lo que se dice es el
  /// [numero] (glosario).
  final String id;

  final int numero;
  final Origen origen;
  final EstadoPago estadoPago;
  final EstadoEntrega estadoEntrega;
  final List<ItemDeOrden> items;

  /// Suma de los precios de lista. **No es lo que se cobro**: el cobro de un
  /// pedido de WhatsApp va por fuera y el panel no lo sigue (ADR 018 §6).
  final int subtotal;
  final int total;

  final ContactoDeOrden contacto;
  final EntregaDeOrden entrega;

  /// La hora **del servidor**. `null` solo si el documento no la trae.
  final DateTime? creadaEn;

  final String? notasOperador;

  /// Por donde salio (EP-07). `null` hasta que se despacha.
  final DespachoDeOrden? despacho;

  /// Por que fallo la ultima entrega. **Queda** aunque se vuelva a despachar.
  final EntregaFallida? entregaFallida;

  /// Por que se cancelo y que no volvio al stock. Solo en una cancelada.
  final CancelacionDeOrden? cancelacion;

  EstadoPublico get estadoPublico =>
      proyectarEstadoPublico(estadoPago, estadoEntrega);

  /// Espera algo del operador (HU-06.3): lo que hay que preparar, entregar de
  /// nuevo o devolver.
  bool get requiereAccion =>
      estadosPublicosQueRequierenAccion.contains(estadoPublico);

  /// `true` si su cobro no lo sigue el sistema (un pedido de WhatsApp).
  bool get cobroPorFuera => estadoPago == EstadoPago.por_fuera;

  int get botellasEnTotal => items.fold(0, (a, i) => a + i.botellasEnTotal);
}
