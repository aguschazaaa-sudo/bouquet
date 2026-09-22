/**
 * Que la ruta del crudo sea EXACTAMENTE `productos/{productoId}/{archivo}` -un
 * solo segmento de nombre de archivo, ver ARQUITECTURA §5.4 regla 2- y que el
 * `productoId` de la ruta coincida con el que vino en el argumento de la
 * callable.
 *
 * Quien llama a `procesarFoto` elige la ruta: sin esto, un admin con un panel
 * con bugs -o una llamada a mano- puede hacer que la function lea y borre
 * cualquier objeto del bucket (design.md, "una callable es un endpoint HTTPS
 * publico").
 */

const PATRON = /^productos\/([^/]+)\/([^/]+)$/;

/**
 * `null` cuando la ruta no matchea la forma esperada o cuando el id de la
 * ruta no coincide con `productoIdEsperado`.
 */
export function validarRutaDelCrudo(ruta: string, productoIdEsperado: string): string | null {
  const m = PATRON.exec(ruta);
  if (!m) return null;
  const [, productoId, archivo] = m;
  if (productoId !== productoIdEsperado) return null;
  return archivo!;
}
