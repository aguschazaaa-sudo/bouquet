import '../../../core/contratos/despacho.dart';
import '../../../core/contratos/estado_entrega.dart';
import 'despacho_de_orden.dart';
import 'orden.dart';
import 'paso_de_entrega.dart';
import 'pedido_a_cargar.dart';

/// Cuantos pedidos trae la bandeja por vez (HU-06.1). Es el `limit` de la
/// consulta: las reglas piden hasta 50 y la cuota se mide con este numero
/// (ADR 018, *Presupuesto de lecturas*).
const tamanoDePaginaDePedidos = 25;

/// Lo que devolvio `crearOrdenDelPanel`.
class ResultadoDeCarga {
  const ResultadoDeCarga({
    required this.ordenId,
    required this.numero,
    required this.repetido,
  });

  /// El id del documento (es el `idPedido`). Sirve para llevar al detalle;
  /// **nunca se le muestra a nadie**.
  final String ordenId;

  /// Lo que se dice y lo que se busca.
  final int numero;

  /// `true` si este `idPedido` ya era una Orden y no se toco nada: un reintento
  /// que el servidor reconocio. Para el operador es un exito igual.
  final bool repetido;
}

/// Lo que devolvio `cancelarOrden` (HU-07.6).
class ResultadoDeCancelacion {
  const ResultadoDeCancelacion({
    required this.numero,
    required this.repetido,
    this.sinReponer = const [],
  });

  final int numero;

  /// `true` si ya estaba cancelado: un reintento. Para el operador es un exito.
  final bool repetido;

  /// Lo que NO volvio al stock. Si no esta vacio, la pantalla lo dice: lo tiene
  /// que resolver una persona.
  final List<LineaSinReponer> sinReponer;
}

/// Una pagina de la bandeja.
class PaginaDePedidos {
  const PaginaDePedidos({
    required this.ordenes,
    required this.incompletos,
    this.siguiente,
  });

  final List<Orden> ordenes;

  /// Cuantos documentos de esta pagina no se pudieron leer como una Orden
  /// (falta `items`, un estado desconocido...). **Se cuentan y se muestran**: un
  /// pedido que desaparece de la lista en silencio es exactamente el defecto que
  /// HU-03.7 tuvo que cerrar en el catalogo.
  final int incompletos;

  /// La marca de la que sigue: la `creadaEn` de la ultima orden de esta pagina.
  /// `null` si no hay mas, o sea si la pagina vino con menos de
  /// [tamanoDePaginaDePedidos].
  final DateTime? siguiente;

  bool get hayMas => siguiente != null;
}

/// Lo que dice el detalle de un pedido pedido por id.
sealed class DetalleDePedido {
  const DetalleDePedido();
}

class PedidoEncontrado extends DetalleDePedido {
  const PedidoEncontrado(this.orden);
  final Orden orden;
}

/// No hay un documento con ese id. Se dice, no se deja la pantalla en blanco.
class PedidoInexistente extends DetalleDePedido {
  const PedidoInexistente();
}

/// Hay un documento pero no se lee como una Orden.
class PedidoIncompleto extends DetalleDePedido {
  const PedidoIncompleto();
}

/// Lo que el panel sabe hacer con los pedidos: cargar uno de WhatsApp, listar los
/// que hay por estado de entrega, abrir uno (HU-10.1, HU-06.1, HU-06.2) y
/// moverlo por el eje de entrega (EP-07).
///
/// **El panel no crea una Orden**: las reglas lo niegan. Nacen por la callable
/// `crearOrdenDelPanel`, que descuenta el stock y numera en una transaccion
/// (ADR 018 §1). Y **no la cancela escribiendo**: cancelar devuelve stock, y lo
/// hace la callable `cancelarOrden` (ADR 019).
///
/// [cargar], [avanzar] y [cancelar] lanzan `FalloDePedidos`, nunca otra cosa y
/// nunca en silencio (HU-04.4).
/// Los que leen dejan subir el error para que la pantalla lo dibuje como un
/// fallo y no como "no hay pedidos".
abstract interface class RepositorioDePedidos {
  /// [pedido] ya viene con su `idPedido`, que vale para TODOS los intentos.
  Future<ResultadoDeCarga> cargar(PedidoACargar pedido);

  /// Una pagina de los pedidos en [estado], los mas nuevos primero. Sin
  /// [despuesDe] es la primera. **Una lectura, no un stream**: la bandeja se
  /// actualiza a pedido (ARQUITECTURA §6.3).
  Future<PaginaDePedidos> bandeja(EstadoEntrega estado, {DateTime? despuesDe});

  /// Un pedido por id: una lectura.
  Future<DetalleDePedido> detalle(String id);

  /// Escribe [paso] en el pedido [id]: **una escritura, cero lecturas**. Las
  /// reglas lo validan contra el estado de ahora: si otra persona lo movio
  /// mientras se miraba, se rechaza (`ErrorDePedido.cambioElPedido`).
  Future<void> avanzar(String id, PasoDeEntrega paso);

  /// Cancela [id] y devuelve su stock, por la callable `cancelarOrden`.
  /// Reintentar es seguro: un pedido ya cancelado es su propio marcador.
  Future<ResultadoDeCancelacion> cancelar(
    String id,
    MotivoDeCancelacion motivo,
  );
}
