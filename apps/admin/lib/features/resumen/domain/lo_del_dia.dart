import '../../../core/contratos/catalogo_publico.dart';
import '../../../core/contratos/estado_entrega.dart';
import '../../../core/contratos/estado_pago.dart';
import '../../../core/contratos/estado_publico.dart';
import '../../catalogo/domain/catalogo.dart';
import '../../catalogo/domain/producto_del_panel.dart';

/// Hasta cuanto cuenta un conteo del resumen (HU-11.2, ADR 025).
///
/// **Lo exigen las reglas, no es un gusto**: `ordenes` solo se lista —y se
/// cuenta, que pasa por la misma regla— con `limit <= 50` (ADR 018 §7). Un
/// `count()` sin `limit` se rechaza. Con 50 pedidos por preparar el numero
/// exacto ya no cambia lo que hay que hacer.
const topeDelConteo = 50;

/// Un numero del resumen, contado por el servidor con `count()`: **una
/// lectura** cada 1.000 documentos contados, no una por documento.
class Conteo {
  const Conteo(this.cuantos);

  final int cuantos;

  /// Si se corto en el tope: la pantalla dice "50 o más", no "50".
  bool get llegoAlTope => cuantos >= topeDelConteo;
}

/// Los rotulos del operador que dicen *"para despachar"* sin preparar
/// (ADR 027): `pagada` (*"Pagado - para despachar"*) y `por_preparar`
/// (*"Para despachar"*). Es lo que HU-11.2 llama *"cuántos pedidos hay por
/// preparar"*.
///
/// `en_preparacion` NO entra aunque su rotulo tambien diga *"Para despachar"*:
/// la proyeccion lo da con **cualquier** pago, y contaria un pedido de la
/// tienda impago. Sin el paso de preparar ya no nacen pedidos ahi.
const estadosPublicosPorPreparar = {
  EstadoPublico.pagada,
  EstadoPublico.por_preparar,
};

/// Un tramo de la consulta de *"por preparar"*: un estado de entrega y los
/// pagos que, con el, caen en [estadosPublicosPorPreparar].
class TramoPorPreparar {
  const TramoPorPreparar({required this.entrega, required this.pagos});

  final EstadoEntrega entrega;
  final List<EstadoPago> pagos;
}

/// Los tramos, **sacados de la proyeccion** y no escritos a mano, igual que
/// `tramosParaHacer`: si ADR 002 cambia la tabla, el conteo cambia solo. Hoy
/// da uno solo —`sin_preparar` con `pagada` y `por_fuera`—, y el test lo dice
/// con la lista entera.
List<TramoPorPreparar> tramosPorPreparar() => [
  for (final entrega in EstadoEntrega.values)
    if (_pagosPorPreparar(entrega) case final pagos when pagos.isNotEmpty)
      TramoPorPreparar(entrega: entrega, pagos: pagos),
];

List<EstadoPago> _pagosPorPreparar(EstadoEntrega entrega) => [
  for (final pago in EstadoPago.values)
    if (estadosPublicosPorPreparar.contains(
      proyectarEstadoPublico(pago, entrega),
    ))
      pago,
];

/// Lo que la tienda muestra y ya no tiene stock: *"qué se agotó"* (HU-11.2).
///
/// **Cero lecturas**: sale del catalogo que ya esta en memoria. Solo los
/// **publicados** —un vino que la tienda no muestra no "se agotó" para nadie—
/// y con el mismo `balde` que decide la vidriera. Un compuesto no tiene stock
/// propio y no entra. En el orden del catalogo, por nombre.
List<ProductoDelPanel> agotadosEnLaTienda(Catalogo catalogo) => [
  for (final r in catalogo.renglones)
    if (r.producto case ProductoDelPanel(publicado: true, :final stock?)
        when balde(stock: stock, botellas: r.producto.botellas) ==
            Balde.agotado)
      r.producto,
];
