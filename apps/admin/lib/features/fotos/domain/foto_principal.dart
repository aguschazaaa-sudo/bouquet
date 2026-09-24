/// [imagenes] con [url] al frente y el resto en su orden relativo, o `null` si
/// [url] no está (HU-04.2).
///
/// La principal es la primera de `imagenes[]`: es la única que dibuja la
/// vidriera (`VentanaDeBotella.tsx`, `seleccion.ts`). **No ordena las demás.**
///
/// Es una permutación de [imagenes]: nunca agrega ni pierde una URL. Por eso
/// el repositorio la aplica sobre lo que **acaba de leer** dentro de una
/// transacción y no sobre la lista de la pantalla, que puede estar vieja
/// (ARQUITECTURA §5.3). Si la URL está repetida, mueve la primera aparición.
List<String>? conPrincipal(List<String> imagenes, String url) {
  final posicion = imagenes.indexOf(url);
  if (posicion < 0) return null;
  return [
    url,
    ...imagenes.sublist(0, posicion),
    ...imagenes.sublist(posicion + 1),
  ];
}
