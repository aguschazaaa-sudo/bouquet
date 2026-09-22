/// La baranda de HU-03.5 (design.md de `panel-publicar-un-vino`, Decision
/// #5; ARQUITECTURA §9.4): *"la condicion se escribe sobre el valor NUEVO,
/// con el anterior como señal opcional"*. Dos condiciones, CUALQUIERA pide
/// confirmacion:
///
///   1. El precio nuevo se aparta **10x o mas** de la MEDIANA de los
///      publicados -- atrapa el cero de mas y el cero de menos, aunque el
///      precio anterior ya estuviera mal. Con menos de
///      [minimoParaLaMediana] publicados la mediana no discrimina y esta
///      condicion queda sin aplicar.
///   2. El precio nuevo es **menos de la mitad o mas del doble** del
///      anterior -- atrapa el cambio grande sobre un precio sano.
///
/// **Cero lecturas**: la mediana sale de lo que ya esta en memoria (el
/// stream de productos que pinta la lista), nunca de una consulta nueva.
library;

/// Con menos publicados que esto, la mediana no dice nada (design.md,
/// Decision #5): es el estado del dia que se publique el primer vino.
const minimoParaLaMediana = 5;

/// `true` si cambiar el precio de un vino publicado de [precioAnterior] a
/// [precioNuevo] (los dos en centavos) tiene que confirmarse antes de
/// guardar.
///
/// [preciosPublicados] son los precios, en centavos, de TODOS los productos
/// publicados del catalogo tal como estan hoy.
bool pideConfirmarElCambio({
  required int precioNuevo,
  required int precioAnterior,
  required List<int> preciosPublicados,
}) {
  return _seApartaDeLaMediana(precioNuevo, preciosPublicados) ||
      _esUnSaltoGrande(precioNuevo, precioAnterior);
}

bool _seApartaDeLaMediana(int precioNuevo, List<int> publicados) {
  if (publicados.length < minimoParaLaMediana) return false;
  final mediana = _mediana(publicados);
  if (mediana <= 0) return false;
  return precioNuevo >= mediana * 10 || precioNuevo * 10 <= mediana;
}

bool _esUnSaltoGrande(int precioNuevo, int precioAnterior) =>
    precioNuevo * 2 < precioAnterior || precioNuevo > precioAnterior * 2;

/// El promedio de los dos del medio si [valores] tiene una cantidad par.
double _mediana(List<int> valores) {
  final ordenados = [...valores]..sort();
  final n = ordenados.length;
  final medio = n ~/ 2;
  if (n.isOdd) return ordenados[medio].toDouble();
  return (ordenados[medio - 1] + ordenados[medio]) / 2;
}
