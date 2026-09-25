/// Las notas internas de un pedido (HU-07.7): *"llamar antes"*, *"falta una
/// botella"*. El comprador no las ve nunca.
///
/// El tope es el de las reglas (`notasOperador.size() <= 1000`). Se cuenta en
/// unidades de `String.length`, que nunca son menos que los caracteres que
/// cuentan las reglas: lo que pasa aca, pasa alla.
const largoMaximoDeNota = 1000;

/// Lo que se guarda de lo escrito: sin espacios de mas en los bordes, y `null`
/// si quedo vacio. **Una nota vacia se borra**, no se guarda como `""`: un
/// pedido sin nota y uno con una nota en blanco se ven igual, y no tienen por
/// que ser distintos en la base.
String? notaAGuardar(String texto) {
  final limpia = texto.trim();
  return limpia.isEmpty ? null : limpia;
}

/// `true` si lo escrito entra en las reglas.
bool notaEntra(String texto) =>
    (notaAGuardar(texto)?.length ?? 0) <= largoMaximoDeNota;
