import '../domain/ventas_sin_despachar.dart';
import 'textos_del_stock.dart';

// Los textos del aviso de pedidos abiertos (HU-05.2, ADR 018 §9). Los lee la
// familia, no el comprador: no pasan por `voz`. Funciones puras, sin Flutter: se
// prueban con `dart test`.

const textoNoSePudoVerLoVendido =
    'No pudimos ver si hay pedidos sin despachar. Si los hay, esas botellas ya '
    'están descontadas del stock: si siguen en la estantería, contalas aparte.';

/// Lo que hay en pedidos que todavia no figuran como despachados, con lo que hacer
/// al contar.
///
/// **Es condicional a proposito**: el panel todavia no puede marcar un pedido como
/// despachado (EP-07), asi que un pedido cuyas botellas ya salieron sigue figurando
/// abierto. Decir *"restale esas"* a secas haria restar de mas en ese caso. Solo el
/// operador sabe si siguen en la estanteria: se le da el dato y las dos salidas.
///
///   `Hay 2 botellas en pedidos que todavía no figuran como despachados. Ya están
///   descontadas del stock. Si siguen en la estantería, restale esas 2 a lo que
///   cuentes; si ya salieron, contá lo que hay.`
String textoDeVentasSinDespachar(
  VentasSinDespachar v, {
  required int botellas,
}) {
  if (v.unidades == 0) {
    // Solo la duda: se llego al tope de pedidos y ninguno de los leidos lo lleva.
    return 'Hay muchos pedidos sin despachar y no llegamos a leerlos todos: '
        'puede haber unidades de este vino en ellos. Ya están descontadas del '
        'stock; si siguen en la estantería, restalas a lo que cuentes.';
  }
  final n = describirElStock(v.unidades, botellas: botellas);
  final esas = v.unidades == 1 ? 'esa' : 'esas ${v.unidades}';
  final piso = v.completo
      ? ''
      : ' Hay muchos pedidos sin despachar: puede haber más de las que contamos.';
  return 'Hay $n en pedidos que todavía no figuran como despachados. Ya están '
      'descontadas del stock. Si siguen en la estantería, restale $esas a lo '
      'que cuentes; si ya salieron, contá lo que hay.$piso';
}
