/// El numero de pedido que alguien escribio en el buscador (HU-06.4), o `null`
/// si lo escrito no es un numero de pedido.
///
/// Acepta lo que se copia de un chat: *"123"*, *"#123"*, *"Pedido 123"*,
/// *"N.º 123"*. Todo lo de adelante que no sea un digito se ignora; **lo de atras
/// no**: *"12 3"* o *"123abc"* no se leen como 123, porque buscar un numero que
/// nadie escribio abre el pedido de otra persona.
///
/// Hasta 9 cifras: un numero de pedido es un contador que arranca en 1, y uno
/// mas largo es un telefono pegado en el lugar equivocado.
int? numeroBuscado(String texto) {
  final m = _numero.firstMatch(texto);
  if (m == null) return null;
  final n = int.parse(m.group(1)!);
  return n >= 1 ? n : null;
}

final _numero = RegExp(r'^\D*?(\d{1,9})\s*$');
