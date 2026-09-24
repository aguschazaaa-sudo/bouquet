// El espejo en Dart de `normalizarTelefonoAR`, de
// `packages/contratos/src/envio.ts`. HU-10.1, ADR 018.
//
// NO ES COSMETICO. El panel le muestra al operador como quedo el numero que
// pego del chat, y el servidor guarda el que sale de la funcion de TypeScript.
// Si difieren, el operador confirma un numero y se guarda otro; y `wa.me` lee
// los digitos como E.164 COMPLETO, asi que un numero mal armado abre un chat
// con otra persona sin fallar. Vive dos veces por lo mismo que `texto.dart`:
// la logica no se transporta en JSON, viajan pares entrada->salida CALCULADOS
// por el TypeScript de hoy (`generated/contratos.json`, seccion `pedido`), y
// `test/core/contratos/telefono_test.dart` compara contra eso.

/// El telefono a E.164 (`+549` y diez digitos), o `null` si no se puede.
///
/// Acepta el numero como se escribe en un chat: con espacios, guiones,
/// parentesis, el `0` de larga distancia, el `15` de celular, el `9` y el `54`.
///
/// Asume MOVIL: antepone el `9`. Un fijo normalizado asi queda mal, y es
/// deliberado -el campo existe para escribir por WhatsApp-.
String? normalizarTelefonoAR(String entrada) {
  var d = entrada.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('54')) d = d.substring(2);
  if (d.startsWith('9')) d = d.substring(1);
  while (d.startsWith('0')) {
    d = d.substring(1);
  }
  // El `15` no existe en E.164 y la longitud nacional es siempre 10 (area +
  // abonado): un numero de 12 con `15` adentro se corrige buscando donde
  // cortarlo.
  if (d.length > 10) {
    for (final corte in const [2, 3, 4]) {
      if (d.length - 2 == 10 && d.substring(corte, corte + 2) == '15') {
        d = d.substring(0, corte) + d.substring(corte + 2);
        break;
      }
    }
  }
  if (d.length != 10) return null;
  return '+549$d';
}
