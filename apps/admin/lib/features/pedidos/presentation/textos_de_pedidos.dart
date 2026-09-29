import '../../../core/contratos/pedido.dart';
import '../domain/vista_de_bandeja.dart';

// Los textos de la bandeja y del detalle de un pedido (HU-06.1, HU-06.2). En
// espanol rioplatense y con voseo, como el resto del panel: lo lee la familia.
//
// ⚠️ **Ningun texto dice "cobrado" ni "pagado".** El total es *de lista*: el
// cobro de un pedido de WhatsApp va por fuera y el panel no lo sigue
// (ADR 018 §6). Hay un test que lo fija.

const textoTituloDePedidos = 'Pedidos';
const textoCargarUnPedido = 'Cargar un pedido';
const textoActualizar = 'Actualizar';
const textoVerMas = 'Ver más pedidos';
const textoCargandoPedidos = 'Buscando los pedidos…';
const textoTotalDeLista = 'Total de lista';

const textoNoSePudieronLeerLosPedidos =
    'No pudimos leer los pedidos. Puede ser la conexión, o que tu cuenta '
    'todavía no tenga permiso.';

const textoNoSePudoVerMas =
    'No pudimos traer más pedidos. Los que ya ves siguen ahí: probá de nuevo.';

/// Las tres fichas de la bandeja (ADR 027). Con las mismas palabras que el
/// estado de cada pedido y que el boton que lo lleva ahi: *"Para despachar"*
/// vive en *Para hacer*, *"Salió"* lo pasa a *En camino*.
String textoDeLaVista(VistaDeBandeja v) => switch (v) {
  VistaDeBandeja.paraHacer => 'Para hacer',
  VistaDeBandeja.enCamino => 'En camino',
  VistaDeBandeja.terminados => 'Terminados',
};

/// Lo que dice la bandeja vacia de una vista. **Dice que esta vacia y por que
/// puede ser**: una lista en blanco muda parece un error.
String textoVistaVacia(VistaDeBandeja v) => switch (v) {
  VistaDeBandeja.paraHacer =>
    'Nada espera por vos. Cuando cargues un pedido de WhatsApp, entre uno de la '
        'tienda o no se pueda entregar uno, aparece acá.',
  VistaDeBandeja.enCamino => 'No hay pedidos en camino.',
  VistaDeBandeja.terminados =>
    'Todavía no hay pedidos entregados ni cancelados.',
};

// --------------------------------------------------------------- buscar

/// HU-06.4. Dice que se busca por NUMERO: el nombre del cliente no se busca.
/// Sin el "Buscar por" de adelante: la lupa ya lo dice, y en un telefono de
/// 328 px el texto largo se cortaba en *"Buscar por nú…"*, justo antes de la
/// palabra que importa.
const textoBuscarPorNumero = 'Número de pedido';
const textoBuscar = 'Buscar';
const textoBuscando = 'Buscando…';
const textoNoEsUnNumero = 'Escribí el número del pedido, por ejemplo 123.';

String textoNoHayPedido(int numero) =>
    'No hay un pedido $numero. Fijate el número que te pasaron.';

String textoPedidoConNumeroIncompleto(int numero) =>
    'El pedido $numero está incompleto y no lo podemos mostrar.';

const textoNoSePudoBuscar =
    'No pudimos buscar. Puede ser la conexión: probá de nuevo.';

String textoIncompletos(int n) => n == 1
    ? 'Hay 1 pedido que no pudimos leer y no aparece en la lista.'
    : 'Hay $n pedidos que no pudimos leer y no aparecen en la lista.';

String textoDelNumero(int numero) => 'Pedido $numero';

String textoDelOrigen(Origen o) => switch (o) {
  Origen.whatsapp => 'De WhatsApp',
  Origen.vidriera => 'De la tienda',
};

String textoBotellas(int n) => n == 1 ? '1 botella' : '$n botellas';

// ------------------------------------------------------------------ detalle

const textoTituloDelDetalle = 'Pedido';
const textoQueLleva = 'Qué lleva';
const textoQuienLoRecibe = 'Quién lo recibe';
const textoADondeVa = 'A dónde va';
const textoElCobroVaPorFuera =
    'El cobro se gestiona por fuera: acá no se ve si se cobró.';
const textoVolverALosPedidos = 'Volver a los pedidos';

const textoPedidoInexistente =
    'No encontramos ese pedido. Puede que el enlace esté mal.';

const textoPedidoIncompleto =
    'Este pedido está incompleto y no lo podemos mostrar entero. Mirá en la '
    'lista si aparece con el mismo número.';

const textoNoSePudoLeerElPedido =
    'No pudimos leer el pedido. Puede ser la conexión, o que tu cuenta todavía '
    'no tenga permiso.';
