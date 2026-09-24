import '../domain/ventas_sin_despachar.dart';
import 'textos_del_stock.dart';

// Los textos del aviso de "vendidas sin despachar" (HU-05.2, ADR 018 §9). Los
// lee la familia, no el comprador: no pasan por `voz`. Funciones puras, sin
// Flutter: se prueban con `dart test`.

const textoNoSePudoVerLoVendido =
    'No pudimos ver si hay pedidos sin despachar. Si los hay, esas botellas '
    'siguen en la estantería aunque ya no figuren en el stock: contalas aparte.';

/// Lo que hay vendido y sin despachar, con la instruccion de que hacer al contar.
///
/// Dice **las dos cosas** que el operador necesita: que ya estan descontadas (por
/// eso el stock que figura es menor que el que ve) y que **siguen en la
/// estanteria** (por eso al contar hay que restarlas).
///
///   `Hay 2 botellas vendidas que todavía no se despacharon. Ya están descontadas
///   del stock pero siguen en la estantería: al contar, restale esas 2.`
String textoDeVentasSinDespachar(
  VentasSinDespachar v, {
  required int botellas,
}) {
  final n = describirElStock(v.unidades, botellas: botellas);
  final piso = v.completo
      ? ''
      : ' Hay muchos pedidos sin despachar: puede haber más de las que contamos.';
  if (v.unidades == 0) {
    // Solo la duda: se llego al tope de pedidos y ninguno de los leidos lo lleva.
    return 'Hay muchos pedidos sin despachar y no llegamos a leerlos todos: '
        'puede haber unidades de este vino vendidas que siguen en la '
        'estantería. Al contar, restale esas.';
  }
  final unidad = v.unidades == 1 ? 'vendida' : 'vendidas';
  return 'Hay $n $unidad que todavía no se despacharon. Ya están descontadas '
      'del stock pero siguen en la estantería: al contar, restale '
      '${v.unidades == 1 ? 'esa' : 'esas ${v.unidades}'}.$piso';
}
