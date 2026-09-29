import '../domain/lo_del_dia.dart';

/// Lo que dice la seccion Resumen (EP-11). Para gente no tecnica: que es cada
/// numero y a donde ir con el.

const textoArmandoElResumen = 'Armando el resumen…';

const textoNoSeLeyoElCatalogo =
    'No se pudo leer el catálogo, y sin él no se sabe qué se agotó.';

// ------------------------------------------------------------------ el dia

const textoTituloDelDia = 'Hoy';

const textoPorPreparar = 'Por preparar';
const textoQueEsPorPreparar =
    'Pedidos cobrados —o de WhatsApp— que todavía no se prepararon.';
const textoVerPedidos = 'Ver pedidos';

const textoPagosEnProceso = 'Pagos en proceso';
const textoQueEsEnProceso =
    'Compras de la tienda que Mercado Pago todavía no confirmó.';

const textoAgotados = 'Agotados';
const textoQueEsAgotados = 'Vinos de la tienda que se quedaron sin stock.';
const textoVerQueReponer = 'Ver qué reponer';

/// El numero de un conteo. En el tope no es exacto, y lo dice.
String textoDelConteo(Conteo c) =>
    c.llegoAlTope ? '$topeDelConteo o más' : '${c.cuantos}';

const textoNoSePudoContar = 'No se pudo contar.';
const textoVolverAContar = 'Volver a contar';

/// Cuantos nombres de agotados se dicen antes del *"y N más"*.
const agotadosQueSeNombran = 5;

String textoSeAgotaron(List<String> nombres) {
  final dichos = nombres.take(agotadosQueSeNombran).join(', ');
  final resto = nombres.length - agotadosQueSeNombran;
  final verbo = nombres.length == 1 ? 'Se agotó' : 'Se agotaron';
  return resto > 0 ? '$verbo: $dichos y $resto más.' : '$verbo: $dichos.';
}

// --------------------------------------------------- lo que mas se vende

const textoTituloLoQueMasSeVende = 'Lo que más se vende';

String textoDeLaVentana({
  required int dias,
  required int ventas,
  required String cuando,
}) =>
    'En los últimos $dias días, sobre ${ventas == 1 ? '1 pedido' : '$ventas pedidos'}. '
    'Calculado $cuando.';

/// Todavia no corrio el calculo, o lo que hay es el simulado del seed. **No
/// se muestra un ranking inventado** (EP-11).
const textoSinMedir =
    'Todavía no hay ventas medidas. Se calcula solo, cada madrugada, con los '
    'pedidos cobrados y los de WhatsApp.';

String textoSinVentasEnLaVentana(int dias) =>
    'En los últimos $dias días no hubo ventas.';

const textoIlegible = 'El cálculo de ventas está, pero no se pudo leer.';

const textoNoSeLeyoLoQueMasSeVende = 'No se pudo leer lo que más se vende.';
const textoVolverALeer = 'Volver a leer';

String textoUnidades(int n) => n == 1 ? '1 unidad' : '$n unidades';

/// Un id del ranking que el catalogo no tiene: el vino se vendio y despues
/// se borro de la base. Pasa poco —el panel no borra, despublica—, pero pasa.
const textoVinoQueYaNoEsta = 'Un vino que ya no está en el catálogo';
