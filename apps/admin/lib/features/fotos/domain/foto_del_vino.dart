/// Una foto de un vino, ya procesada por `procesarFoto`
/// (`functions/src/foto/procesar_foto.ts`).
///
/// No es el archivo crudo que el operador eligio: es lo que la callable
/// devolvio despues de recortar al borde, redimensionar y codificar a WebP
/// con la misma tuberia que usa el seed
/// (`packages/contratos/src/foto.ts`, `TUBERIA_DE_FOTO`). [url] es la que
/// entra a `imagenes[]` con `arrayUnion` (design.md decision 5: el
/// `arrayUnion` lo hace el panel, no la callable).
///
/// El panel **no vuelve a correr la tuberia**: `contratos` documenta que Dart
/// no la necesita espejar, solo mostrar lo que la callable informo. Por eso
/// este modelo es puro dato, sin logica de recorte adentro.
class FotoDelVino {
  const FotoDelVino({
    required this.url,
    required this.ancho,
    required this.alto,
    required this.porcentajeRecortado,
  });

  /// La URL publica en Storage
  /// (`https://firebasestorage.googleapis.com/v0/b/.../o/...`), ya en
  /// `imagenes[]` una vez que el `arrayUnion` se confirmo.
  final String url;

  /// Ancho final del WebP, despues del recorte y el resize.
  final int ancho;

  /// Alto final del WebP. La tuberia apunta a 1200 con
  /// `withoutEnlargement: true`: una foto que ya era mas chica no se agranda,
  /// y por eso puede llegar por debajo del objetivo (`portillo-malbec.png`,
  /// 173x438 en origen, es el caso real que documenta el spec).
  final int alto;

  /// Cuanto saco `trim()` respecto del crudo, en porcentaje entero de 0 a
  /// 100. **0 no es "no se proceso"**: es "no habia un fondo uniforme para
  /// sacar" -- la foto trae fondo, y la vidriera la va a dibujar con
  /// `mix-blend-mode: multiply` sobre ese fondo, el rectangulo oscuro que
  /// documenta `proposal.md`.
  final int porcentajeRecortado;
}

/// `imagenesValidas` de `firestore.rules` rechaza una lista de mas de diez
/// URLs. El panel tiene que decirlo **antes** de subir el archivo numero
/// once -- si no, el operador paga la subida y el procesamiento y recien ahi
/// la escritura del documento falla (spec "Un vino no pasa de diez fotos").
const topeDeFotos = 10;
