import '../../../core/contratos/despacho.dart';
import '../domain/fallo_de_pedidos.dart';
import '../domain/paso_de_entrega.dart';
import 'textos_de_pedidos.dart';

// Los textos de mover un pedido por el eje de entrega (EP-07). Los lee la
// familia, no el comprador: no pasan por `voz`. Funciones puras, sin Flutter: se
// prueban con `dart test`.
//
// Mismo cuidado que el resto de pedidos: ningun texto dice "cobrado" ni
// "pagado" de un pedido de WhatsApp (ADR 018 §6).

const textoQueSigue = 'Qué sigue';
const textoCorreo = '¿Por dónde sale?';
const textoSeguimiento = 'Número de seguimiento';
const textoSeguimientoOpcional =
    'Opcional. Si lo tenés, sirve para contestar «¿dónde está mi vino?».';
const textoMotivoDeFalla = '¿Qué pasó?';
const textoMotivoDeCancelacion = '¿Por qué se cancela?';
const textoElegiUnMotivo = 'Elegí un motivo.';
const textoElegiElCorreo = 'Elegí por dónde sale.';
const textoTodaviaNo = 'Todavía no';

String textoSeguimientoLargo(int largo) =>
    'El número de seguimiento tiene hasta $largo caracteres.';

/// El boton de cada accion, como lo lee quien lo aprieta.
String textoDeLaAccion(AccionDelPedido a) => switch (a) {
  AccionDelPedido.preparar => 'Empezar a prepararlo',
  AccionDelPedido.despachar => 'Despachar',
  AccionDelPedido.entregar => 'Llegó: marcar entregado',
  AccionDelPedido.noSeEntrego => 'No se pudo entregar',
  AccionDelPedido.cancelar => 'Cancelar el pedido',
};

String textoRotuloDelCorreo(Correo c) => switch (c) {
  Correo.andreani => 'Andreani',
  Correo.correoArgentino => 'Correo Argentino',
  Correo.oca => 'OCA',
  Correo.enMano => 'Lo llevamos nosotros',
  Correo.otro => 'Otro',
};

String textoDelMotivoDeFalla(MotivoDeFalla m) => switch (m) {
  MotivoDeFalla.sinMayor => 'No había un mayor de 18',
  MotivoDeFalla.nadie => 'No había nadie',
  MotivoDeFalla.direccion => 'La dirección estaba mal',
  MotivoDeFalla.rechazo => 'No lo quisieron recibir',
  MotivoDeFalla.otro => 'Otro',
};

String textoDelMotivoDeCancelacion(MotivoDeCancelacion m) => switch (m) {
  MotivoDeCancelacion.malCargado => 'Lo cargué mal o está repetido',
  MotivoDeCancelacion.cliente => 'El cliente ya no lo quiere',
  MotivoDeCancelacion.faltaVino => 'No teníamos el vino',
  MotivoDeCancelacion.otro => 'Otro',
};

String textoDelMotivoSinReponer(MotivoSinReponer? m) => switch (m) {
  MotivoSinReponer.noExiste => 'el vino ya no existe en el catálogo',
  MotivoSinReponer.otraPresentacion =>
    'el vino ahora viene en otra presentación',
  MotivoSinReponer.compuesto => 'es una caja armada, sin stock propio',
  MotivoSinReponer.productoRoto => 'el vino tiene un dato mal cargado',
  null => 'no sabemos por qué',
};

// ---------------------------------------------------------------- las hojas

String textoTituloDeDespachar(int numero) => 'Despachar el pedido $numero';
const textoMarcarDespachado = 'Marcar como despachado';

String textoTituloDeFalla(int numero) => 'El pedido $numero no se entregó';
const textoMarcarNoEntregado = 'Marcar que no se entregó';
const textoDespuesDeLaFalla =
    'Queda como «No entregado». Cuando salga de nuevo, lo volvés a despachar: '
    'mantiene su número.';

String textoTituloDeCancelar(int numero) => 'Cancelar el pedido $numero';
const textoVuelvenAlStock = 'Vuelven al stock:';

/// `2 × Malbec Reserva · 12 botellas`: las unidades del pedido y, para que un
/// vino de caja no se lea como sueltas, las botellas.
String textoLineaQueVuelve(int cantidad, String nombre, int botellas) =>
    '$cantidad × $nombre · ${textoBotellas(botellas)}';
const textoCancelarNoSeDeshace =
    'No se puede deshacer. Si el cliente lo vuelve a pedir, se carga de nuevo.';
const textoConfirmarCancelacion = 'Sí, cancelarlo';

// --------------------------------------------------------------- la entrega

String textoTituloDeEntrega(int numero) => '¿El pedido $numero llegó?';

/// La confirmacion ES la declaracion legal: `entregada` quiere decir que lo
/// recibio y firmo un mayor de 18 (ADR 002, ARQUITECTURA §9.5).
const textoCondicionDeEntrega =
    'Marcalo entregado solo si lo recibió una persona mayor de 18. Si no había '
    'nadie, o solo un menor, marcá que no se pudo entregar.';
const textoConfirmarEntrega = 'Sí, lo recibió un mayor de 18';

// ---------------------------------------------------------- lo que ya paso

String textoDelDespacho({required Correo correo, String? seguimiento}) =>
    seguimiento == null
    ? textoRotuloDelCorreo(correo)
    : '${textoRotuloDelCorreo(correo)} · $seguimiento';

const textoSalioPor = 'Salió por';
const textoPorQueNoSeEntrego = 'Por qué no se entregó';
const textoPorQueSeCancelo = 'Por qué se canceló';
const textoNoVolvieron =
    'Esto NO volvió al stock. Revisalo a mano en Catálogo:';

String textoLineaSinReponer(String nombre, int cantidad, MotivoSinReponer? m) =>
    '$cantidad × $nombre: ${textoDelMotivoSinReponer(m)}.';

const textoEsperaElPago =
    'Todavía no se puede despachar: falta que se acredite el pago.';

// -------------------------------------------------------------- resultados

String textoPasoHecho(PasoDeEntrega paso, int numero) => switch (paso) {
  Preparar() => 'Pedido $numero: lo estás preparando.',
  Despachar() => 'Pedido $numero despachado.',
  Entregar() => 'Pedido $numero entregado.',
  NoSeEntrego() => 'Pedido $numero: quedó como no entregado.',
};

String textoCancelado(
  int numero, {
  required bool repetido,
  required int sinReponer,
}) {
  if (repetido) return 'El pedido $numero ya estaba cancelado.';
  if (sinReponer > 0) {
    return 'Pedido $numero cancelado. Hay vinos que no volvieron al stock: '
        'mirá el detalle.';
  }
  return 'Pedido $numero cancelado: su stock volvió.';
}

/// Por que no se pudo mover o cancelar un pedido. Los que hacen volver a leer
/// el pedido lo dicen: la pantalla ya muestra lo de ahora.
String textoDelFalloDeEntrega(FalloDePedidos f) => switch (f.error) {
  ErrorDePedido.sinPermiso => 'Tu cuenta no tiene permiso para mover pedidos.',
  ErrorDePedido.sinConexion =>
    'No hubo conexión, y no sabemos si el cambio se guardó. Revisá la conexión '
        'y probá de nuevo: si ya estaba hecho, te lo decimos.',
  ErrorDePedido.cambioElPedido =>
    'No se guardó: otra persona lo movió mientras lo mirabas. Ya lo volvimos a '
        'leer; fijate cómo quedó.',
  ErrorDePedido.yaSalio =>
    'Ya salió, y un pedido despachado no se cancela: el envío ya costó. Si no '
        'llega, marcá que no se pudo entregar.',
  ErrorDePedido.pedidoInexistente => 'Este pedido ya no existe.',
  ErrorDePedido.pedidoRoto =>
    'Este pedido tiene un dato roto y no lo podemos cancelar desde acá. Avisale '
        'a quien mantiene el panel.',
  _ => 'No pudimos guardar el cambio. Probá de nuevo en un rato.',
};

/// Los fallos que dicen que lo que se ve ya no es lo que hay: la pantalla
/// vuelve a leer el pedido.
bool hayQueReleer(FalloDePedidos f) => switch (f.error) {
  ErrorDePedido.cambioElPedido ||
  ErrorDePedido.yaSalio ||
  ErrorDePedido.pedidoInexistente ||
  ErrorDePedido.desconocido => true,
  _ => false,
};
