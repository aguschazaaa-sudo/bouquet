import '../../../core/contratos/plata.dart';
import '../domain/entrega_escrita.dart';
import '../domain/fallo_de_pedidos.dart';
import '../domain/linea_a_cargar.dart';

// Los textos de cargar un pedido de WhatsApp (HU-10.1). Los lee la familia, no
// el comprador: no pasan por `voz`. Funciones puras, sin Flutter: se prueban con
// `dart test`. Cada error dice **que hacer**, no solo que paso.
//
// ⚠️ Ningun texto dice "cobrado" ni "pagado": el total es *de lista*.

const textoTituloDeCargar = 'Cargar un pedido';
const textoQueSeLlevan = 'Qué se llevan';
const textoSumarUnVino = 'Sumar un vino';
const textoSinVinosTodavia =
    'Todavía no sumaste ningún vino. Tocá «Sumar un vino» y elegí de la lista.';
const textoQuienYDonde = 'Quién lo recibe y a dónde va';
const textoCargarElPedido = 'Cargar el pedido';
const textoCargandoElPedido = 'Cargando el pedido…';
const textoElegirUnVino = 'Elegí un vino';
const textoBuscarUnVino = 'Buscar un vino';
const textoNoHayVinos = 'No hay vinos que coincidan con lo que escribiste.';
const textoNoSePudieronLeerLosVinos =
    'No pudimos leer tu catálogo. Puede ser la conexión, o que tu cuenta '
    'todavía no tenga permiso.';
const textoNoEstaEnLaTienda = 'no está en la tienda';
const textoSacarDelPedido = 'Sacar del pedido';
const textoEsTodoElStock = 'Es todo el stock que hay';
const textoTelefonoAyuda =
    'Pegalo como te lo mandaron: con o sin 15, con o sin +54.';
const textoFaltaAlgo = 'Falta completar algo para poder cargarlo.';
String textoAbrirElPedido(int numero) => 'Abrir el pedido $numero';

/// Como va a quedar el telefono, **antes de confirmar**: es lo que se guarda y lo
/// que lee `wa.me`. Un numero mal armado abre el chat de otra persona.
String textoVaAQuedarComo(String e164) =>
    'Va a quedar como ${e164.replaceFirst('+549', '+54 9 ')}';

String textoDeCuantoQueda(LineaACargar l) =>
    'Quedan ${l.stock} · ${enPesos(l.precioUnitario)} c/u';

/// Por que no se puede elegir un vino, dicho en el renglon deshabilitado.
String textoDeMotivoNoElegible(MotivoNoElegible m) => switch (m) {
  MotivoNoElegible.deMuestra => 'de muestra: no existe, no se puede vender',
  MotivoNoElegible.compuesto => 'caja armada: todavía no se puede vender acá',
  MotivoNoElegible.sinStock => 'sin stock: cargalo primero en Stock',
};

/// Que campo se marca y con que palabras.
String textoDelProblema(CampoDeEntrega c) => switch (c) {
  CampoDeEntrega.nombre => 'Escribí el nombre de quien recibe.',
  CampoDeEntrega.telefono =>
    'No podemos armar el número. Revisá que tenga el código de área y el '
        'número: son 10 dígitos en total.',
  CampoDeEntrega.email => 'Ese mail no parece completo. Podés dejarlo vacío.',
  CampoDeEntrega.calle => 'Escribí la calle.',
  CampoDeEntrega.numero => 'Escribí el número, o «s/n».',
  CampoDeEntrega.codigoPostal => 'El código postal son 4 números.',
  CampoDeEntrega.localidad => 'Escribí la localidad.',
  CampoDeEntrega.provincia => 'Elegí la provincia.',
};

/// Lo que se le dice al operador cuando el servidor rechaza el pedido.
///
/// [nombre] es el del vino de la linea que fallo, resuelto por quien llama con
/// lo que tiene en memoria: **el id no se muestra**.
String textoDelFalloDePedidos(FalloDePedidos f, {String? nombre}) {
  final vino = nombre ?? 'Ese vino';
  return switch (f.error) {
    ErrorDePedido.sinPermiso =>
      'Tu cuenta no tiene permiso para cargar pedidos.',
    ErrorDePedido.sinConexion =>
      'No hubo conexión, y no sabemos si el pedido llegó a cargarse. Tocá '
          '«$textoCargarElPedido» de nuevo: si ya estaba cargado te lo decimos, '
          'y no se duplica.',
    ErrorDePedido.sinStock =>
      f.actual == null
          ? '$vino ya no tiene stock suficiente. Corregí la cantidad.'
          : '$vino ya no tiene stock suficiente: quedan ${f.actual}. Corregí la '
                'cantidad.',
    ErrorDePedido.cambioElPrecio =>
      f.actual == null
          ? 'El precio de $vino cambió. Revisá el total y volvé a confirmar.'
          : 'El precio de $vino cambió a ${enPesos(f.actual!)}. Ya lo '
                'actualizamos: revisá el total y volvé a confirmar.',
    ErrorDePedido.deMuestra =>
      '$vino es un vino de muestra: no existe, no se puede vender.',
    ErrorDePedido.compuesto =>
      '$vino es una caja armada y todavía no se puede vender desde acá.',
    ErrorDePedido.sinPrecio =>
      '$vino no tiene precio cargado. Cargalo en Catálogo y volvé.',
    ErrorDePedido.productoRoto =>
      '$vino tiene un dato mal cargado y no se puede vender. Corregilo en '
          'Catálogo.',
    ErrorDePedido.noExiste => '$vino ya no existe en el catálogo.',
    ErrorDePedido.yaEstaHecho =>
      f.numero == null
          ? 'Este pedido ya se cargó antes, con otros datos. No lo cargues de '
                'nuevo: buscalo en la lista y revisalo.'
          : 'Este pedido ya se cargó como el pedido ${f.numero}, con otros '
                'datos. No lo cargues de nuevo: abrilo y revisalo.',
    ErrorDePedido.datosInvalidos =>
      'Hay un dato del pedido que no se aceptó. Revisá el nombre, el teléfono '
          'y la dirección.',
    // Los de EP-07 son de mover o cancelar un pedido que ya existe: cargar no
    // los produce. Si alguno llegara, no se inventa una explicacion.
    ErrorDePedido.cambioElPedido ||
    ErrorDePedido.yaSalio ||
    ErrorDePedido.pedidoInexistente ||
    ErrorDePedido.pedidoRoto ||
    ErrorDePedido.desconocido =>
      'No pudimos cargar el pedido. Probá de nuevo en un rato.',
  };
}
